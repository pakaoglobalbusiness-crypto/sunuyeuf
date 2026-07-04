import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import {
  BOOKING_TRANSITIONS,
  COMMISSION_RATE,
  refundPercent,
} from '../common/constants';

const DAY_MS = 24 * 60 * 60 * 1000;

function eachDay(start: Date, end: Date): Date[] {
  const days: Date[] = [];
  for (let t = start.getTime(); t < end.getTime(); t += DAY_MS) {
    days.push(new Date(t));
  }
  return days;
}

@Injectable()
export class BookingsService {
  constructor(private prisma: PrismaService) {}

  private assertTransition(from: string, to: string) {
    if (!BOOKING_TRANSITIONS[from]?.includes(to)) {
      throw new ConflictException(`Transition ${from} → ${to} interdite`);
    }
  }

  async request(renterId: string, listingId: string, startDate: string, endDate: string) {
    const start = new Date(startDate);
    const end = new Date(endDate);
    if (!(start < end)) throw new BadRequestException('Dates invalides');
    if (start < new Date(new Date().toDateString())) {
      throw new BadRequestException('La date de début est passée');
    }

    const listing = await this.prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing || listing.status !== 'published') {
      throw new NotFoundException('Annonce indisponible');
    }
    if (listing.ownerId === renterId) {
      throw new BadRequestException('Impossible de réserver votre propre annonce');
    }

    // Vérification de disponibilité (équivalent du verrou Redis en prod — spec §6.1)
    const busy = await this.prisma.availability.count({
      where: {
        listingId,
        date: { gte: start, lt: end },
        status: { in: ['bloque', 'reserve'] },
      },
    });
    if (busy > 0) throw new ConflictException('Dates indisponibles');

    const days = eachDay(start, end).length;
    const totalPriceFcfa = days * listing.pricePerDayFcfa;
    const commissionFcfa = Math.round(totalPriceFcfa * COMMISSION_RATE);

    const booking = await this.prisma.booking.create({
      data: {
        listingId,
        renterId,
        startDate: start,
        endDate: end,
        totalPriceFcfa,
        commissionFcfa,
        cancellationPolicy: listing.cancellationPolicy, // figée (F9)
        status: listing.instantBooking ? 'accepted' : 'requested',
      },
      include: { listing: true },
    });

    console.log(
      `[Notif mock] ${listing.instantBooking ? 'Réservation instantanée' : 'Demande de réservation'} ${booking.id} — push+SMS au propriétaire ${listing.ownerId}`,
    );
    return booking;
  }

  async respond(ownerId: string, bookingId: string, action: 'accept' | 'reject') {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { listing: true },
    });
    if (!booking) throw new NotFoundException('Réservation introuvable');
    if (booking.listing.ownerId !== ownerId) throw new ForbiddenException();

    const to = action === 'accept' ? 'accepted' : 'rejected';
    this.assertTransition(booking.status, to);

    const updated = await this.prisma.booking.update({
      where: { id: bookingId },
      data: { status: to },
    });
    console.log(`[Notif mock] Réservation ${bookingId} ${to} — push+SMS au locataire`);
    return updated;
  }

  // Appelé par le module paiements après confirmation du webhook
  async markPaid(bookingId: string) {
    const booking = await this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: { listing: true },
    });
    this.assertTransition(booking.status, 'paid');

    for (const date of eachDay(booking.startDate, booking.endDate)) {
      await this.prisma.availability.upsert({
        where: { listingId_date: { listingId: booking.listingId, date } },
        update: { status: 'reserve' },
        create: { listingId: booking.listingId, date, status: 'reserve' },
      });
    }
    await this.prisma.conversation.upsert({
      where: { bookingId },
      update: {},
      create: { bookingId },
    });

    // Versement propriétaire programmé à J+1 après le début (spec §6.1, F14)
    await this.prisma.payout.create({
      data: {
        ownerId: booking.listing.ownerId,
        bookingId,
        amountFcfa: booking.totalPriceFcfa - booking.commissionFcfa,
        method: 'wave',
        status: 'scheduled',
      },
    });

    return this.prisma.booking.update({
      where: { id: bookingId },
      data: { status: 'paid' },
    });
  }

  async cancel(userId: string, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { listing: true, payments: true },
    });
    if (!booking) throw new NotFoundException('Réservation introuvable');

    const isRenter = booking.renterId === userId;
    const isOwner = booking.listing.ownerId === userId;
    if (!isRenter && !isOwner) throw new ForbiddenException();
    this.assertTransition(booking.status, 'cancelled');

    let refundFcfa = 0;
    const paid = booking.payments.some(
      (p) => p.kind === 'rental' && p.status === 'confirmed',
    );
    if (paid) {
      if (isOwner) {
        // Annulation propriétaire : remboursement intégral + pénalité (spec §6.2)
        refundFcfa = booking.totalPriceFcfa;
        console.log(`[Pénalité] Baisse de visibilité pour le propriétaire ${userId}`);
      } else {
        const daysBefore = Math.floor(
          (booking.startDate.getTime() - Date.now()) / DAY_MS,
        );
        refundFcfa = Math.round(
          (booking.totalPriceFcfa * refundPercent(booking.cancellationPolicy, daysBefore)) / 100,
        );
      }
      if (refundFcfa > 0) {
        await this.prisma.payment.create({
          data: {
            bookingId,
            method: booking.payments[0].method,
            aggregatorRef: `refund_${bookingId}_${Date.now()}`,
            amountFcfa: refundFcfa,
            kind: 'refund',
            status: 'confirmed',
          },
        });
      }
      // Libération des dates + annulation du payout programmé
      await this.prisma.availability.updateMany({
        where: {
          listingId: booking.listingId,
          date: { gte: booking.startDate, lt: booking.endDate },
        },
        data: { status: 'libre' },
      });
      await this.prisma.payout.updateMany({
        where: { bookingId, status: 'scheduled' },
        data: { status: 'failed' },
      });
    }

    const updated = await this.prisma.booking.update({
      where: { id: bookingId },
      data: { status: 'cancelled' },
    });
    return { ...updated, refundFcfa };
  }

  // Avance automatiquement les statuts selon les dates (en prod : job planifié).
  // paid → ongoing dès le début de la location ; ongoing → completed après la fin.
  // Pour les voitures, la remise/retour via l'état des lieux reste prioritaire :
  // on ne force le passage qu'aux dates dépassées.
  private async refreshStatuses(where: object) {
    const now = new Date();
    await this.prisma.booking.updateMany({
      where: { ...where, status: 'paid', startDate: { lte: now } },
      data: { status: 'ongoing' },
    });
    await this.prisma.booking.updateMany({
      where: { ...where, status: 'ongoing', endDate: { lte: now } },
      data: { status: 'completed' },
    });
  }

  async myBookings(userId: string) {
    await this.refreshStatuses({ renterId: userId });
    return this.prisma.booking.findMany({
      where: { renterId: userId, hiddenByRenter: false },
      include: { listing: { include: { photos: true } }, payments: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  // Retirer une réservation de la liste du locataire (uniquement une
  // réservation terminée/annulée/refusée/expirée — les actives doivent
  // d'abord être annulées). L'enregistrement reste pour le propriétaire.
  async hideBooking(userId: string, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Réservation introuvable');
    if (booking.renterId !== userId) throw new ForbiddenException();
    if (!['completed', 'cancelled', 'rejected', 'expired'].includes(booking.status)) {
      throw new BadRequestException(
        'Annulez d’abord cette réservation avant de la retirer de votre liste',
      );
    }
    await this.prisma.booking.update({
      where: { id: bookingId },
      data: { hiddenByRenter: true },
    });
    return { hidden: true };
  }

  async ownerBookings(ownerId: string) {
    await this.refreshStatuses({ listing: { ownerId } });
    return this.prisma.booking.findMany({
      where: { listing: { ownerId } },
      include: {
        listing: { select: { id: true, title: true, type: true } },
        renter: { select: { id: true, name: true, phone: true, avgRating: true } },
        payments: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(userId: string, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        listing: { include: { photos: true, owner: { select: { id: true, name: true, photoUrl: true } } } },
        payments: true,
        reviews: true,
        carCheckins: true,
      },
    });
    if (!booking) throw new NotFoundException('Réservation introuvable');
    if (booking.renterId !== userId && booking.listing.owner.id !== userId) {
      throw new ForbiddenException();
    }
    // Localisation exacte révélée seulement après paiement (spec §7)
    const paidStatuses = ['paid', 'ongoing', 'completed'];
    if (!paidStatuses.includes(booking.status) && booking.renterId === userId) {
      booking.listing.lat = booking.listing.lat
        ? Math.round(booking.listing.lat * 100) / 100
        : null;
      booking.listing.lng = booking.listing.lng
        ? Math.round(booking.listing.lng * 100) / 100
        : null;
    }
    return booking;
  }

  // État des lieux voiture (F17)
  async carCheckin(
    userId: string,
    bookingId: string,
    type: 'remise' | 'retour',
    photos: string[],
    km?: number,
    fuelLevel?: string,
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { listing: true },
    });
    if (!booking) throw new NotFoundException('Réservation introuvable');
    if (booking.listing.type !== 'voiture') {
      throw new BadRequestException('État des lieux réservé aux voitures');
    }
    if (booking.renterId !== userId && booking.listing.ownerId !== userId) {
      throw new ForbiddenException();
    }

    const checkin = await this.prisma.carCheckin.create({
      data: { bookingId, type, photos: JSON.stringify(photos), km, fuelLevel },
    });

    if (type === 'remise' && booking.status === 'paid') {
      await this.prisma.booking.update({
        where: { id: bookingId },
        data: { status: 'ongoing' },
      });
    }
    if (type === 'retour' && booking.status === 'ongoing') {
      await this.prisma.booking.update({
        where: { id: bookingId },
        data: { status: 'completed' },
      });
      console.log('[Caution] Remboursement de la caution sous 48 h sans litige');
    }
    return checkin;
  }
}

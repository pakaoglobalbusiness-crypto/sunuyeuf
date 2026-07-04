import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { CreateListingDto, SearchListingsDto, UpdateListingDto } from './listings.dto';

@Injectable()
export class ListingsService {
  constructor(private prisma: PrismaService) {}

  async create(ownerId: string, dto: CreateListingDto) {
    if (dto.type === 'villa' && !dto.villaDetails) {
      throw new BadRequestException('villaDetails requis pour une villa');
    }
    if (dto.type === 'voiture' && !dto.carDetails) {
      throw new BadRequestException('carDetails requis pour une voiture');
    }

    // Photos réelles obligatoires : 5 min pour un logement, 3 min pour
    // une voiture, 7 max (confiance + poids des annonces).
    const minPhotos = dto.type === 'villa' ? 5 : 3;
    const photoCount = dto.photoUrls?.length ?? 0;
    if (photoCount < minPhotos) {
      throw new BadRequestException(
        `Ajoutez au moins ${minPhotos} photos pour ${dto.type === 'villa' ? 'un logement' : 'une voiture'} (${photoCount}/${minPhotos})`,
      );
    }
    if (photoCount > 7) {
      throw new BadRequestException('Maximum 7 photos par annonce');
    }

    const owner = await this.prisma.user.findUniqueOrThrow({ where: { id: ownerId } });
    if (owner.kycStatus !== 'verified') {
      throw new ForbiddenException(
        'KYC requis pour publier une annonce (pièce d’identité + selfie)',
      );
    }

    const listing = await this.prisma.listing.create({
      data: {
        ownerId,
        type: dto.type,
        title: dto.title,
        description: dto.description,
        city: dto.city,
        district: dto.district,
        lat: dto.lat,
        lng: dto.lng,
        pricePerDayFcfa: dto.pricePerDayFcfa,
        depositFcfa: dto.depositFcfa ?? 0,
        cancellationPolicy: dto.cancellationPolicy ?? 'moderate',
        instantBooking: dto.instantBooking ?? false,
        status: 'in_moderation', // modération manuelle au lancement (F19)
        villaDetails: dto.villaDetails ? { create: dto.villaDetails } : undefined,
        carDetails: dto.carDetails ? { create: dto.carDetails } : undefined,
        photos: dto.photoUrls
          ? { create: dto.photoUrls.map((url, order) => ({ url, order })) }
          : undefined,
      },
      include: { villaDetails: true, carDetails: true, photos: true },
    });

    // Le propriétaire bascule automatiquement en rôle owner
    if (owner.role === 'renter') {
      await this.prisma.user.update({ where: { id: ownerId }, data: { role: 'owner' } });
    }
    return listing;
  }

  async update(ownerId: string, id: string, dto: UpdateListingDto) {
    const listing = await this.prisma.listing.findUnique({ where: { id } });
    if (!listing) throw new NotFoundException('Annonce introuvable');
    if (listing.ownerId !== ownerId) throw new ForbiddenException();
    const { villaDetails, carDetails, photoUrls, ...scalars } = dto;

    // Remplacement des photos si fournies (avec respect min/max)
    if (photoUrls) {
      const min = listing.type === 'villa' ? 5 : 3;
      if (photoUrls.length < min) {
        throw new BadRequestException(
          `Ajoutez au moins ${min} photos pour ${listing.type === 'villa' ? 'un logement' : 'une voiture'} (${photoUrls.length}/${min})`,
        );
      }
      if (photoUrls.length > 7) {
        throw new BadRequestException('Maximum 7 photos par annonce');
      }
      await this.prisma.listingPhoto.deleteMany({ where: { listingId: id } });
      await this.prisma.listingPhoto.createMany({
        data: photoUrls.map((url, order) => ({ listingId: id, url, order })),
      });
    }

    return this.prisma.listing.update({
      where: { id },
      data: {
        ...scalars,
        villaDetails: villaDetails ? { update: villaDetails } : undefined,
        carDetails: carDetails ? { update: carDetails } : undefined,
      },
      include: {
        villaDetails: true,
        carDetails: true,
        photos: { orderBy: { order: 'asc' } },
      },
    });
  }

  async search(dto: SearchListingsDto) {
    const where: any = { status: 'published' };
    if (dto.type) where.type = dto.type;
    if (dto.city) where.city = dto.city;
    if (dto.maxPrice) where.pricePerDayFcfa = { lte: dto.maxPrice };
    if (dto.minPrice) {
      where.pricePerDayFcfa = { ...(where.pricePerDayFcfa ?? {}), gte: dto.minPrice };
    }
    if (dto.q) {
      where.OR = [
        { title: { contains: dto.q } },
        { description: { contains: dto.q } },
        { district: { contains: dto.q } },
      ];
    }
    // Exclut les annonces ayant au moins un jour indisponible sur la période
    if (dto.startDate && dto.endDate) {
      where.NOT = {
        availability: {
          some: {
            date: { gte: new Date(dto.startDate), lt: new Date(dto.endDate) },
            status: { in: ['bloque', 'reserve'] },
          },
        },
      };
    }

    const page = dto.page ?? 1;
    const pageSize = Math.min(dto.pageSize ?? 20, 50);
    const [items, total] = await Promise.all([
      this.prisma.listing.findMany({
        where,
        include: {
          photos: { orderBy: { order: 'asc' } },
          villaDetails: true,
          carDetails: true,
          owner: { select: { id: true, name: true, photoUrl: true, avgRating: true, kycStatus: true } },
        },
        orderBy:
          dto.sort === 'price_asc'
            ? { pricePerDayFcfa: 'asc' }
            : dto.sort === 'price_desc'
              ? { pricePerDayFcfa: 'desc' }
              : { avgRating: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.listing.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  async findOne(id: string) {
    const listing = await this.prisma.listing.findUnique({
      where: { id },
      include: {
        photos: { orderBy: { order: 'asc' } },
        villaDetails: true,
        carDetails: true,
        owner: {
          select: { id: true, name: true, photoUrl: true, avgRating: true, ratingCount: true, kycStatus: true, createdAt: true },
        },
      },
    });
    if (!listing || !['published', 'suspended'].includes(listing.status)) {
      throw new NotFoundException('Annonce introuvable');
    }
    // Localisation approximative avant paiement : on arrondit à ~1 km (spec §7)
    return {
      ...listing,
      lat: listing.lat ? Math.round(listing.lat * 100) / 100 : null,
      lng: listing.lng ? Math.round(listing.lng * 100) / 100 : null,
    };
  }

  async myListings(ownerId: string) {
    return this.prisma.listing.findMany({
      where: { ownerId, status: { not: 'archived' } },
      include: { photos: true, villaDetails: true, carDetails: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  // Suppression d'une annonce. Si des réservations existent (historique,
  // paiements), on archive plutôt que détruire ; sinon suppression réelle.
  // isAdmin = true permet à l'admin de supprimer n'importe quelle annonce.
  async remove(userId: string, listingId: string, isAdmin = false) {
    const listing = await this.prisma.listing.findUnique({
      where: { id: listingId },
      include: { _count: { select: { bookings: true } } },
    });
    if (!listing) throw new NotFoundException('Annonce introuvable');
    if (!isAdmin && listing.ownerId !== userId) throw new ForbiddenException();

    if (listing._count.bookings > 0) {
      await this.prisma.listing.update({
        where: { id: listingId },
        data: { status: 'archived' },
      });
      return { deleted: false, archived: true };
    }

    // Aucune réservation : suppression réelle (enfants d'abord)
    await this.prisma.favorite.deleteMany({ where: { listingId } });
    await this.prisma.availability.deleteMany({ where: { listingId } });
    await this.prisma.listingPhoto.deleteMany({ where: { listingId } });
    await this.prisma.villaDetails.deleteMany({ where: { listingId } });
    await this.prisma.carDetails.deleteMany({ where: { listingId } });
    await this.prisma.listing.delete({ where: { id: listingId } });
    return { deleted: true, archived: false };
  }

  // Favoris (wishlist type Airbnb)
  async addFavorite(userId: string, listingId: string) {
    const listing = await this.prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing) throw new NotFoundException('Annonce introuvable');
    await this.prisma.favorite.upsert({
      where: { userId_listingId: { userId, listingId } },
      update: {},
      create: { userId, listingId },
    });
    return { favorite: true };
  }

  async removeFavorite(userId: string, listingId: string) {
    await this.prisma.favorite.deleteMany({ where: { userId, listingId } });
    return { favorite: false };
  }

  async myFavorites(userId: string) {
    const favs = await this.prisma.favorite.findMany({
      where: { userId, listing: { status: 'published' } },
      include: {
        listing: {
          include: {
            photos: { orderBy: { order: 'asc' } },
            villaDetails: true,
            carDetails: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return favs.map((f) => f.listing);
  }

  async myFavoriteIds(userId: string) {
    const favs = await this.prisma.favorite.findMany({
      where: { userId },
      select: { listingId: true },
    });
    return favs.map((f) => f.listingId);
  }

  async setAvailability(ownerId: string, listingId: string, dates: string[], status: 'libre' | 'bloque') {
    const listing = await this.prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing) throw new NotFoundException('Annonce introuvable');
    if (listing.ownerId !== ownerId) throw new ForbiddenException();
    for (const d of dates) {
      const date = new Date(d);
      await this.prisma.availability.upsert({
        where: { listingId_date: { listingId, date } },
        update: { status },
        create: { listingId, date, status },
      });
    }
    return { updated: dates.length };
  }

  async getAvailability(listingId: string, from?: string, to?: string) {
    return this.prisma.availability.findMany({
      where: {
        listingId,
        ...(from && to ? { date: { gte: new Date(from), lte: new Date(to) } } : {}),
      },
      orderBy: { date: 'asc' },
    });
  }
}

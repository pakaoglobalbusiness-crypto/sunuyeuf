import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';

// Détecte un numéro de téléphone dans un message, y compris les tentatives
// de contournement (chiffres espacés/séparés). Objectif : empêcher les
// échanges hors plateforme (spec §7). Un prix comme « 150 000 » (6 chiffres)
// n'est pas bloqué ; un numéro sénégalais fait 9 chiffres.
export function containsPhoneNumber(text: string): boolean {
  // 1) Séquences de chiffres (éventuellement séparés par espaces/./-/… )
  const candidates = text.match(/\+?\d[\d\s.\-/_()]{6,}\d/g) ?? [];
  for (const c of candidates) {
    if (c.replace(/\D/g, '').length >= 8) return true;
  }
  // 2) Préfixe international sénégalais explicite
  if (/\+\s*221/.test(text)) return true;
  // 3) Chiffres écrits en toutes lettres, en série (ex. « sept sept un deux »)
  const words =
    /\b(zero|z[ée]ro|un|deux|trois|quatre|cinq|six|sept|huit|neuf)\b/gi;
  const wordMatches = text.match(words) ?? [];
  if (wordMatches.length >= 7) return true;
  return false;
}

@Injectable()
export class MessagesService {
  constructor(private prisma: PrismaService) {}

  private async assertParticipant(conversationId: string, userId: string) {
    const conv = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { booking: { include: { listing: true } } },
    });
    if (!conv) throw new NotFoundException('Conversation introuvable');
    if (conv.booking.renterId !== userId && conv.booking.listing.ownerId !== userId) {
      throw new ForbiddenException();
    }
    return conv;
  }

  async myConversations(userId: string) {
    return this.prisma.conversation.findMany({
      where: {
        booking: {
          OR: [{ renterId: userId }, { listing: { ownerId: userId } }],
        },
      },
      include: {
        booking: {
          include: {
            listing: { select: { id: true, title: true, type: true, ownerId: true } },
            renter: { select: { id: true, name: true, photoUrl: true } },
          },
        },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getMessages(userId: string, conversationId: string) {
    await this.assertParticipant(conversationId, userId);
    await this.prisma.message.updateMany({
      where: { conversationId, senderId: { not: userId }, readAt: null },
      data: { readAt: new Date() },
    });
    return this.prisma.message.findMany({
      where: { conversationId },
      include: { sender: { select: { id: true, name: true, photoUrl: true } } },
      orderBy: { createdAt: 'asc' },
    });
  }

  async send(userId: string, conversationId: string, body: string, photoUrl?: string) {
    await this.assertParticipant(conversationId, userId);
    if (containsPhoneNumber(body)) {
      throw new BadRequestException(
        'Pour votre sécurité, le partage de numéros de téléphone n’est pas '
          + 'autorisé. Gardez vos échanges et paiements sur Gologui.',
      );
    }
    const message = await this.prisma.message.create({
      data: { conversationId, senderId: userId, body, photoUrl },
      include: { sender: { select: { id: true, name: true, photoUrl: true } } },
    });
    console.log(`[Notif mock] Push nouveau message dans ${conversationId}`);
    return message;
  }
}

import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { kycDocuments: { orderBy: { createdAt: 'desc' } } },
    });
    if (!user) throw new NotFoundException();
    return user;
  }

  async updateProfile(
    userId: string,
    data: {
      name?: string;
      firstName?: string;
      lastName?: string;
      email?: string;
      photoUrl?: string;
      payoutMethod?: string;
      payoutAccount?: string;
      payoutName?: string;
      payoutAddress?: string;
    },
  ) {
    return this.prisma.user.update({ where: { id: userId }, data });
  }

  acceptTerms(userId: string) {
    return this.prisma.user.update({
      where: { id: userId },
      data: { acceptedTermsAt: new Date() },
    });
  }

  // Soumission KYC (F15) — en dev les fichiers sont des URLs ; en prod, upload S3
  async submitKyc(userId: string, docs: { type: string; fileUrl: string }[]) {
    await this.prisma.kycDocument.createMany({
      data: docs.map((d) => ({ userId, type: d.type, fileUrl: d.fileUrl })),
    });
    return this.prisma.user.update({
      where: { id: userId },
      data: { kycStatus: 'pending' },
    });
  }

  async publicProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        photoUrl: true,
        avgRating: true,
        ratingCount: true,
        kycStatus: true,
        createdAt: true,
        reviewsGotten: {
          take: 10,
          orderBy: { createdAt: 'desc' },
          select: {
            rating: true,
            comment: true,
            createdAt: true,
            author: { select: { name: true, photoUrl: true } },
          },
        },
      },
    });
    if (!user) throw new NotFoundException();
    return user;
  }
}

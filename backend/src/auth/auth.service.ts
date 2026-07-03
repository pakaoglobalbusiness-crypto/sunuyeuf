import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma.service';
import { SmsService } from '../notifications/sms.service';
import { OTP_MAX_ATTEMPTS, OTP_TTL_MINUTES } from '../common/constants';

// Si SMS_PROVIDER=mock (défaut en dev), le code est loggé et renvoyé dans
// la réponse API (champ devCode) pour permettre les tests sans compte SMS.
@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private sms: SmsService,
  ) {}

  private normalizePhone(phone: string): string {
    const cleaned = phone.replace(/[\s.-]/g, '');
    if (/^\+221[0-9]{9}$/.test(cleaned)) return cleaned;
    if (/^[0-9]{9}$/.test(cleaned)) return `+221${cleaned}`;
    throw new BadRequestException(
      'Numéro invalide. Format attendu : +221 7X XXX XX XX',
    );
  }

  async requestOtp(phone: string) {
    const normalized = this.normalizePhone(phone);
    let user = await this.prisma.user.findUnique({ where: { phone: normalized } });
    if (user?.blocked) throw new UnauthorizedException('Compte bloqué');
    if (!user) {
      user = await this.prisma.user.create({ data: { phone: normalized } });
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    await this.prisma.otpCode.create({
      data: {
        userId: user.id,
        code,
        expiresAt: new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000),
      },
    });

    await this.sms.send(
      normalized,
      `Gologui : votre code de connexion est ${code}. Valable ${OTP_TTL_MINUTES} min.`,
    );
    return {
      sent: true,
      phone: normalized,
      ...(this.sms.isMock ? { devCode: code } : {}),
    };
  }

  async verifyOtp(phone: string, code: string) {
    const normalized = this.normalizePhone(phone);
    const user = await this.prisma.user.findUnique({ where: { phone: normalized } });
    if (!user) throw new UnauthorizedException('Utilisateur inconnu');
    if (user.blocked) throw new UnauthorizedException('Compte bloqué');

    const otp = await this.prisma.otpCode.findFirst({
      where: { userId: user.id, usedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) throw new UnauthorizedException('Code expiré — redemandez un code');
    if (otp.attempts >= OTP_MAX_ATTEMPTS) {
      throw new UnauthorizedException('Trop de tentatives — redemandez un code');
    }

    if (otp.code !== code) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new UnauthorizedException('Code incorrect');
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { usedAt: new Date() },
    });

    const token = await this.jwt.signAsync({
      sub: user.id,
      phone: user.phone,
      role: user.role,
    });
    return { token, user };
  }
}

import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { AuthGuard, CurrentUser } from '../auth/auth.guard';
import { UsersService } from './users.service';

class UpdateProfileDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() firstName?: string;
  @IsOptional() @IsString() lastName?: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() photoUrl?: string;
  // Coordonnées de paiement (remboursements locataires / gains propriétaires)
  @IsOptional() @IsIn(['wave', 'orange_money', 'free_money', 'bank']) payoutMethod?: string;
  @IsOptional() @IsString() payoutAccount?: string; // numéro Wave OU IBAN
  @IsOptional() @IsString() payoutName?: string; // nom complet / titulaire
  @IsOptional() @IsString() payoutAddress?: string; // adresse (option Wave)
}

class KycDocDto {
  // Identité : recto + verso de la CNI ou du permis de conduire + selfie.
  // carte_grise/assurance restent pour les annonces de voitures (F15).
  @IsIn([
    'cni_recto',
    'cni_verso',
    'permis_recto',
    'permis_verso',
    'selfie',
    'passeport',
    'carte_grise',
    'assurance',
  ])
  type!: string;

  @IsString() @IsNotEmpty() fileUrl!: string;
}

class SubmitKycDto {
  @IsArray() @ValidateNested({ each: true }) @Type(() => KycDocDto) documents!: KycDocDto[];
}

@Controller('users')
export class UsersController {
  constructor(private users: UsersService) {}

  @Get('me')
  @UseGuards(AuthGuard)
  me(@CurrentUser() user: any) {
    return this.users.me(user.id);
  }

  @Patch('me')
  @UseGuards(AuthGuard)
  update(@CurrentUser() user: any, @Body() dto: UpdateProfileDto) {
    return this.users.updateProfile(user.id, dto);
  }

  @Post('me/kyc')
  @UseGuards(AuthGuard)
  kyc(@CurrentUser() user: any, @Body() dto: SubmitKycDto) {
    return this.users.submitKyc(user.id, dto.documents);
  }

  // Acceptation des conditions d'utilisation (obligatoire après l'inscription)
  @Post('me/accept-terms')
  @UseGuards(AuthGuard)
  acceptTerms(@CurrentUser() user: any) {
    return this.users.acceptTerms(user.id);
  }

  @Get(':id/profile')
  profile(@Param('id') id: string) {
    return this.users.publicProfile(id);
  }
}

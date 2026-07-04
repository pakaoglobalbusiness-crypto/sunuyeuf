import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { CANCELLATION_POLICIES, LISTING_TYPES } from '../common/constants';

export class VillaDetailsDto {
  @IsInt() @Min(1) bedrooms!: number;
  @IsInt() @Min(1) bathrooms!: number;
  @IsInt() @Min(1) capacity!: number;
  @IsOptional() @IsBoolean() pool?: boolean;
  @IsOptional() @IsBoolean() wifi?: boolean;
  @IsOptional() @IsBoolean() ac?: boolean;
  @IsOptional() @IsBoolean() guard?: boolean;
}

export class CarDetailsDto {
  @IsString() @IsNotEmpty() brand!: string;
  @IsOptional() @IsString() model?: string;
  @IsInt() @Min(1990) year!: number;
  @IsIn(['manuelle', 'automatique']) gearbox!: string;
  @IsIn(['essence', 'diesel', 'hybride', 'electrique']) fuel!: string;
  @IsOptional() @IsBoolean() withDriver?: boolean;
  @IsOptional() @IsInt() @Min(0) kmIncludedDay?: number;
  @IsIn(['aeroport_aibd', 'domicile', 'agence']) deliveryPlace!: string;
}

export class CreateListingDto {
  @IsIn(LISTING_TYPES as unknown as string[]) type!: string;
  @IsString() @IsNotEmpty() title!: string;
  @IsString() @IsNotEmpty() description!: string;
  @IsString() @IsNotEmpty() city!: string;
  @IsOptional() @IsString() district?: string;
  @IsOptional() @IsNumber() lat?: number;
  @IsOptional() @IsNumber() lng?: number;
  @IsInt() @Min(1000) pricePerDayFcfa!: number;
  @IsOptional() @IsInt() @Min(0) depositFcfa?: number;
  @IsOptional() @IsIn(CANCELLATION_POLICIES as unknown as string[]) cancellationPolicy?: string;
  @IsOptional() @IsBoolean() instantBooking?: boolean;
  @IsOptional() @IsString({ each: true }) photoUrls?: string[];
  @IsOptional() @ValidateNested() @Type(() => VillaDetailsDto) villaDetails?: VillaDetailsDto;
  @IsOptional() @ValidateNested() @Type(() => CarDetailsDto) carDetails?: CarDetailsDto;
}

export class UpdateListingDto {
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() district?: string;
  @IsOptional() @IsInt() @Min(1000) pricePerDayFcfa?: number;
  @IsOptional() @IsInt() @Min(0) depositFcfa?: number;
  @IsOptional() @IsIn(CANCELLATION_POLICIES as unknown as string[]) cancellationPolicy?: string;
  @IsOptional() @IsBoolean() instantBooking?: boolean;
  @IsOptional() @IsString({ each: true }) photoUrls?: string[];
  @IsOptional() @ValidateNested() @Type(() => VillaDetailsDto) villaDetails?: VillaDetailsDto;
  @IsOptional() @ValidateNested() @Type(() => CarDetailsDto) carDetails?: CarDetailsDto;
}

export class SearchListingsDto {
  @IsOptional() @IsIn(LISTING_TYPES as unknown as string[]) type?: string;
  @IsOptional() @IsString() city?: string;
  @IsOptional() @IsString() q?: string;
  @IsOptional() @Type(() => Number) @IsInt() minPrice?: number;
  @IsOptional() @Type(() => Number) @IsInt() maxPrice?: number;
  @IsOptional() @IsString() startDate?: string;
  @IsOptional() @IsString() endDate?: string;
  @IsOptional() @IsIn(['price_asc', 'price_desc', 'rating']) sort?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) pageSize?: number;
}

export class SetAvailabilityDto {
  @IsString({ each: true }) dates!: string[];
  @IsIn(['libre', 'bloque']) status!: 'libre' | 'bloque';
}

import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  IsIn,
  IsInt,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';
import { AuthGuard, CurrentUser } from '../auth/auth.guard';
import { BookingsService } from './bookings.service';

class RequestBookingDto {
  @IsString() @IsNotEmpty() listingId!: string;
  @IsISO8601() startDate!: string;
  @IsISO8601() endDate!: string;
}

class RespondDto {
  @IsIn(['accept', 'reject']) action!: 'accept' | 'reject';
}

class CarCheckinDto {
  @IsIn(['remise', 'retour']) type!: 'remise' | 'retour';
  @IsString({ each: true }) photos!: string[];
  @IsOptional() @IsInt() km?: number;
  @IsOptional() @IsString() fuelLevel?: string;
}

@Controller('bookings')
@UseGuards(AuthGuard)
export class BookingsController {
  constructor(private bookings: BookingsService) {}

  @Post()
  request(@CurrentUser() user: any, @Body() dto: RequestBookingDto) {
    return this.bookings.request(user.id, dto.listingId, dto.startDate, dto.endDate);
  }

  @Get('mine')
  mine(@CurrentUser() user: any) {
    return this.bookings.myBookings(user.id);
  }

  @Get('owner')
  owner(@CurrentUser() user: any) {
    return this.bookings.ownerBookings(user.id);
  }

  @Get(':id')
  findOne(@CurrentUser() user: any, @Param('id') id: string) {
    return this.bookings.findOne(user.id, id);
  }

  @Post(':id/respond')
  respond(@CurrentUser() user: any, @Param('id') id: string, @Body() dto: RespondDto) {
    return this.bookings.respond(user.id, id, dto.action);
  }

  @Delete(':id')
  hide(@CurrentUser() user: any, @Param('id') id: string) {
    return this.bookings.hideBooking(user.id, id);
  }

  @Post(':id/cancel')
  cancel(@CurrentUser() user: any, @Param('id') id: string) {
    return this.bookings.cancel(user.id, id);
  }

  @Post(':id/car-checkin')
  carCheckin(@CurrentUser() user: any, @Param('id') id: string, @Body() dto: CarCheckinDto) {
    return this.bookings.carCheckin(user.id, id, dto.type, dto.photos, dto.km, dto.fuelLevel);
  }
}

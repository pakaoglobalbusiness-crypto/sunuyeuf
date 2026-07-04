import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard';
import { ListingsService } from './listings.service';
import {
  CreateListingDto,
  SearchListingsDto,
  SetAvailabilityDto,
  UpdateListingDto,
} from './listings.dto';

@Controller('listings')
export class ListingsController {
  constructor(private listings: ListingsService) {}

  // Public : recherche et consultation (F2, F3)
  @Get()
  search(@Query() dto: SearchListingsDto) {
    return this.listings.search(dto);
  }

  @Get('mine')
  @UseGuards(AuthGuard)
  mine(@CurrentUser() user: any) {
    return this.listings.myListings(user.id);
  }

  // Favoris (déclarés avant ':id' pour la résolution des routes)
  @Get('favorites/mine')
  @UseGuards(AuthGuard)
  favorites(@CurrentUser() user: any) {
    return this.listings.myFavorites(user.id);
  }

  @Get('favorites/ids')
  @UseGuards(AuthGuard)
  favoriteIds(@CurrentUser() user: any) {
    return this.listings.myFavoriteIds(user.id);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.listings.findOne(id);
  }

  @Post(':id/favorite')
  @UseGuards(AuthGuard)
  addFavorite(@CurrentUser() user: any, @Param('id') id: string) {
    return this.listings.addFavorite(user.id, id);
  }

  @Delete(':id/favorite')
  @UseGuards(AuthGuard)
  removeFavorite(@CurrentUser() user: any, @Param('id') id: string) {
    return this.listings.removeFavorite(user.id, id);
  }

  @Get(':id/availability')
  availability(
    @Param('id') id: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.listings.getAvailability(id, from, to);
  }

  // Propriétaire (F10, F11)
  @Post()
  @UseGuards(AuthGuard)
  create(@CurrentUser() user: any, @Body() dto: CreateListingDto) {
    return this.listings.create(user.id, dto);
  }

  @Patch(':id')
  @UseGuards(AuthGuard)
  update(@CurrentUser() user: any, @Param('id') id: string, @Body() dto: UpdateListingDto) {
    return this.listings.update(user.id, id, dto);
  }

  // Suppression d'une annonce par son propriétaire (ou un admin)
  @Delete(':id')
  @UseGuards(AuthGuard)
  remove(@CurrentUser() user: any, @Param('id') id: string) {
    return this.listings.remove(user.id, id, user.role === 'admin');
  }

  @Post(':id/availability')
  @UseGuards(AuthGuard)
  setAvailability(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() dto: SetAvailabilityDto,
  ) {
    return this.listings.setAvailability(user.id, id, dto.dates, dto.status);
  }
}

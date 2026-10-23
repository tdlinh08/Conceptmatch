import { Body, Controller, Post } from '@nestjs/common';
import { ReviewsService } from './reviews.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('reviews')
export class ReviewsController {
  constructor(private reviewsService: ReviewsService) {}

  @Roles('user')
  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateReviewDto) {
    return this.reviewsService.create(userId, dto);
  }
}

import {
  BadRequestException,
  Body,
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AiService } from './ai.service';
import { Roles } from '../auth/decorators/roles.decorator';

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB — khớp API Contract
const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const DEFAULT_TOP_K = 10;

@Controller('ai')
export class AiController {
  constructor(private aiService: AiService) {}

  @Roles('user')
  @Post('visual-search')
  @UseInterceptors(
    FileInterceptor('image', {
      limits: { fileSize: MAX_FILE_SIZE },
    }),
  )
  async visualSearch(
    @UploadedFile() file: Express.Multer.File,
    @Body('top_k') topKRaw?: string,
  ) {
    if (!file) {
      throw new BadRequestException('Không có file ảnh');
    }
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      throw new BadRequestException('Chỉ nhận JPG/PNG/WEBP');
    }

    const topK = topKRaw ? parseInt(topKRaw, 10) : DEFAULT_TOP_K;
    return this.aiService.visualSearch(file, topK);
  }
}

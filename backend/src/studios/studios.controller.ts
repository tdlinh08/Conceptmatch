import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  UploadedFile,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor, FilesInterceptor } from '@nestjs/platform-express';
import { StudiosService } from './studios.service';
import { CreateStudioDto } from './dto/create-studio.dto';
import { UpdateStudioDto } from './dto/update-studio.dto';
import { QueryStudiosDto } from './dto/query-studios.dto';
import { CreateStudioSetDto } from './dto/create-studio-set.dto';
import { AvailabilityQueryDto } from './dto/availability-query.dto';
import { CreatePackageDto } from './dto/create-package.dto';
import { UpdatePackageDto } from './dto/update-package.dto';
import { CreateStaffDto, UpdateStaffDto } from './dto/staff.dto';
import { CreateAddonDto, UpdateAddonDto } from './dto/addon.dto';
import { UpdateStudioSetDto } from './dto/update-studio-set.dto';
import { deleteLocalMedia, imageUploadOptions, publicUrl } from '../media/media.util';
import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('studios')
export class StudiosController {
  constructor(private studiosService: StudiosService) {}

  @Public()
  @Get()
  findAll(@Query() query: QueryStudiosDto) {
    return this.studiosService.findAll(query);
  }

  // 3 route "chữ" dưới đây BẮT BUỘC khai báo TRƯỚC @Get(':id') — nếu không,
  // NestJS sẽ hiểu "featured"/"style-tags"/"for-you" là giá trị của tham số
  // :id (khớp route theo thứ tự khai báo), gây lỗi 400 "id không phải UUID
  // hợp lệ" thay vì chạy đúng logic mong muốn.

  @Public()
  @Get('featured')
  findFeatured(@Query('limit') limit?: number) {
    return this.studiosService.findFeatured(Number(limit) || 10);
  }

  @Public()
  @Get('style-tags')
  findStyleTags() {
    return this.studiosService.findStyleTags();
  }

  @Roles('user')
  @Get('for-you')
  findForYou(
    @CurrentUser('id') userId: string,
    @Query('limit') limit?: number,
  ) {
    return this.studiosService.findForYou(userId, Number(limit) || 10);
  }

  // ---- Chủ studio: studio của tôi (cũng phải đứng TRƯỚC @Get(':id')) ----

  @Roles('studio_owner')
  @Get('mine')
  findMine(@CurrentUser('id') ownerId: string) {
    return this.studiosService.findMine(ownerId);
  }

  @Roles('studio_owner')
  @Get('mine/:id')
  findMineOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
  ) {
    return this.studiosService.findMineOne(id, ownerId);
  }

  @Public()
  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.studiosService.findOne(id);
  }

  @Roles('studio_owner')
  @Post()
  create(@CurrentUser('id') ownerId: string, @Body() dto: CreateStudioDto) {
    return this.studiosService.create(ownerId, dto);
  }

  @Roles('studio_owner')
  @Put(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: UpdateStudioDto,
  ) {
    return this.studiosService.update(id, ownerId, dto);
  }

  @Public()
  @Get(':id/sets')
  findSets(@Param('id', ParseUUIDPipe) id: string) {
    return this.studiosService.findSets(id);
  }

  @Roles('user')
  @Post(':id/view')
  recordView(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.studiosService.recordView(id, userId);
  }

  @Roles('studio_owner')
  @Post(':id/sets')
  createSet(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: CreateStudioSetDto,
  ) {
    return this.studiosService.createSet(id, ownerId, dto);
  }

  @Roles('studio_owner')
  @Put(':id/sets/:setId')
  updateSet(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('setId', ParseUUIDPipe) setId: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: UpdateStudioSetDto,
  ) {
    return this.studiosService.updateSet(id, setId, ownerId, dto);
  }

  // ---- Ảnh studio (multipart/form-data) ----

  /** Tải lên tối đa 10 ảnh một lần, field "images". */
  @Roles('studio_owner')
  @Post(':id/images')
  @UseInterceptors(FilesInterceptor('images', 10, imageUploadOptions('studios')))
  async addImages(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @UploadedFiles() files: Express.Multer.File[] = [],
  ) {
    const urls = files.map((f) => publicUrl('studios', f.filename));
    try {
      return await this.studiosService.addImages(id, ownerId, urls);
    } catch (err) {
      // Multer đã ghi file xuống đĩa trước khi kiểm tra quyền -> lỗi thì dọn lại
      await Promise.all(urls.map(deleteLocalMedia));
      throw err;
    }
  }

  @Roles('studio_owner')
  @Patch(':id/images/:imageId/cover')
  setCoverImage(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('imageId', ParseUUIDPipe) imageId: string,
    @CurrentUser('id') ownerId: string,
  ) {
    return this.studiosService.setCoverImage(id, ownerId, imageId);
  }

  @Roles('studio_owner')
  @Delete(':id/images/:imageId')
  deleteImage(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('imageId', ParseUUIDPipe) imageId: string,
    @CurrentUser('id') ownerId: string,
  ) {
    return this.studiosService.deleteImage(id, ownerId, imageId);
  }

  // ---- Album ảnh của set (multipart/form-data, field "images") ----

  /** Thêm ảnh vào album 1 bối cảnh; tối đa 10 ảnh / set (tính cả ảnh đã có). */
  @Roles('studio_owner')
  @Post(':id/sets/:setId/images')
  @UseInterceptors(FilesInterceptor('images', 10, imageUploadOptions('sets')))
  async addSetImages(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('setId', ParseUUIDPipe) setId: string,
    @CurrentUser('id') ownerId: string,
    @UploadedFiles() files: Express.Multer.File[] = [],
  ) {
    const urls = files.map((f) => publicUrl('sets', f.filename));
    try {
      return await this.studiosService.addSetImages(id, setId, ownerId, urls);
    } catch (err) {
      await Promise.all(urls.map(deleteLocalMedia)); // lỗi quyền / quá số ảnh -> dọn file vừa ghi
      throw err;
    }
  }

  @Roles('studio_owner')
  @Delete(':id/sets/:setId/images/:imageId')
  deleteSetImage(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('setId', ParseUUIDPipe) setId: string,
    @Param('imageId', ParseUUIDPipe) imageId: string,
    @CurrentUser('id') ownerId: string,
  ) {
    return this.studiosService.deleteSetImage(id, setId, ownerId, imageId);
  }

  /**
   * Tải 1 ảnh (field "image") để dùng làm ảnh đại diện của set.
   * Trả về { url } -> app gửi url này trong avatar_url khi tạo/sửa set.
   */
  @Roles('studio_owner')
  @Post(':id/media')
  @UseInterceptors(FileInterceptor('image', imageUploadOptions('sets')))
  async uploadSetImage(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('Chưa chọn ảnh (field "image")');
    const url = publicUrl('sets', file.filename);
    try {
      await this.studiosService.assertOwner(id, ownerId);
    } catch (err) {
      await deleteLocalMedia(url);
      throw err;
    }
    return { url };
  }

  @Public()
  @Get(':id/availability')
  getAvailability(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: AvailabilityQueryDto,
  ) {
    return this.studiosService.getAvailability(id, query);
  }

  @Public()
  @Get(':id/reviews')
  findReviews(
    @Param('id', ParseUUIDPipe) id: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.studiosService.findReviews(id, Number(page) || 1, Number(limit) || 10);
  }

  // --- Gói thuê của từng set (thay cho /pricing-rules cũ). Khách xem gói qua
  // GET /studios/:id và GET /studios/:id/sets (mỗi set kèm danh sách packages).

  @Roles('studio_owner')
  @Post(':id/sets/:setId/packages')
  createPackage(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('setId', ParseUUIDPipe) setId: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: CreatePackageDto,
  ) {
    return this.studiosService.createPackage(id, setId, ownerId, dto);
  }

  @Roles('studio_owner')
  @Put(':id/sets/:setId/packages/:packageId')
  updatePackage(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('setId', ParseUUIDPipe) setId: string,
    @Param('packageId', ParseUUIDPipe) packageId: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: UpdatePackageDto,
  ) {
    return this.studiosService.updatePackage(id, setId, packageId, ownerId, dto);
  }

  // --- Nhân sự (thợ ảnh / trang điểm) + dịch vụ thêm. Khách xem dịch vụ đang bán
  // và số thợ qua GET /studios/:id (addons, staff_counts) — không lộ tên/SĐT nhân sự.

  @Roles('studio_owner')
  @Get(':id/staff')
  findStaff(@Param('id', ParseUUIDPipe) id: string, @CurrentUser('id') ownerId: string) {
    return this.studiosService.findStaff(id, ownerId);
  }

  @Roles('studio_owner')
  @Post(':id/staff')
  createStaff(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: CreateStaffDto,
  ) {
    return this.studiosService.createStaff(id, ownerId, dto);
  }

  @Roles('studio_owner')
  @Put(':id/staff/:staffId')
  updateStaff(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('staffId', ParseUUIDPipe) staffId: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: UpdateStaffDto,
  ) {
    return this.studiosService.updateStaff(id, staffId, ownerId, dto);
  }

  @Roles('studio_owner')
  @Post(':id/addons')
  createAddon(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: CreateAddonDto,
  ) {
    return this.studiosService.createAddon(id, ownerId, dto);
  }

  @Roles('studio_owner')
  @Put(':id/addons/:addonId')
  updateAddon(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('addonId', ParseUUIDPipe) addonId: string,
    @CurrentUser('id') ownerId: string,
    @Body() dto: UpdateAddonDto,
  ) {
    return this.studiosService.updateAddon(id, addonId, ownerId, dto);
  }
}

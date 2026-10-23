import { PartialType } from '@nestjs/mapped-types';
import { CreateStudioDto } from './create-studio.dto';

// Không cho phép sửa qua route này: status, owner_id (owner cố định từ lúc tạo;
// status chỉ Admin mới đổi được qua route /admin/studios/:id/approve|reject).
export class UpdateStudioDto extends PartialType(CreateStudioDto) {}

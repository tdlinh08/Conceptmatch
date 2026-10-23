import { IsNotEmpty } from 'class-validator';

export class GoogleAuthDto {
  @IsNotEmpty({ message: 'id_token không được để trống' })
  id_token: string;
}

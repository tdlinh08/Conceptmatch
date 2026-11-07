/** Khoảng cách đường chim bay giữa 2 toạ độ (km), công thức Haversine. */
export function distanceKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371; // bán kính Trái Đất (km)
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/** Làm tròn 1 chữ số thập phân để hiển thị ("2.4 km"). */
export const roundKm = (km: number) => Math.round(km * 10) / 10;

import {
  assertValidStart,
  listStartTimes,
  PricingError,
  quotePrice,
  toHHmm,
  toMinutes,
} from './pricing';

// Gói mẫu: 60.000đ gồm 1 người, thêm 40.000đ/người, tối đa 5 người
const PKG = {
  price: 60000,
  included_people: 1,
  extra_person_fee: 40000,
  max_people: 5,
};
const NO_SURCHARGE = {
  evening_start_time: '18:00',
  evening_surcharge_pct: 0,
  weekend_surcharge_pct: 0,
};
const SURCHARGE = {
  evening_start_time: '18:00',
  evening_surcharge_pct: 20,
  weekend_surcharge_pct: 10,
};

// 04/11/2026 là thứ Tư, 07/11/2026 là thứ Bảy
const wed = (h: number, m = 0) => new Date(2026, 10, 4, h, m);
const sat = (h: number, m = 0) => new Date(2026, 10, 7, h, m);

describe('toMinutes / toHHmm', () => {
  it('đổi qua lại giờ và phút', () => {
    expect(toMinutes('08:30')).toBe(510);
    expect(toMinutes('24:00')).toBe(1440);
    expect(toHHmm(510)).toBe('08:30');
  });
  it('từ chối giờ sai định dạng', () => {
    expect(() => toMinutes('8:30')).toThrow(PricingError);
    expect(() => toMinutes('24:30')).toThrow(PricingError);
    expect(() => toMinutes('10:75')).toThrow(PricingError);
  });
});

describe('quotePrice — phụ thu theo số người', () => {
  it('1 người: đúng giá gói', () => {
    expect(quotePrice(PKG, NO_SURCHARGE, 1, wed(9)).total_amount).toBe(60000);
  });
  it('2 người: cộng 1 người vượt mức', () => {
    const q = quotePrice(PKG, NO_SURCHARGE, 2, wed(9));
    expect(q.extra_people_amount).toBe(40000);
    expect(q.total_amount).toBe(100000);
  });
  it('vượt số người tối đa thì báo lỗi', () => {
    expect(() => quotePrice(PKG, NO_SURCHARGE, 6, wed(9))).toThrow(
      'tối đa 5 người',
    );
  });
  it('số người không hợp lệ thì báo lỗi', () => {
    expect(() => quotePrice(PKG, NO_SURCHARGE, 0, wed(9))).toThrow(
      PricingError,
    );
    expect(() => quotePrice(PKG, NO_SURCHARGE, 1.5, wed(9))).toThrow(
      PricingError,
    );
  });
});

describe('quotePrice — phụ thu giờ tối / cuối tuần', () => {
  it('ngày thường, giờ thường: không phụ thu', () => {
    expect(quotePrice(PKG, SURCHARGE, 2, wed(17, 30)).surcharge_pct).toBe(0);
  });
  it('bắt đầu đúng 18:00 tính là giờ tối', () => {
    const q = quotePrice(PKG, SURCHARGE, 2, wed(18));
    expect(q.surcharge_pct).toBe(20);
    expect(q.surcharge_amount).toBe(20000); // 100.000 * 20%
    expect(q.total_amount).toBe(120000);
  });
  it('thứ Bảy buổi tối: cộng dồn 2 loại phụ thu', () => {
    const q = quotePrice(PKG, SURCHARGE, 1, sat(19));
    expect(q.surcharge_pct).toBe(30);
    expect(q.total_amount).toBe(78000); // 60.000 + 18.000
  });
  it('tiền cọc 30%, làm tròn đến 1.000đ', () => {
    // 650.000 * 10% = 65.000 -> tổng 715.000 -> cọc 214.500 -> làm tròn 215.000
    const city = {
      price: 650000,
      included_people: 10,
      extra_person_fee: 0,
      max_people: 30,
    };
    const q = quotePrice(city, SURCHARGE, 3, sat(9));
    expect(q.total_amount).toBe(715000);
    expect(q.deposit_amount).toBe(215000);
  });
});

describe('listStartTimes', () => {
  const base = {
    date: new Date(2026, 10, 4),
    openTime: '08:00',
    closeTime: '12:00',
    now: new Date(2026, 10, 1),
  };

  it('gói 2 tiếng: các giờ bắt đầu cách nhau 30 phút, kết thúc trước giờ đóng cửa', () => {
    const slots = listStartTimes({ ...base, durationMinutes: 120, busy: [] });
    expect(
      slots.map((s) => toHHmm(s.start.getHours() * 60 + s.start.getMinutes())),
    ).toEqual(['08:00', '08:30', '09:00', '09:30', '10:00']);
  });

  it('loại các giờ chồng lên booking đã có', () => {
    const busy = [
      { start: new Date(2026, 10, 4, 9, 0), end: new Date(2026, 10, 4, 10, 0) },
    ];
    const slots = listStartTimes({ ...base, durationMinutes: 60, busy });
    const starts = slots.map(
      (s) => s.start.getHours() * 60 + s.start.getMinutes(),
    );
    // 08:00 (kết thúc 09:00, chạm mép -> hợp lệ), 08:30 chồng, 09:00/09:30 chồng, 10:00 trở đi hợp lệ
    expect(starts.map(toHHmm)).toEqual(['08:00', '10:00', '10:30', '11:00']);
  });

  it('không trả giờ đã qua', () => {
    const now = new Date(2026, 10, 4, 9, 15);
    const slots = listStartTimes({
      ...base,
      durationMinutes: 60,
      busy: [],
      now,
    });
    expect(
      toHHmm(slots[0].start.getHours() * 60 + slots[0].start.getMinutes()),
    ).toBe('09:30');
  });

  it('gói dài hơn giờ mở cửa thì không có giờ nào', () => {
    expect(listStartTimes({ ...base, durationMinutes: 300, busy: [] })).toEqual(
      [],
    );
  });
});

describe('assertValidStart', () => {
  const opts = {
    openTime: '08:00',
    closeTime: '18:00',
    durationMinutes: 120,
    now: new Date(2026, 10, 1),
  };

  it('trả về giờ kết thúc = giờ bắt đầu + thời lượng gói', () => {
    expect(assertValidStart({ ...opts, start: wed(9, 30) })).toEqual(
      wed(11, 30),
    );
  });
  it('từ chối giờ lệch lưới 30 phút', () => {
    expect(() => assertValidStart({ ...opts, start: wed(9, 15) })).toThrow(
      ':00 hoặc :30',
    );
  });
  it('từ chối gói kết thúc sau giờ đóng cửa', () => {
    expect(() => assertValidStart({ ...opts, start: wed(17) })).toThrow(
      PricingError,
    );
  });
  it('từ chối thời điểm quá khứ', () => {
    expect(() =>
      assertValidStart({ ...opts, start: wed(9), now: wed(10) }),
    ).toThrow('quá khứ');
  });
});

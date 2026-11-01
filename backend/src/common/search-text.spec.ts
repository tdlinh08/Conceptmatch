import { normalizeSearch, searchWords } from './search-text';

describe('normalizeSearch — tìm không phân biệt dấu', () => {
  it('bỏ dấu, chữ thường, đ -> d', () => {
    expect(normalizeSearch('Studio Hoa Nắng')).toBe('studio hoa nang');
    expect(normalizeSearch('ĐỐNG ĐA')).toBe('dong da');
    expect(normalizeSearch('Hai Bà Trưng')).toBe('hai ba trung');
  });
  it('gộp khoảng trắng thừa', () => {
    expect(normalizeSearch('  Ngõ   95  ')).toBe('ngo 95');
  });
  it('tách từ khoá thành từng từ', () => {
    expect(searchWords('Nắng  hoa')).toEqual(['nang', 'hoa']);
    expect(searchWords('   ')).toEqual([]);
  });
});

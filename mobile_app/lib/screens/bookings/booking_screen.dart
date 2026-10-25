import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking_models.dart';
import '../../models/studio_detail_model.dart';
import '../../providers/bookings_provider.dart';
import 'booking_success_screen.dart';

/// Màn chọn lịch: chọn set -> chọn ngày -> chọn 1 hoặc nhiều giờ LIỀN NHAU -> đặt.
class BookingScreen extends StatefulWidget {
  final StudioDetailModel studio;
  final String? initialSetId;

  const BookingScreen({super.key, required this.studio, this.initialSetId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

/// Trạng thái hiển thị của một ô giờ.
enum _SlotState { available, booked, past, noPrice }

class _BookingScreenState extends State<BookingScreen> {
  // Khớp với OPENING_HOUR / GOLDEN_HOUR / CLOSING_HOUR trong backend.
  static const int _openHour = 8;
  static const int _goldenHour = 18;
  static const int _closeHour = 22;
  static const int _daysAhead = 14; // cho chọn trong 14 ngày tới
  static const double _depositRatio = 0.3; // khớp DEPOSIT_RATIO trong backend

  late String _setId;
  late DateTime _date;
  final _noteController = TextEditingController();

  AvailabilityResult? _availability;
  bool _loadingSlots = false;
  String? _slotsError;

  int? _rangeStart; // giờ bắt đầu đã chọn (vd 14)
  int? _rangeEnd; // giờ bắt đầu của ô CUỐI đã chọn (vd 15 -> kết thúc 16:00)

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final sets = widget.studio.sets;
    _setId = sets.any((s) => s.id == widget.initialSetId) ? widget.initialSetId! : sets.first.id;

    // Sau 21h thì hôm nay không còn giờ nào -> mặc định chọn ngày mai.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _date = now.hour >= _closeHour - 1 ? today.add(const Duration(days: 1)) : today;

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Dữ liệu
  // ===========================================================================

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
      _rangeStart = null;
      _rangeEnd = null;
    });
    try {
      final result = await context.read<BookingsProvider>().fetchAvailability(
            studioId: widget.studio.id,
            setId: _setId,
            date: _date,
          );
      if (!mounted) return;
      setState(() => _availability = result);
    } on BookingException catch (e) {
      if (!mounted) return;
      setState(() => _slotsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  AvailableSlot? _slotAt(int hour) {
    final slots = _availability?.slots ?? const <AvailableSlot>[];
    for (final s in slots) {
      if (s.hour == hour) return s;
    }
    return null;
  }

  _SlotState _stateOf(int hour) {
    final now = DateTime.now();
    final isToday = _date.year == now.year && _date.month == now.month && _date.day == now.day;
    if (isToday && hour <= now.hour) return _SlotState.past;

    final slot = _slotAt(hour);
    if (slot == null) return _SlotState.booked;
    if (slot.price == null) return _SlotState.noPrice;
    return _SlotState.available;
  }

  bool _isSelected(int hour) =>
      _rangeStart != null && hour >= _rangeStart! && hour <= _rangeEnd!;

  int get _selectedHours => _rangeStart == null ? 0 : _rangeEnd! - _rangeStart! + 1;

  double get _total {
    if (_rangeStart == null) return 0;
    var sum = 0.0;
    for (var h = _rangeStart!; h <= _rangeEnd!; h++) {
      sum += _slotAt(h)?.price ?? 0;
    }
    return sum;
  }

  // ===========================================================================
  // Chọn giờ: chạm 1 ô = chọn ô đó; chạm ô liền kề = nối dài; chạm ô ở đầu/cuối
  // đoạn đang chọn = bỏ ô đó; chạm ô xa = chọn lại từ đầu.
  // ===========================================================================

  void _onSlotTap(int hour) {
    if (_stateOf(hour) != _SlotState.available) return;

    setState(() {
      if (_rangeStart == null) {
        _rangeStart = _rangeEnd = hour;
      } else if (hour == _rangeEnd! + 1) {
        _rangeEnd = hour;
      } else if (hour == _rangeStart! - 1) {
        _rangeStart = hour;
      } else if (_rangeStart == _rangeEnd && hour == _rangeStart) {
        _rangeStart = _rangeEnd = null; // bỏ chọn ô duy nhất
      } else if (hour == _rangeStart) {
        _rangeStart = hour + 1;
      } else if (hour == _rangeEnd) {
        _rangeEnd = hour - 1;
      } else {
        _rangeStart = _rangeEnd = hour; // chạm ô ở giữa hoặc ở xa -> chọn lại
      }
    });
  }

  void _onSelectSet(String setId) {
    if (setId == _setId) return;
    setState(() => _setId = setId);
    _loadSlots();
  }

  void _onSelectDate(DateTime date) {
    if (DateUtils.isSameDay(date, _date)) return;
    setState(() => _date = date);
    _loadSlots();
  }

  Future<void> _submit() async {
    if (_rangeStart == null || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final setName = widget.studio.sets.firstWhere((s) => s.id == _setId).name;
    final start = _rangeStart!;
    final end = _rangeEnd! + 1;

    try {
      final booking = await context.read<BookingsProvider>().createBooking(
            studioId: widget.studio.id,
            setId: _setId,
            date: _date,
            startHour: start,
            endHour: end,
            note: _noteController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            booking: booking,
            studioName: widget.studio.name,
            setName: setName,
            date: _date,
            startHour: start,
            endHour: end,
          ),
        ),
      );
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      // Khung giờ vừa bị người khác đặt mất -> tải lại lịch trống cho đúng.
      if (e.isSlotTaken) _loadSlots();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn lịch chụp'),
            Text(
              widget.studio.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                color: AppColors.textBody,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const _Label('BỐI CẢNH'),
          const SizedBox(height: 10),
          _buildSetChips(),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: _Label('NGÀY')),
              Text(
                'Tháng ${_date.month}/${_date.year}',
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDateStrip(),
          const SizedBox(height: 24),
          const _Label('KHUNG GIỜ'),
          const SizedBox(height: 4),
          const Text(
            'Chạm để chọn, chạm ô bên cạnh để đặt nhiều giờ liền nhau.',
            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
          const SizedBox(height: 12),
          _buildSlotsArea(),
          const SizedBox(height: 12),
          const _Legend(),
          const SizedBox(height: 24),
          const _Label('GHI CHÚ CHO STUDIO'),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            minLines: 1,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ví dụ: cần thêm đèn spotlight, có 2 người mẫu…',
              counterText: '',
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSetChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.studio.sets.map((set) {
        final selected = set.id == _setId;
        return _Pill(
          label: set.name,
          selected: selected,
          onTap: () => _onSelectSet(set.id),
        );
      }).toList(),
    );
  }

  Widget _buildDateStrip() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _daysAhead,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = today.add(Duration(days: i));
          final selected = DateUtils.isSameDay(day, _date);
          final isWeekend = day.weekday >= DateTime.saturday;
          return Semantics(
            button: true,
            selected: selected,
            label: 'Ngày ${day.day} tháng ${day.month}',
            excludeSemantics: true,
            child: Material(
              color: selected ? AppColors.primary : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: selected ? BorderSide.none : const BorderSide(color: AppColors.outline),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _onSelectDate(day),
                child: SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        i == 0 ? 'Nay' : weekdays[day.weekday - 1],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.onPrimary
                              : (isWeekend ? AppColors.accentText : AppColors.textFaint),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.onPrimary : AppColors.textTitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotsArea() {
    if (_loadingSlots) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    if (_slotsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            Text(
              _slotsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.statusError),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadSlots, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    final hours = [for (var h = _openHour; h < _closeHour; h++) h];
    final anyAvailable = hours.any((h) => _stateOf(h) == _SlotState.available);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.75,
          children: [
            for (final h in hours)
              _SlotTile(
                hour: h,
                price: _slotAt(h)?.price,
                state: _stateOf(h),
                selected: _isSelected(h),
                golden: h >= _goldenHour,
                onTap: () => _onSlotTap(h),
              ),
          ],
        ),
        if (!anyAvailable)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Ngày này đã kín lịch. Bạn thử chọn ngày khác hoặc set khác nhé.',
              style: TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final hasSelection = _rangeStart != null;
    final deposit = (_total * _depositRatio).roundToDouble();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: hasSelection
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_two(_rangeStart!)}:00 – ${_two(_rangeEnd! + 1)}:00 · $_selectedHours giờ',
                            style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.vnd(_total),
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: AppColors.textTitle,
                            ),
                          ),
                          Text(
                            'Cọc trước ${Formatters.vnd(deposit)} (30%)',
                            style: const TextStyle(fontSize: 12, color: AppColors.textBody),
                          ),
                        ],
                      )
                    : const Text(
                        'Chọn khung giờ để xem tổng tiền',
                        style: TextStyle(fontSize: 14, color: AppColors.textBody),
                      ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: hasSelection && !_submitting ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                      )
                    : const Text('Đặt lịch'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

// =============================================================================
// Widget con
// =============================================================================

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textFaint,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : const BorderSide(color: AppColors.outlineStrong),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.onPrimary : AppColors.textBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final int hour;
  final double? price;
  final _SlotState state;
  final bool selected;
  final bool golden;
  final VoidCallback onTap;

  const _SlotTile({
    required this.hour,
    required this.price,
    required this.state,
    required this.selected,
    required this.golden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time = '${hour.toString().padLeft(2, '0')}:00';
    final enabled = state == _SlotState.available;

    final String subtitle;
    switch (state) {
      case _SlotState.booked:
        subtitle = 'Đã kín';
      case _SlotState.past:
        subtitle = 'Đã qua';
      case _SlotState.noPrice:
        subtitle = 'Chưa có giá';
      case _SlotState.available:
        subtitle = Formatters.vnd(price!);
    }

    final Color background;
    final Color titleColor;
    final Color subtitleColor;
    final BorderSide border;
    if (selected) {
      background = AppColors.primary;
      titleColor = AppColors.onPrimary;
      subtitleColor = AppColors.onPrimary.withValues(alpha: 0.85);
      border = BorderSide.none;
    } else if (!enabled) {
      background = Colors.transparent;
      titleColor = AppColors.textFaint;
      subtitleColor = AppColors.textFaint;
      border = const BorderSide(color: AppColors.outlineStrong);
    } else if (golden) {
      background = AppColors.surface;
      titleColor = AppColors.textTitle;
      subtitleColor = AppColors.statusWarning;
      border = BorderSide(color: AppColors.statusWarning.withValues(alpha: 0.55), width: 1.2);
    } else {
      background = AppColors.surface;
      titleColor = AppColors.textTitle;
      subtitleColor = AppColors.textBody;
      border = const BorderSide(color: AppColors.outline);
    }

    return Semantics(
      button: enabled,
      selected: selected,
      label: '$time, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: border),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    decoration: state == _SlotState.booked ? TextDecoration.lineThrough : null,
                    decorationColor: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: subtitleColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color fill, BorderSide side, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
                border: Border.fromBorderSide(side),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textBody)),
          ],
        );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(AppColors.primary, BorderSide.none, 'Đang chọn'),
        item(AppColors.surface, BorderSide(color: AppColors.statusWarning.withValues(alpha: 0.7)),
            'Giờ vàng (từ 18:00)'),
        item(Colors.transparent, const BorderSide(color: AppColors.outlineStrong), 'Đã kín / đã qua'),
      ],
    );
  }
}
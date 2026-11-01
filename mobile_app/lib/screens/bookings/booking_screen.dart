import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking_models.dart';
import '../../models/studio_detail_model.dart';
import '../../providers/bookings_provider.dart';
import 'booking_success_screen.dart';

/// Màn chọn lịch theo GÓI: chọn set -> gói -> số người -> ngày -> giờ bắt đầu -> đặt.
/// Giá hiển thị lấy từ backend (GET availability), app không tự tính phụ thu.
class BookingScreen extends StatefulWidget {
  final StudioDetailModel studio;
  final String? initialSetId;
  final String? initialPackageId;

  const BookingScreen({
    super.key,
    required this.studio,
    this.initialSetId,
    this.initialPackageId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const int _daysAhead = 14; // cho chọn trong 14 ngày tới
  static const double _depositRatio = 0.3; // khớp DEPOSIT_RATIO trong backend

  late StudioSetModel _set;
  late RentalPackageModel _package;
  late int _people;
  late DateTime _date;
  final _noteController = TextEditingController();

  AvailabilityResult? _availability;
  bool _loadingSlots = false;
  String? _slotsError;
  String? _selectedStart; // "09:30"
  // Dịch vụ thêm đang tick, theo vai trò (mỗi vai trò tối đa 1 dịch vụ): role -> addonId
  final Map<String, String> _addonByRole = {};
  int _requestId = 0; // bỏ qua kết quả cũ khi người dùng đổi lựa chọn liên tục
  Timer? _peopleDebounce;

  bool _submitting = false;

  List<StudioSetModel> get _bookableSets =>
      widget.studio.sets.where((s) => s.isBookable).toList();

  AvailableSlot? get _selectedSlot {
    final slots = _availability?.slots ?? const <AvailableSlot>[];
    for (final s in slots) {
      if (s.start == _selectedStart) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final sets = _bookableSets; // màn Chi tiết chỉ mở màn này khi có ít nhất 1 set có gói
    _set = sets.firstWhere((s) => s.id == widget.initialSetId, orElse: () => sets.first);
    _package = _set.packages.firstWhere(
      (p) => p.id == widget.initialPackageId,
      orElse: () => _set.packages.first,
    );
    _people = _defaultPeople(_package);

    // Gần giờ đóng cửa thì hôm nay không còn giờ nào -> mặc định chọn ngày mai.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMinutes = now.hour * 60 + now.minute;
    _date = nowMinutes + _package.durationMinutes > _toMinutes(widget.studio.closeTime)
        ? today.add(const Duration(days: 1))
        : today;

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots());
  }

  @override
  void dispose() {
    _noteController.dispose();
    _peopleDebounce?.cancel();
    super.dispose();
  }

  static int _defaultPeople(RentalPackageModel p) =>
      p.includedPeople <= p.maxPeople ? p.includedPeople : p.maxPeople;

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // ===========================================================================
  // Dữ liệu
  // ===========================================================================

  Future<void> _loadSlots() async {
    final requestId = ++_requestId;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });
    try {
      final result = await context.read<BookingsProvider>().fetchAvailability(
            studioId: widget.studio.id,
            packageId: _package.id,
            date: _date,
            numPeople: _people,
            addonIds: _addonByRole.values.toList(),
          );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _availability = result;
        // Giữ giờ đã chọn nếu vẫn còn trống (vd chỉ đổi số người), không thì bỏ chọn.
        if (!result.slots.any((s) => s.start == _selectedStart)) _selectedStart = null;
      });
    } on BookingException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _availability = null;
        _selectedStart = null;
        _slotsError = e.message;
      });
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loadingSlots = false);
    }
  }

  void _onSelectSet(StudioSetModel set) {
    if (set.id == _set.id) return;
    setState(() {
      _set = set;
      _package = set.packages.first;
      _people = _people.clamp(1, _package.maxPeople).toInt();
      _selectedStart = null;
    });
    _loadSlots();
  }

  void _onSelectPackage(RentalPackageModel pkg) {
    if (pkg.id == _package.id) return;
    setState(() {
      _package = pkg;
      _people = _people.clamp(1, pkg.maxPeople).toInt();
      _selectedStart = null; // gói khác thời lượng -> giờ trống khác
    });
    _loadSlots();
  }

  void _onChangePeople(int delta) {
    final next = (_people + delta).clamp(1, _package.maxPeople).toInt();
    if (next == _people) return;
    setState(() => _people = next);
    // Bấm +/- liên tục chỉ gọi API một lần sau khi dừng tay
    _peopleDebounce?.cancel();
    _peopleDebounce = Timer(const Duration(milliseconds: 350), _loadSlots);
  }

  /// Tick / bỏ tick dịch vụ; chọn dịch vụ khác cùng vai trò thì thay dịch vụ cũ.
  void _onToggleAddon(AddonServiceModel addon) {
    setState(() {
      if (_addonByRole[addon.role] == addon.id) {
        _addonByRole.remove(addon.role);
      } else {
        _addonByRole[addon.role] = addon.id;
      }
    });
    _loadSlots(); // cần thợ rảnh -> giờ trống và giá thay đổi
  }

  void _onSelectDate(DateTime date) {
    if (DateUtils.isSameDay(date, _date)) return;
    setState(() {
      _date = date;
      _selectedStart = null;
    });
    _loadSlots();
  }

  Future<void> _submit() async {
    final slot = _selectedSlot;
    if (slot == null || _submitting || _loadingSlots) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final booking = await context.read<BookingsProvider>().createBooking(
            packageId: _package.id,
            date: _date,
            startTime: slot.start,
            numPeople: _people,
            addonIds: _addonByRole.values.toList(),
            note: _noteController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            booking: booking,
            studioName: widget.studio.name,
            setName: _set.name,
          ),
        ),
      );
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      // Khung giờ vừa bị người khác đặt mất -> tải lại lịch trống cho đúng.
      if (e.isSlotTaken) {
        setState(() => _selectedStart = null);
        _loadSlots();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final sets = _bookableSets;

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
          if (sets.length > 1) ...[
            const _Label('BỐI CẢNH'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final set in sets)
                  _Pill(label: set.name, selected: set.id == _set.id, onTap: () => _onSelectSet(set)),
              ],
            ),
            const SizedBox(height: 24),
          ],
          _Label(sets.length > 1 ? 'GÓI THUÊ' : 'GÓI THUÊ · ${_set.name.toUpperCase()}'),
          const SizedBox(height: 10),
          for (final pkg in _set.packages) ...[
            _PackageOption(
              package: pkg,
              selected: pkg.id == _package.id,
              onTap: () => _onSelectPackage(pkg),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          const _Label('SỐ NGƯỜI'),
          const SizedBox(height: 10),
          _buildPeopleStepper(),
          if (widget.studio.addons.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _Label('DỊCH VỤ THÊM'),
            const SizedBox(height: 4),
            const Text(
              'Thợ do studio cung cấp, studio sẽ phân công người cụ thể khi xác nhận đơn.',
              style: TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
            const SizedBox(height: 10),
            for (final addon in widget.studio.addons) ...[
              _AddonOption(
                addon: addon,
                estimate: addon.amountFor(_package.durationMinutes, _people),
                selected: _addonByRole[addon.role] == addon.id,
                onTap: () => _onToggleAddon(addon),
              ),
              const SizedBox(height: 8),
            ],
          ],
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
          const _Label('CHỌN GIỜ'),
          const SizedBox(height: 4),
          Text(
            'Mỗi lựa chọn là một lượt ${Formatters.duration(_package.durationMinutes)} · chỉ hiện giờ còn trống'
            '${_addonByRole.isEmpty ? '' : ' và còn thợ rảnh'} · '
            'studio mở ${widget.studio.isOpen24h ? '24/7' : '${widget.studio.openTime}–${widget.studio.closeTime}'}',
            style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
          const SizedBox(height: 12),
          _buildSlotsArea(),
          if (_surchargeNote() != null) ...[
            const SizedBox(height: 12),
            _InfoNote(text: _surchargeNote()!),
          ],
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
              hintText: 'Ví dụ: cần thêm đèn spotlight, mang theo thú cưng…',
              counterText: '',
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  String? _surchargeNote() {
    final s = widget.studio;
    final parts = <String>[
      if (s.eveningSurchargePct > 0) '+${s.eveningSurchargePct}% nếu bắt đầu từ ${s.eveningStartTime}',
      if (s.weekendSurchargePct > 0) '+${s.weekendSurchargePct}% vào thứ 7, chủ nhật',
    ];
    return parts.isEmpty ? null : 'Phụ thu ${parts.join(', ')}. Giá ở từng giờ đã cộng sẵn.';
  }

  Widget _buildPeopleStepper() {
    final extra = _people - _package.includedPeople;
    final hint = extra > 0
        ? 'Giá gồm ${_package.includedPeople} người · thêm $extra × ${Formatters.vnd(_package.extraPersonFee)}'
        : 'Giá gói đã gồm ${_package.includedPeople} người';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint,
                  style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tối đa ${_package.maxPeople} người',
                  style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            tooltip: 'Bớt 1 người',
            onPressed: _people > 1 ? () => _onChangePeople(-1) : null,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$_people',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: 'Thêm 1 người',
            onPressed: _people < _package.maxPeople ? () => _onChangePeople(1) : null,
          ),
        ],
      ),
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
    if (_loadingSlots && _availability == null) {
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

    final slots = _availability?.slots ?? const <AvailableSlot>[];
    if (slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          _addonByRole.isEmpty
              ? 'Ngày này không còn giờ trống cho gói đã chọn. Bạn thử ngày khác hoặc gói ngắn hơn nhé.'
              : 'Ngày này không còn giờ có cả phòng trống lẫn thợ rảnh. Bạn thử ngày khác hoặc bỏ bớt dịch vụ thêm nhé.',
          style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textBody),
        ),
      );
    }

    // Đang tải lại (vd đổi số người): làm mờ lưới cũ thay vì nháy vòng xoay
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _loadingSlots ? 0.45 : 1,
      child: IgnorePointer(
        ignoring: _loadingSlots,
        child: GridView.count(
          crossAxisCount: 2, // 2 cột đủ chỗ ghi cả giờ kết thúc "15:30 – 17:30"
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: [
            for (final slot in slots)
              _SlotTile(
                slot: slot,
                selected: slot.start == _selectedStart,
                onTap: () => setState(
                  () => _selectedStart = slot.start == _selectedStart ? null : slot.start,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final slot = _selectedSlot;
    // Làm tròn đến 1.000đ giống backend; số cuối cùng vẫn lấy theo đơn backend trả về.
    final deposit = slot == null ? 0.0 : ((slot.price * _depositRatio) / 1000).round() * 1000.0;

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
                child: slot != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_dayShort(_date)} · ${slot.start} – ${slot.end} · $_people người',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.vnd(slot.price),
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
                        'Chọn giờ bắt đầu để xem tổng tiền',
                        style: TextStyle(fontSize: 14, color: AppColors.textBody),
                      ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: slot != null && !_submitting && !_loadingSlots ? _submit : null,
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

  static String _dayShort(DateTime d) {
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return '${weekdays[d.weekday - 1]} ${d.day}/${d.month}';
  }
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

/// Một gói để chọn: viền đậm + dấu tích khi đang chọn.
class _PackageOption extends StatelessWidget {
  final RentalPackageModel package;
  final bool selected;
  final VoidCallback onTap;

  const _PackageOption({required this.package, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = package;
    final peopleText = p.extraPersonFee > 0
        ? 'Gồm ${p.includedPeople} người · +${Formatters.vnd(p.extraPersonFee)}/người thêm · tối đa ${p.maxPeople}'
        : 'Tối đa ${p.maxPeople} người, không phụ thu theo người';

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.surfacePink : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.textFaint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTitle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.vnd(p.price),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTitle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.duration(p.durationMinutes),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        peopleText,
                        style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textBody),
                      ),
                      if (p.description != null && p.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          p.description!.trim(),
                          style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textFaint),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Một dịch vụ thêm có ô tick; kèm số tiền ước tính cho gói + số người đang chọn.
class _AddonOption extends StatelessWidget {
  final AddonServiceModel addon;
  final double estimate;
  final bool selected;
  final VoidCallback onTap;

  const _AddonOption({
    required this.addon,
    required this.estimate,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.surfacePink : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.textFaint,
                ),
                const SizedBox(width: 12),
                Icon(
                  addon.role == StaffRoles.makeup ? Icons.brush_outlined : Icons.photo_camera_outlined,
                  size: 18,
                  color: AppColors.accentText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addon.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                      Text(
                        '${Formatters.vnd(addon.price)}${addon.unitLabel}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textBody),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+${Formatters.vnd(estimate)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.textTitle : AppColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceMuted,
        foregroundColor: AppColors.textTitle,
        disabledBackgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.5),
        disabledForegroundColor: AppColors.textFaint.withValues(alpha: 0.5),
        minimumSize: const Size(44, 44),
      ),
    );
  }
}

/// Ô giờ bắt đầu: giờ + giá. Giờ có phụ thu viền vàng đậm và ghi "+20%".
class _SlotTile extends StatelessWidget {
  final AvailableSlot slot;
  final bool selected;
  final VoidCallback onTap;

  const _SlotTile({required this.slot, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasSurcharge = slot.surchargePct > 0;

    final Color background;
    final Color titleColor;
    final Color subtitleColor;
    final BorderSide border;
    if (selected) {
      background = AppColors.primary;
      titleColor = AppColors.onPrimary;
      subtitleColor = AppColors.onPrimary.withValues(alpha: 0.85);
      border = BorderSide.none;
    } else if (hasSurcharge) {
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

    final price = Formatters.vnd(slot.price);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Bắt đầu ${slot.start}, kết thúc ${slot.end}, $price'
          '${hasSurcharge ? ', đã gồm phụ thu ${slot.surchargePct}%' : ''}',
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: border),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${slot.start} – ${slot.end}', // ghi rõ cả giờ kết thúc: đây là 1 lượt trọn gói
                  maxLines: 1,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: titleColor),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                    ),
                    if (hasSurcharge)
                      Text(
                        '+${slot.surchargePct}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline_rounded, size: 16, color: AppColors.statusWarning),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textBody),
          ),
        ),
      ],
    );
  }
}

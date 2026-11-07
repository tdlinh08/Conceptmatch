import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/owner_studios_provider.dart' show OwnerActionException;
import 'admin_ui.dart';

/// Trang NGƯỜI DÙNG: tìm theo tên / email, lọc vai trò + trạng thái, khoá / mở khoá.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => AdminUsersPageState();
}

class AdminUsersPageState extends State<AdminUsersPage> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  Timer? _debounce;
  String? _role; // null = tất cả
  String? _status;

  List<AdminUserRow> _rows = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    _page = 0;
    _rows = [];
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<AdminProvider>().users(
            keyword: _search.text,
            role: _role,
            status: _status,
            page: _page + 1,
            limit: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...res.items];
        _total = res.total;
        _page++;
      });
    } on OwnerActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _lock(AdminUserRow u) async {
    final reason = await askReason(
      context,
      title: 'Khoá tài khoản ${u.fullName}?',
      hint: 'Người dùng sẽ bị đăng xuất và không đăng nhập được',
      confirmLabel: 'Khoá',
      quick: const ['Đặt lịch ảo nhiều lần', 'Đánh giá sai sự thật', 'Vi phạm điều khoản sử dụng'],
    );
    if (reason == null || !mounted) return;
    try {
      await context.read<AdminProvider>().lockUser(u.id, reason);
      if (mounted) _toast('Đã khoá tài khoản');
      load();
    } on OwnerActionException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _unlock(AdminUserRow u) async {
    try {
      await context.read<AdminProvider>().unlockUser(u.id);
      if (mounted) _toast('Đã mở khoá tài khoản');
      load();
    } on OwnerActionException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Widget _filter(String label, bool selected, VoidCallback onTap) =>
      ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Người dùng',
      subtitle: '$_total tài khoản',
      onRefresh: load,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _search,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), load);
                },
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Tên hoặc email',
                ),
              ),
            ),
            for (final (value, label) in [
              (null, 'Mọi vai trò'),
              ('user', 'Khách hàng'),
              ('studio_owner', 'Chủ studio'),
              ('admin', 'Quản trị'),
            ])
              _filter(label, _role == value, () {
                setState(() => _role = value);
                load();
              }),
            _filter('Đang bị khoá', _status == 'locked', () {
              setState(() => _status = _status == 'locked' ? null : 'locked');
              load();
            }),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null && _rows.isEmpty)
          Column(
            children: [
              Text(_error!),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: load, child: const Text('Thử lại')),
            ],
          )
        else if (!_loading && _rows.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text('Không có tài khoản phù hợp.', textAlign: TextAlign.center),
          )
        else
          AdminCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _UserRow(user: _rows[i], onLock: _lock, onUnlock: _unlock),
              ],
            ],
          ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (_rows.length < _total)
          Center(
            child: OutlinedButton(
              onPressed: _loadMore,
              child: Text('Xem thêm (${_total - _rows.length})'),
            ),
          ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final AdminUserRow user;
  final void Function(AdminUserRow) onLock;
  final void Function(AdminUserRow) onUnlock;

  const _UserRow({required this.user, required this.onLock, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final u = user;
    final name = u.fullName.trim();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: u.isLocked ? AppColors.surfaceMuted : AppColors.surfacePink,
        child: Text(
          name.isEmpty ? '?' : name.split(' ').last[0].toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentText),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(u.fullName, overflow: TextOverflow.ellipsis)),
          if (u.isLocked) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock_rounded, size: 16, color: AppColors.statusError),
          ],
        ],
      ),
      subtitle: Text(
        '${u.email} · ${AdminUserRow.roleLabel(u.role)} · tham gia ${fmtDate(u.createdAt)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: u.role == 'admin'
          ? null
          : u.isLocked
              ? OutlinedButton(onPressed: () => onUnlock(u), child: const Text('Mở khoá'))
              : TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.statusError),
                  onPressed: () => onLock(u),
                  child: const Text('Khoá'),
                ),
    );
  }
}

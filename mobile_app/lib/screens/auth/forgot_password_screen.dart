import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';

/// Quên mật khẩu – 2 bước trên cùng một màn:
///   Bước 1: nhập email → POST /auth/forgot-password (gửi mã 6 số qua email)
///   Bước 2: nhập mã + mật khẩu mới → POST /auth/reset-password
/// Thành công thì quay về màn Đăng nhập (điền sẵn email).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendSeconds = 60; // khớp với thời gian chờ ở backend

  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false; // false = bước 1, true = bước 2
  bool _loading = false;
  bool _obscure = true;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    if (!_codeSent && !_emailForm.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.post(
        '/auth/forgot-password',
        data: {'email': _email.text.trim()},
      );
      if (!mounted) return;
      final msg = (res.data is Map ? res.data['message'] : null)?.toString();
      setState(() => _codeSent = true);
      _startCountdown();
      _toast(msg ?? 'Đã gửi mã xác nhận, vui lòng kiểm tra email');
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e, fallback: 'Không gửi được mã, vui lòng thử lại'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    if (!_resetForm.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.post(
        '/auth/reset-password',
        data: {
          'email': _email.text.trim(),
          'code': _code.text.trim(),
          'new_password': _password.text,
        },
      );
      if (!mounted) return;
      final msg = (res.data is Map ? res.data['message'] : null)?.toString();
      _toast(msg ?? 'Đặt lại mật khẩu thành công');
      Navigator.of(context).pop(_email.text.trim()); // trả email về màn Đăng nhập
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e, fallback: 'Không đặt lại được mật khẩu'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: _codeSent ? _buildStep2() : _buildStep1(),
        ),
      ),
    );
  }

  Widget _stepTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textBody)),
          const SizedBox(height: 24),
        ],
      );

  Widget _submitButton(String label, VoidCallback onPressed) => FilledButton(
        onPressed: _loading ? null : onPressed,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
              )
            : Text(label),
      );

  // ---------------- Bước 1: nhập email
  Widget _buildStep1() {
    return Form(
      key: _emailForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(
            'Nhập email đã đăng ký',
            'Chúng tôi sẽ gửi một mã xác nhận gồm 6 chữ số tới email này để bạn đặt lại mật khẩu.',
          ),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_loading) _sendCode();
            },
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
              if (!v.contains('@')) return 'Email không hợp lệ';
              return null;
            },
          ),
          const SizedBox(height: 24),
          _submitButton('Gửi mã xác nhận', _sendCode),
        ],
      ),
    );
  }

  // ---------------- Bước 2: nhập mã + mật khẩu mới
  Widget _buildStep2() {
    return Form(
      key: _resetForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(
            'Nhập mã xác nhận',
            'Mã gồm 6 chữ số đã được gửi tới ${_email.text.trim()}. Mã có hiệu lực 15 phút. '
                'Nếu không thấy, hãy kiểm tra thư mục Thư rác (Spam).',
          ),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'Mã xác nhận', counterText: ''),
            validator: (v) => (v == null || v.length != 6) ? 'Mã xác nhận gồm 6 chữ số' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: (_loading || _countdown > 0) ? null : _sendCode,
              child: Text(_countdown > 0 ? 'Gửi lại mã sau ${_countdown}s' : 'Gửi lại mã'),
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
              helperText: 'Tối thiểu 8 ký tự',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.length < 8) ? 'Mật khẩu tối thiểu 8 ký tự' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_loading) _reset();
            },
            decoration: const InputDecoration(
              labelText: 'Nhập lại mật khẩu mới',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
          ),
          const SizedBox(height: 24),
          _submitButton('Đặt lại mật khẩu', _reset),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _codeSent = false;
                      _code.clear();
                    }),
            child: const Text('Đổi email khác'),
          ),
        ],
      ),
    );
  }
}

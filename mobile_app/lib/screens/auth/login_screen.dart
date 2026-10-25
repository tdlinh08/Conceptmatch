import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus(); // ẩn bàn phím để thấy thông báo lỗi (nếu có)
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        // SỬA LỖI "BOTTOM OVERFLOWED": trước đây Column đứng yên, khi bàn phím
        // bật lên chiều cao còn lại không đủ chứa hết ô nhập + nút -> tràn.
        // Center + SingleChildScrollView: đủ chỗ thì nằm giữa màn hình như cũ,
        // thiếu chỗ (bàn phím mở) thì cho cuộn được.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // vuốt để ẩn bàn phím
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset('assets/images/logo.png', width: 88, height: 88),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ConceptMatch',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Trước đây chữ trắng 70% -> gần như vô hình trên nền sáng.
                    const Text(
                      'Đăng nhập để tiếp tục',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: AppColors.textBody),
                    ),
                    const SizedBox(height: 32),

                    // Ô nhập dùng style chung từ theme (nền trắng, viền mảnh,
                    // viền Night Plum khi đang nhập) — bỏ style riêng của bản tối cũ.
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next, // phím "Tiếp" nhảy sang ô mật khẩu
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email';
                        if (!value.contains('@')) return 'Email không hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done, // phím "Xong" -> đăng nhập luôn
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) {
                        if (!authProvider.isLoading) _submit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: authProvider.isLoading ? null : _submit,
                      child: authProvider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Đăng nhập'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
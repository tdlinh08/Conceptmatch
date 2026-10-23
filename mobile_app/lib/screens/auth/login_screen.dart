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

  // Style riêng cho ô nhập liệu trên nền navy — không dùng theme sáng mặc
  // định của app (chỉ màn hình này có nền tối, nên cần override cục bộ).
  InputDecoration _fieldDecoration(String label, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.surfaceVariant, // trước đây là Colors.white
    labelStyle: const TextStyle(color: AppColors.textSecondary), // trước đây AppColors.border
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.accent, width: 2),
    ),
    suffixIcon: suffixIcon,
  );
}

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      // Nền navy đậm riêng cho màn này — đóng vai trò "màn khởi động"
      // theo đúng mô tả trong kịch bản màu, không đổi theme toàn app.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 96,
                    height: 96,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ConceptMatch',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đăng nhập để tiếp tục',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 36),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _fieldDecoration('Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Vui lòng nhập email';
                    if (!value.contains('@')) return 'Email không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _fieldDecoration(
                    'Mật khẩu',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.border,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
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
                            color: AppColors.onAccent,
                          ),
                        )
                      : const Text('Đăng nhập'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

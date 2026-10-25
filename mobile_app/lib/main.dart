import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/studios_provider.dart';
import 'providers/favorites_provider.dart';
import 'screens/auth/auth_wrapper.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_background.dart';

void main() {
  runApp(const ConceptMatchApp());
}

class ConceptMatchApp extends StatelessWidget {
  const ConceptMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudiosProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: MaterialApp(
        title: 'ConceptMatch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          // AnnotatedRegion: icon thanh trạng thái màu tối (vì nền app sáng),
          // áp dụng cho MỌI màn, kể cả màn không có AppBar như Home.
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.systemOverlay,
            child: Stack(
              children: [
                const AppBackground(),
                if (child != null) child,
              ],
            ),
          );
        },
        home: const AuthWrapper(),
      ),
    );
  }
}
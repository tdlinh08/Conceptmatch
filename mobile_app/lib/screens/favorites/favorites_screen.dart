import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/favorites_provider.dart';
import '../studios/widgets/studio_card.dart';
import '../studios/studio_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesProvider>().fetchFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FavoritesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Studio yêu thích')),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(FavoritesProvider provider) {
    if (provider.isLoading && provider.favoriteStudios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.favoriteStudios.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.textSecondary, size: 48),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => provider.fetchFavorites(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.favoriteStudios.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, color: AppColors.textSecondary, size: 56),
              SizedBox(height: 12),
              Text(
                'Bạn chưa có studio yêu thích nào',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchFavorites(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.favoriteStudios.length,
        itemBuilder: (context, index) {
          final studio = provider.favoriteStudios[index];
          return StudioCard(
            studio: studio,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StudioDetailScreen(studioId: studio.id)),
              );
            },
          );
        },
      ),
    );
  }
}

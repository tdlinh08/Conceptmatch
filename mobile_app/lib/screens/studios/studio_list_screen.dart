import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/studios_provider.dart';
import 'widgets/studio_card.dart';

class StudioListScreen extends StatefulWidget {
  const StudioListScreen({super.key});

  @override
  State<StudioListScreen> createState() => _StudioListScreenState();
}

class _StudioListScreenState extends State<StudioListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudiosProvider>().fetchStudios();
    });

    _scrollController.addListener(() {
      final provider = context.read<StudiosProvider>();
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          provider.hasMore &&
          !provider.isLoading) {
        provider.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studiosProvider = context.watch<StudiosProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Khám phá Studio')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên studio...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          context.read<StudiosProvider>().search('');
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) => context.read<StudiosProvider>().search(value.trim()),
            ),
          ),
          Expanded(child: _buildBody(studiosProvider)),
        ],
      ),
    );
  }

  Widget _buildBody(StudiosProvider provider) {
    if (provider.isLoading && provider.studios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.studios.isEmpty) {
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
                onPressed: () => provider.fetchStudios(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.studios.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy studio nào phù hợp',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchStudios(keyword: _searchController.text.trim()),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: provider.studios.length + (provider.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= provider.studios.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final studio = provider.studios[index];
          return StudioCard(
            studio: studio,
            onTap: () {
              // TODO: điều hướng sang Studio Detail — sẽ làm ở Giai đoạn 2.
            },
          );
        },
      ),
    );
  }
}

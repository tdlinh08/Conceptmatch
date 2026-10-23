import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/studios_provider.dart';
import 'widgets/studio_card.dart';
import 'studio_detail_screen.dart';

class AllStudiosScreen extends StatefulWidget {
  final String? initialStyleTag;
  final String? initialKeyword;

  const AllStudiosScreen({super.key, this.initialStyleTag, this.initialKeyword});

  @override
  State<AllStudiosScreen> createState() => _AllStudiosScreenState();
}

class _AllStudiosScreenState extends State<AllStudiosScreen> {
  late final TextEditingController _searchController;
  final _scrollController = ScrollController();
  String? _selectedStyleTag;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialKeyword ?? '');
    _selectedStyleTag = widget.initialStyleTag;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StudiosProvider>();
      provider.fetchStudios(
        keyword: widget.initialKeyword,
        styleTag: widget.initialStyleTag,
      );
      if (provider.styleTags.isEmpty) {
        provider.fetchStyleTags();
      }
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

  void _applyFilters() {
    context.read<StudiosProvider>().fetchStudios(
          keyword: _searchController.text.trim(),
          styleTag: _selectedStyleTag,
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudiosProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả Studio')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên studio...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _applyFilters(),
            ),
          ),
          if (provider.styleTags.isNotEmpty) _buildStyleTagFilter(provider),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildStyleTagFilter(StudiosProvider provider) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip('Tất cả', _selectedStyleTag == null, () {
            setState(() => _selectedStyleTag = null);
            _applyFilters();
          }),
          ...provider.styleTags.map(
            (tag) => _filterChip(tag, _selectedStyleTag == tag, () {
              setState(() => _selectedStyleTag = tag);
              _applyFilters();
            }),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    final displayLabel =
        label.isEmpty ? label : '${label[0].toUpperCase()}${label.substring(1)}';
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        label: Text(displayLabel),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.accent,
        backgroundColor: AppColors.surfaceVariant,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        side: BorderSide.none,
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
              FilledButton(onPressed: _applyFilters, child: const Text('Thử lại')),
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
      onRefresh: () async => _applyFilters(),
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

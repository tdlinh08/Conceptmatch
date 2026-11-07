import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/location_service.dart';
import '../../providers/owner_studios_provider.dart';
import 'map_tiles.dart';

/// Màn GHIM VỊ TRÍ: tìm địa chỉ (hoặc dùng vị trí hiện tại) để bản đồ nhảy tới,
/// rồi kéo bản đồ cho mũi ghim ở giữa nằm đúng cổng studio và bấm Lưu.
/// Trả về LatLng qua Navigator.pop (null = huỷ).
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  final String? address; // điền sẵn vào ô tìm kiếm

  const LocationPickerScreen({super.key, this.initial, this.address});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  late final TextEditingController _search = TextEditingController(text: widget.address ?? '');
  late LatLng _center = widget.initial ?? LocationService.hanoi;
  bool _locating = false;
  bool _searching = false;
  List<AddressResult>? _results; // null = đang không hiện danh sách

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _goToMe() async {
    setState(() => _locating = true);
    try {
      final me = await LocationService.current();
      _map.move(me, 17);
      setState(() => _center = me);
    } on LocationException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _doSearch() async {
    final q = _search.text.trim();
    FocusScope.of(context).unfocus();
    if (q.length < 3) {
      _toast('Nhập ít nhất 3 ký tự, vd "45 Phố Huế, Hai Bà Trưng"');
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await context.read<OwnerStudiosProvider>().searchAddress(q);
      if (!mounted) return;
      setState(() => _results = results);
      if (results.isEmpty) {
        _toast('Không tìm thấy. Thử bỏ số nhà, chỉ gõ tên đường + quận.');
      }
    } on OwnerActionException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _choose(AddressResult r) {
    final p = LatLng(r.latitude, r.longitude);
    _map.move(p, 17);
    setState(() {
      _center = p;
      _results = null;
    });
    _toast('Kéo nhẹ bản đồ để mũi ghim nằm đúng cổng studio');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ghim vị trí studio')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial == null ? 13 : 17,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // không xoay bản đồ
              ),
              onPositionChanged: (camera, hasGesture) => setState(() => _center = camera.center),
              onTap: (_, _) => setState(() => _results = null),
            ),
            children: [osmTileLayer(), osmAttribution()],
          ),
          // Mũi ghim cố định ở GIỮA màn: đầu nhọn chạm đúng tâm bản đồ
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: AppColors.statusError),
              ),
            ),
          ),

          // ---- Ô tìm địa chỉ + danh sách kết quả ----
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: AppColors.surface,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(16),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _doSearch(),
                    decoration: InputDecoration(
                      hintText: 'Tìm địa chỉ, vd: 45 Phố Huế, Hai Bà Trưng',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Tìm',
                              icon: const Icon(Icons.arrow_forward_rounded),
                              onPressed: _doSearch,
                            ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (_results != null && _results!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Material(
                    color: AppColors.surface,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _results!.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _results![i];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(r.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () => _choose(r),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton.small(
              heroTag: 'locate_me',
              tooltip: 'Vị trí của tôi',
              onPressed: _locating ? null : _goToMe,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tìm địa chỉ hoặc bấm nút định vị, sau đó kéo bản đồ cho mũi ghim đỏ nằm đúng cổng studio.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textFaint),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_center),
                child: const Text('Lưu vị trí này'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

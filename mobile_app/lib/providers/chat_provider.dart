import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/realtime_client.dart';
import '../models/chat_models.dart';

/// Tin nhắn giữa khách hàng và chủ studio.
///
/// - Danh sách hội thoại + tổng số tin chưa đọc (chấm đỏ ở nút Tin nhắn).
/// - Hội thoại đang mở: tin nhắn tải theo trang (mới nhất trước), gửi tin qua REST.
/// - Nghe socket: tin mới -> chèn vào hội thoại đang mở / đẩy hội thoại lên đầu danh sách;
///   phía bên kia đã đọc -> hiện "Đã xem".
class ChatProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final RealtimeClient _realtime = RealtimeClient();
  final List<StreamSubscription<dynamic>> _subs = [];

  static const _pageSize = 30;

  String? _myId;
  String? get myId => _myId;

  // ---- Danh sách hội thoại ----
  List<ConversationSummary> conversations = [];
  int unreadTotal = 0;
  bool isLoadingList = false;
  String? listError;

  // ---- Hội thoại đang mở ----
  String? activeId;

  /// Tin nhắn của hội thoại đang mở, CŨ trước MỚI sau (để vẽ từ trên xuống).
  List<ChatMessage> messages = [];
  bool isLoadingMessages = false;
  bool hasMore = false;
  int _page = 1;
  String? messagesError;

  ChatProvider() {
    _subs.add(_realtime.messages.listen(_onMessage));
    _subs.add(_realtime.messagesRead.listen(_onRead));
    _subs.add(_realtime.reconnected.listen((_) => _onReconnected()));
  }

  /// Gọi khi đăng nhập xong (biết mình là ai để phân biệt tin của mình / của người kia).
  void start(String userId) {
    _myId = userId;
    fetchUnreadCount();
  }

  /// Đăng xuất: xoá dữ liệu của tài khoản cũ.
  void reset() {
    _myId = null;
    conversations = [];
    unreadTotal = 0;
    listError = null;
    activeId = null;
    messages = [];
    hasMore = false;
    notifyListeners();
  }

  Future<void> fetchUnreadCount() async {
    try {
      final res = await _api.dio.get('/conversations/unread-count');
      unreadTotal = ((res.data as Map<String, dynamic>)['unread_total'] as num).toInt();
      notifyListeners();
    } catch (_) {
      // Không có số chưa đọc cũng không sao.
    }
  }

  Future<void> fetchConversations() async {
    isLoadingList = true;
    listError = null;
    notifyListeners();
    try {
      final res = await _api.dio.get('/conversations');
      final data = res.data as Map<String, dynamic>;
      conversations = (data['data'] as List)
          .map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      unreadTotal = (data['unread_total'] as num).toInt();
    } catch (_) {
      listError = 'Không tải được tin nhắn. Kiểm tra lại kết nối.';
    } finally {
      isLoadingList = false;
      notifyListeners();
    }
  }

  /// Khách bấm "Nhắn tin" ở trang studio. Trả về hội thoại, hoặc ném chuỗi lỗi.
  Future<ConversationSummary> openWithStudio(String studioId) async {
    try {
      final res = await _api.dio.post('/conversations', data: {'studio_id': studioId});
      return ConversationSummary.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Hội thoại đang mở
  // ---------------------------------------------------------------------------

  Future<void> openConversation(String conversationId) async {
    activeId = conversationId;
    messages = [];
    hasMore = false;
    _page = 1;
    messagesError = null;
    notifyListeners();
    await _loadPage(1);
  }

  void closeConversation(String conversationId) {
    if (activeId == conversationId) {
      activeId = null;
      messages = [];
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMessages || activeId == null) return;
    await _loadPage(_page + 1);
  }

  Future<void> _loadPage(int page) async {
    final id = activeId;
    if (id == null) return;
    isLoadingMessages = true;
    notifyListeners();
    try {
      final res = await _api.dio.get(
        '/conversations/$id/messages',
        queryParameters: {'page': page, 'limit': _pageSize},
      );
      if (activeId != id) return; // người dùng đã rời màn này
      final data = res.data as Map<String, dynamic>;
      final batch = (data['data'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();
      final total = (data['total'] as num).toInt();
      if (page == 1) {
        messages = batch;
        _markLocalRead(id); // trang đầu: server đã đánh dấu đã đọc
      } else {
        final known = messages.map((m) => m.id).toSet();
        messages = [...batch.where((m) => !known.contains(m.id)), ...messages];
      }
      _page = page;
      hasMore = page * _pageSize < total;
      messagesError = null;
    } catch (_) {
      if (page == 1) messagesError = 'Không tải được tin nhắn.';
    } finally {
      isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// Gửi tin. Trả về null nếu thành công, hoặc câu báo lỗi.
  Future<String?> send(String conversationId, String text) async {
    final content = text.trim();
    if (content.isEmpty) return 'Tin nhắn không được để trống';
    try {
      final res = await _api.dio.post(
        '/conversations/$conversationId/messages',
        data: {'content': content},
      );
      // Socket cũng sẽ báo tin này; _addMessage tự bỏ qua bản trùng.
      _addMessage(ChatMessage.fromJson(res.data as Map<String, dynamic>));
      return null;
    } on DioException catch (e) {
      return _message(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Sự kiện real-time
  // ---------------------------------------------------------------------------

  void _onMessage(Map<String, dynamic> json) {
    try {
      _addMessage(ChatMessage.fromJson(json));
    } catch (_) {}
  }

  void _addMessage(ChatMessage m) {
    final mine = m.senderId == _myId;
    final isActive = m.conversationId == activeId;
    var changed = false;

    if (isActive && !messages.any((x) => x.id == m.id)) {
      messages = [...messages, m];
      changed = true;
      // Đang mở đúng hội thoại -> tin của người kia coi như đã đọc ngay.
      if (!mine) _api.dio.patch('/conversations/${m.conversationId}/read').ignore();
    }

    final i = conversations.indexWhere((c) => c.id == m.conversationId);
    if (i >= 0) {
      final c = conversations[i];
      final isNewer = c.lastMessageAt == null || !m.sentAt.isBefore(c.lastMessageAt!);
      final duplicate = c.lastMessageAt == m.sentAt && c.lastMessage == m.content;
      if (isNewer && !duplicate) {
        final unread = (!mine && !isActive) ? c.unread + 1 : c.unread;
        if (!mine && !isActive) unreadTotal++;
        final updated = c.copyWith(
          lastMessage: m.content,
          lastSenderId: m.senderId,
          lastMessageAt: m.sentAt,
          unread: unread,
        );
        conversations = [updated, ...conversations.where((x) => x.id != c.id)];
        changed = true;
      }
    } else if (!mine) {
      // Hội thoại mới (vd khách vừa nhắn lần đầu) -> tải lại danh sách cho đủ thông tin.
      if (!isActive) unreadTotal++;
      changed = true;
      fetchConversations();
    }
    if (changed) notifyListeners();
  }

  void _onRead(Map<String, dynamic> json) {
    final id = json['conversation_id'] as String?;
    if (id == null || id != activeId) return;
    messages = [for (final m in messages) m.senderId == _myId && !m.isRead ? m.markRead() : m];
    notifyListeners();
  }

  /// Vừa kết nối lại: có thể đã lỡ tin trong lúc mất mạng -> tải lại.
  void _onReconnected() {
    if (_myId == null) return;
    fetchUnreadCount();
    if (conversations.isNotEmpty) fetchConversations();
    if (activeId != null) _loadPage(1);
  }

  void _markLocalRead(String conversationId) {
    final i = conversations.indexWhere((c) => c.id == conversationId);
    if (i >= 0 && conversations[i].unread > 0) {
      unreadTotal = math.max(0, unreadTotal - conversations[i].unread);
      conversations = [
        for (final c in conversations) c.id == conversationId ? c.copyWith(unread: 0) : c,
      ];
    } else {
      fetchUnreadCount();
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      return msg is List ? msg.join(', ') : msg.toString();
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Không kết nối được máy chủ. Kiểm tra lại mạng.';
    }
    return 'Đã có lỗi xảy ra, vui lòng thử lại.';
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

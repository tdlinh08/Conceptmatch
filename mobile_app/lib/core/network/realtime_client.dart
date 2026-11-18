import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/api_constants.dart';
import 'api_client.dart';

/// Kết nối Socket.IO tới backend (chat + thông báo real-time), dùng chung 1 kết nối
/// cho toàn app.
///
/// - Địa chỉ socket là gốc của baseUrl (vd http://192.168.1.5:3000), KHÔNG có /api/v1.
/// - Gửi access token khi kết nối; server cho vào phòng riêng `user:<id>`.
/// - Access token sống 15 phút: khi server từ chối (sự kiện "auth_error") thì xin
///   token mới qua ApiClient rồi kết nối lại.
/// - Các màn hình / provider nghe sự kiện qua các Stream bên dưới.
class RealtimeClient {
  static final RealtimeClient _instance = RealtimeClient._internal();
  factory RealtimeClient() => _instance;
  RealtimeClient._internal();

  io.Socket? _socket;
  DateTime? _lastAuthRetry;

  /// true khi đang kết nối được (màn chat hiện dòng "Đang kết nối lại…" khi false).
  final ValueNotifier<bool> connected = ValueNotifier(false);

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _messagesRead = StreamController<Map<String, dynamic>>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _bookingChanged = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  /// Tin nhắn mới (cả tin mình gửi từ thiết bị khác).
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  /// Phía bên kia đã đọc tin trong một hội thoại: {conversation_id, reader_id}.
  Stream<Map<String, dynamic>> get messagesRead => _messagesRead.stream;

  /// Thông báo mới (cùng dạng với 1 phần tử của GET /notifications).
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  /// Trạng thái đơn đặt thay đổi: {booking_id, status, studio_name}.
  Stream<Map<String, dynamic>> get bookingChanged => _bookingChanged.stream;

  /// Phát ra mỗi lần kết nối (lại) thành công -> tải lại dữ liệu có thể đã lỡ.
  Stream<void> get reconnected => _reconnected.stream;

  /// Kết nối (hoặc kết nối lại) bằng access token hiện có. Gọi sau khi đăng nhập.
  Future<void> connect() async {
    final token = await ApiClient().getAccessToken();
    if (token == null) return;
    disconnect();

    final socket = io.io(
      Uri.parse(ApiConstants.baseUrl).origin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'token': token})
          .enableForceNew() // không dùng lại kết nối cũ mang token cũ
          .enableReconnection()
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      connected.value = true;
      _reconnected.add(null);
    });
    socket.onDisconnect((_) => connected.value = false);
    socket.on('auth_error', (_) => _onAuthError());
    socket.on('message_received', (data) => _forward(_messages, data));
    socket.on('messages_read', (data) => _forward(_messagesRead, data));
    socket.on('notification_created', (data) => _forward(_notifications, data));
    socket.on('booking_status_changed', (data) => _forward(_bookingChanged, data));

    _socket = socket;
    socket.connect();
  }

  /// Ngắt kết nối (đăng xuất).
  void disconnect() {
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }

  void _forward(StreamController<Map<String, dynamic>> target, dynamic data) {
    if (data is Map) target.add(Map<String, dynamic>.from(data));
  }

  /// Token hết hạn -> xin token mới rồi kết nối lại (tối đa 1 lần mỗi 30 giây để không lặp vô hạn).
  Future<void> _onAuthError() async {
    final now = DateTime.now();
    if (_lastAuthRetry != null && now.difference(_lastAuthRetry!) < const Duration(seconds: 30)) {
      return;
    }
    _lastAuthRetry = now;
    if (await ApiClient().refreshSession()) await connect();
  }
}

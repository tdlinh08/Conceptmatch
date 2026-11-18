/// Một dòng trong danh sách "Tin nhắn" (GET /conversations).
class ConversationSummary {
  final String id;
  final String studioId;
  final String studioName;

  /// 'customer' = mình là khách; 'owner' = mình là chủ studio.
  final String myRole;

  /// Phía còn lại: khách thấy studio (ảnh bìa), chủ studio thấy khách (ảnh đại diện).
  final String partnerName;
  final String? partnerAvatar;

  final String? lastMessage;
  final String? lastSenderId;
  final DateTime? lastMessageAt;
  final int unread;

  ConversationSummary({
    required this.id,
    required this.studioId,
    required this.studioName,
    required this.myRole,
    required this.partnerName,
    this.partnerAvatar,
    this.lastMessage,
    this.lastSenderId,
    this.lastMessageAt,
    this.unread = 0,
  });

  bool get isOwnerView => myRole == 'owner';

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final partner = json['partner'] as Map<String, dynamic>;
    final last = json['last_message'] as Map<String, dynamic>?;
    final at = json['last_message_at'] as String?;
    return ConversationSummary(
      id: json['id'] as String,
      studioId: json['studio_id'] as String,
      studioName: json['studio_name'] as String,
      myRole: json['my_role'] as String,
      partnerName: partner['name'] as String,
      partnerAvatar: partner['avatar'] as String?,
      lastMessage: last?['content'] as String?,
      lastSenderId: last?['sender_id'] as String?,
      lastMessageAt: at == null ? null : DateTime.parse(at).toLocal(),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );
  }

  ConversationSummary copyWith({
    String? lastMessage,
    String? lastSenderId,
    DateTime? lastMessageAt,
    int? unread,
  }) {
    return ConversationSummary(
      id: id,
      studioId: studioId,
      studioName: studioName,
      myRole: myRole,
      partnerName: partnerName,
      partnerAvatar: partnerAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unread: unread ?? this.unread,
    );
  }
}

/// Một tin nhắn (GET /conversations/:id/messages, sự kiện socket "message_received").
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      sentAt: DateTime.parse(json['sent_at'] as String).toLocal(),
    );
  }

  ChatMessage markRead() => ChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        isRead: true,
        sentAt: sentAt,
      );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/realtime_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import 'chat_avatar.dart';

/// Màn trò chuyện 1–1 giữa khách và studio.
/// Tin mới nhất ở dưới cùng; kéo lên đầu để tải tin cũ hơn. Tin mới đến qua socket.
class ChatScreen extends StatefulWidget {
  final ConversationSummary conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final ChatProvider _chat;
  bool _sending = false;

  static const _maxLength = 2000;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatProvider>();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chat.openConversation(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    _chat.closeConversation(widget.conversation.id);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Danh sách đảo ngược (tin mới ở dưới) -> cuộn tới "cuối" danh sách là lên tin cũ.
  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _chat.loadMore();
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await _chat.send(widget.conversation.id, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _input.clear();
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final c = widget.conversation;
    final isActive = chat.activeId == c.id;
    final messages = isActive ? chat.messages : const <ChatMessage>[];
    final myId = chat.myId;
    // Tin cuối cùng của mình -> hiện "Đã gửi" / "Đã xem" bên dưới
    final lastMine = messages.lastWhere(
      (m) => m.senderId == myId,
      orElse: () => _none,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ChatAvatar(name: c.partnerName, url: c.partnerAvatar, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.partnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    c.isOwnerView ? 'Khách hỏi ${c.studioName}' : 'Studio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: RealtimeClient().connected,
            builder: (_, connected, _) => connected
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: AppColors.surfaceMuted,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: const Text(
                      'Đang kết nối lại… tin nhắn mới có thể đến chậm',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textBody),
                    ),
                  ),
          ),
          Expanded(child: _buildMessages(chat, messages, myId, lastMine)),
          _buildInput(),
        ],
      ),
    );
  }

  static final _none = ChatMessage(
    id: '',
    conversationId: '',
    senderId: '',
    content: '',
    isRead: false,
    sentAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Widget _buildMessages(
    ChatProvider chat,
    List<ChatMessage> messages,
    String? myId,
    ChatMessage lastMine,
  ) {
    if (messages.isEmpty) {
      if (chat.isLoadingMessages || chat.activeId != widget.conversation.id) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            chat.messagesError ??
                (widget.conversation.isOwnerView
                    ? 'Chưa có tin nhắn.'
                    : 'Hãy gửi lời chào và hỏi studio về lịch trống, giá hoặc trang phục.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
          ),
        ),
      );
    }

    final count = messages.length + (chat.hasMore ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: count,
      itemBuilder: (context, i) {
        if (i == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final index = messages.length - 1 - i; // i = 0 là tin mới nhất
        final m = messages[index];
        final older = index > 0 ? messages[index - 1] : null;
        final showDay = older == null || !DateUtils.isSameDay(older.sentAt, m.sentAt);
        final mine = m.senderId == myId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDay) _DayChip(day: m.sentAt),
            _Bubble(message: m, mine: mine),
            if (mine && m.id == lastMine.id)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: Text(
                  m.isRead ? 'Đã xem' : 'Đã gửi',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                maxLength: _maxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn…',
                  counterText: '',
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Gửi',
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;

  const _DayChip({required this.day});

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final String label;
    if (DateUtils.isSameDay(now, day)) {
      label = 'Hôm nay';
    } else if (DateUtils.isSameDay(now.subtract(const Duration(days: 1)), day)) {
      label = 'Hôm qua';
    } else {
      label = '${two(day.day)}/${two(day.month)}/${day.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textBody)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;

  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final t = message.sentAt;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.surface,
          border: mine ? null : Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(
              message.content,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: mine ? AppColors.onPrimary : AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${two(t.hour)}:${two(t.minute)}',
              style: TextStyle(
                fontSize: 11,
                color: mine ? AppColors.onPrimary.withValues(alpha: 0.75) : AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

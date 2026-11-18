import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import 'chat_avatar.dart';
import 'chat_screen.dart';

/// Màn "Tin nhắn": các cuộc trò chuyện, mới nhất lên đầu; có tin chưa đọc thì chữ đậm + số đếm.
/// Dùng chung cho khách (thấy tên studio) và chủ studio (thấy tên khách + studio được hỏi).
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().fetchConversations();
    });
  }

  void _open(ConversationSummary c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final items = chat.conversations;

    return Scaffold(
      appBar: AppBar(title: const Text('Tin nhắn')),
      body: RefreshIndicator(
        onRefresh: chat.fetchConversations,
        child: Builder(
          builder: (context) {
            if (chat.isLoadingList && items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return _Empty(
                text: chat.listError ??
                    'Chưa có cuộc trò chuyện nào.\nKhách hàng có thể bấm biểu tượng tin nhắn ở trang studio để hỏi lịch trống, giá, trang phục…',
                isError: chat.listError != null,
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _ConversationTile(
                c: items[i],
                myId: chat.myId,
                onTap: () => _open(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationSummary c;
  final String? myId;
  final VoidCallback onTap;

  const _ConversationTile({required this.c, required this.myId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = c.unread > 0;
    final preview = c.lastMessage == null
        ? ''
        : (c.lastSenderId == myId ? 'Bạn: ${c.lastMessage}' : c.lastMessage!);

    return Material(
      color: hasUnread ? AppColors.surfacePink : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: hasUnread ? AppColors.dustyMauve.withValues(alpha: 0.3) : AppColors.outline,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ChatAvatar(name: c.partnerName, url: c.partnerAvatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.partnerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.textTitle,
                            ),
                          ),
                        ),
                        if (c.lastMessageAt != null)
                          Text(
                            chatListTime(c.lastMessageAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread ? AppColors.accentText : AppColors.textFaint,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    if (c.isOwnerView) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Hỏi ${c.studioName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: hasUnread ? AppColors.textTitle : AppColors.textBody,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.statusError,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              c.unread > 99 ? '99+' : '${c.unread}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  final bool isError;

  const _Empty({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(36, 96, 36, 80),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.surfacePink, shape: BoxShape.circle),
            child: Icon(
              isError ? Icons.wifi_off_rounded : Icons.chat_bubble_outline_rounded,
              size: 32,
              color: AppColors.accentText,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../groups/models/group_model.dart';
import '../controllers/chat_controller.dart';
import '../models/message_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final GroupModel group;
  const ChatScreen({super.key, required this.group});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  final _currentUserId =
      SupabaseConfig.client.auth.currentUser?.id ?? '';

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();

    final error = await ref
        .read(messagesProvider(widget.group.id).notifier)
        .sendMessage(text);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (error != null) {
      showErrorSnack(context, error);
    } else {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final messagesAsync =
    ref.watch(messagesProvider(widget.group.id));

    // Auto scroll when new messages arrive
    ref.listen(messagesProvider(widget.group.id), (_, next) {
      if (next.hasValue) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.primaryTint, size: 16),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_rounded,
                  color: AppColors.primaryTint, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.group.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryTint)),
                const Text('Group chat',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryLight)),
              ],
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // ── Messages list ─────────────────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: TextStyle(color: AppColors.danger)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyChat();
                }

                WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == _currentUserId;

                    // Show date separator if needed
                    final showDate = i == 0 ||
                        !_isSameDay(
                            messages[i - 1].createdAt, msg.createdAt);

                    return Column(
                      children: [
                        if (showDate)
                          _DateSeparator(date: msg.createdAt),
                        _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          showName: !isMe &&
                              (i == 0 ||
                                  messages[i - 1].senderId !=
                                      msg.senderId),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Message input ─────────────────────────────────────────
          _MessageInput(
            controller: _msgCtrl,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showName;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showName,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Sender name (for others, first message in sequence)
                if (showName && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary),
                    ),
                  ),

                // Message content
                Container(
                  constraints: BoxConstraints(
                    maxWidth:
                    MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primary
                        : dark
                        ? AppColors.primaryDark
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    border: isMe
                        ? null
                        : Border.all(
                        color: dark
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.primaryTint,
                        width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe
                          ? Colors.white
                          : dark
                          ? AppColors.primaryTint
                          : AppColors.primaryDark,
                      height: 1.4,
                    ),
                  ),
                ),

                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primaryLight.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),

          // Spacer for my messages
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }
}

// ── Date separator ────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      label = '${months[date.month]} ${date.day}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: AppColors.primaryTint, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: Divider(
                  color: AppColors.primaryTint, thickness: 0.5)),
        ],
      ),
    );
  }
}

// ── Message input bar ─────────────────────────────────────────────────────────
class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final bg = dark ? AppColors.primaryDark : Colors.white;
    final borderColor =
    dark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryTint;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
            top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          // Input field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.primaryDark.withOpacity(0.5)
                    : AppColors.primaryTint.withOpacity(0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppColors.primaryLight.withOpacity(0.3),
                    width: 0.5),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                    fontSize: 14,
                    color: dark
                        ? AppColors.primaryTint
                        : AppColors.primaryDark),
                decoration: InputDecoration(
                  hintText: 'Message ${controller.text.isEmpty ? "..." : ""}',
                  hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.primaryLight.withOpacity(0.5)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSending
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty chat state ──────────────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: dark ? AppColors.primaryDark : AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No messages yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color:
                  dark ? AppColors.primaryTint : AppColors.primaryDark)),
          const SizedBox(height: 8),
          Text('Start the conversation!',
              style: TextStyle(
                  fontSize: 13, color: AppColors.primary)),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/controllers/groups_controller.dart';
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

  // ── Voice recording ─────────────────────────────────────────────────────
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  DateTime? _recordStart;

  // ── Reply ────────────────────────────────────────────────────────────────
  MessageModel? _replyingTo;

  // ── Typing indicator ─────────────────────────────────────────────────────
  Timer? _typingTimer;

  // ── @Mentions ────────────────────────────────────────────────────────────
  String? _mentionQuery;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _onMentionCheck(_msgCtrl.text);

    final notifier = ref.read(messagesProvider(widget.group.id).notifier);
    notifier.setTyping(_msgCtrl.text.trim().isNotEmpty);

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      notifier.setTyping(false);
    });
  }

  void _onMentionCheck(String text) {
    final atIndex = text.lastIndexOf('@');
    if (atIndex == -1) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final afterAt = text.substring(atIndex + 1);
    if (afterAt.contains(' ')) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
    } else {
      setState(() => _mentionQuery = afterAt);
    }
  }

  void _insertMention(String name) {
    final text = _msgCtrl.text;
    final atIndex = text.lastIndexOf('@');
    final newText = '${text.substring(0, atIndex)}@$name ';
    _msgCtrl.text = newText;
    _msgCtrl.selection =
        TextSelection.fromPosition(TextPosition(offset: newText.length));
    setState(() => _mentionQuery = null);
  }

  @override
  void dispose() {
    _msgCtrl.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    ref.read(messagesProvider(widget.group.id).notifier).setTyping(false);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _audioRecorder.dispose();
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
    final replyId = _replyingTo?.id;
    setState(() => _replyingTo = null);

    final error = await ref
        .read(messagesProvider(widget.group.id).notifier)
        .sendMessage(text, replyToId: replyId);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (error != null) {
      showErrorSnack(context, error);
    } else {
      _scrollToBottom();
    }
  }

  // ── Photo attachment ─────────────────────────────────────────────────────
  Future<void> _pickAndSendImage(ImageSource source) async {
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (picked == null) return;
    if (!mounted) return;

    // ✅ Show preview with caption option before sending
    final captionCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final dark = isDark(context);
        final l10n = AppLocalizations.of(context)!;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: dark ? AppColors.primaryDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(picked.path),
                      height: 260, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: captionCtrl,
                  style: TextStyle(
                      color: dark ? AppColors.primaryTint : AppColors.primaryDark),
                  decoration: InputDecoration(
                    hintText: l10n.messageHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: dark
                        ? AppColors.primaryDark.withOpacity(0.5)
                        : AppColors.primaryTint.withOpacity(0.4),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(l10n.share),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isSending = true);
    final error = await ref
        .read(messagesProvider(widget.group.id).notifier)
        .sendImage(File(picked.path), caption: captionCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isSending = false);

    if (error != null) {
      showErrorSnack(context, l10n.failedToSendAttachment);
    } else {
      _scrollToBottom();
    }
  }

  void _showAttachmentSheet() {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final sheetBg = dark ? AppColors.primaryDark : Colors.white;
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    final borderColor = dark ? AppColors.primary.withOpacity(0.3) : AppColors.primaryTint;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            _AttachmentTile(
              icon: Icons.camera_alt_outlined,
              label: l10n.camera2,
              textColor: textColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            _AttachmentTile(
              icon: Icons.photo_outlined,
              label: l10n.chooseFromGallery,
              textColor: textColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Voice recording ─────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    final l10n = AppLocalizations.of(context)!;

    if (_isRecording) {
      // Stop recording and send
      final path = await _audioRecorder.stop();
      final duration = _recordStart != null
          ? DateTime.now().difference(_recordStart!).inSeconds
          : 0;
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });

      if (path == null || duration < 1) return;

      setState(() => _isSending = true);
      final error = await ref
          .read(messagesProvider(widget.group.id).notifier)
          .sendAudio(File(path), duration);

      if (!mounted) return;
      setState(() => _isSending = false);

      if (error != null) {
        showErrorSnack(context, l10n.failedToSendAttachment);
      } else {
        _scrollToBottom();
      }
    } else {
      // Start recording
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) showErrorSnack(context, l10n.microphonePermissionNeeded);
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      _recordStart = DateTime.now();
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _tickRecordTimer();
    }
  }

  void _tickRecordTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isRecording || !mounted) return;
      setState(() => _recordSeconds++);
      _tickRecordTimer();
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final messagesAsync = ref.watch(messagesProvider(widget.group.id));

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
                Text(l10n.groupChat,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryLight)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Text('${l10n.somethingWentWrong}: $e',
                    style: TextStyle(color: AppColors.danger)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const _EmptyChat();
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == _currentUserId;

                    final showDate = i == 0 ||
                        !_isSameDay(
                            messages[i - 1].createdAt, msg.createdAt);

                    return Column(
                      children: [
                        if (showDate) _DateSeparator(date: msg.createdAt),
                        _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          showName: !isMe &&
                              (i == 0 ||
                                  messages[i - 1].senderId != msg.senderId),
                          onReply: (m) => setState(() => _replyingTo = m),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Typing indicator ────────────────────────────────────────────
          Consumer(
            builder: (context, ref, _) {
              final typingUsers =
                  ref.watch(typingUsersProvider(widget.group.id)).value ?? [];
              if (typingUsers.isEmpty) return const SizedBox.shrink();

              final text = typingUsers.length == 1
                  ? l10n.isTyping(typingUsers.first)
                  : l10n.severalTyping;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(text,
                      style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.primaryLight)),
                ),
              );
            },
          ),

          // ── @Mention suggestions ─────────────────────────────────────────
          if (_mentionQuery != null)
            Consumer(
              builder: (context, ref, _) {
                final membersAsync =
                ref.watch(groupMembersProvider(widget.group.id));
                return membersAsync.when(
                  data: (members) {
                    final matches = members.where((m) {
                      final name = (m['profiles']?['full_name'] as String? ?? '')
                          .toLowerCase();
                      return name.contains(_mentionQuery!.toLowerCase());
                    }).toList();
                    if (matches.isEmpty) return const SizedBox.shrink();

                    return Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: BoxDecoration(
                        color: isDark(context) ? AppColors.primaryDark : Colors.white,
                        border: Border(top: BorderSide(color: AppColors.primaryTint)),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.groups_rounded, color: AppColors.primary),
                            title: const Text('all'),
                            onTap: () => _insertMention('all'),
                          ),
                          ...matches.map((m) {
                            final name = m['profiles']?['full_name'] as String? ?? 'Unknown';
                            return ListTile(
                              leading: const Icon(Icons.person_rounded, color: AppColors.primary),
                              title: Text(name),
                              onTap: () => _insertMention(name.replaceAll(' ', '')),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),

          _MessageInput(
            controller: _msgCtrl,
            isSending: _isSending,
            isRecording: _isRecording,
            recordSeconds: _recordSeconds,
            onSend: _sendMessage,
            onAttachment: _showAttachmentSheet,
            onMicToggle: _toggleRecording,
            replyingTo: _replyingTo,
            onCancelReply: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.primaryLight, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends ConsumerWidget {
  final MessageModel message;
  final bool isMe;
  final bool showName;
  final void Function(MessageModel) onReply;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showName,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = isDark(context);
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onLongPress: () => _showMessageActions(context, ref, l10n),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment:
          isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
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
            Flexible(
              child: Column(
                crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showName && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary),
                      ),
                    ),

                  // ── Reply preview strip (if this message is a reply) ─────
                  if (message.isReply)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: (isMe ? Colors.white : AppColors.primary).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                              color: isMe ? Colors.white : AppColors.primary, width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToSender ?? '',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isMe ? Colors.white : AppColors.primary),
                          ),
                          Text(
                            message.replyToContent ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: (isMe
                                    ? Colors.white
                                    : (dark ? AppColors.primaryTint : AppColors.primaryDark))
                                    .withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),

                  // ── Content — text, image, or audio ────────────────────
                  if (message.isImage) ...[
                    _ImageBubble(message: message, isMe: isMe, dark: dark),
                    if (message.content.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          message.content,
                          style: TextStyle(
                            fontSize: 13,
                            color: dark ? AppColors.primaryTint : AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ]
                  else if (message.isAudio)
                    _AudioBubble(message: message, isMe: isMe, dark: dark)
                  else
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
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
                      ),
                      child: _buildMessageText(message.content, isMe, dark),
                    ),

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
            if (isMe) const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  void _showMessageActions(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final dark = isDark(context);
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    final isOwn = message.senderId == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: dark ? AppColors.primaryDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
              title: Text(l10n.reply),
              onTap: () {
                Navigator.pop(sheetContext);
                onReply(message);
              },
            ),
            if (!message.hasAttachment)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.primary),
                title: Text(l10n.copyMessage),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: message.content));
                  showSuccessSnack(context, l10n.messageCopied);
                },
              ),
            if (isOwn)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: Text(l10n.deleteMessage, style: const TextStyle(color: AppColors.danger)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(l10n.deleteMessage),
                      content: Text(l10n.deleteMessageConfirm),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    final error = await ref
                        .read(messagesProvider(message.groupId).notifier)
                        .deleteMessage(message.id);
                    if (context.mounted) {
                      if (error == null) {
                        showSuccessSnack(context, l10n.messageDeleted);
                      } else {
                        showErrorSnack(context, error);
                      }
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Highlights @mentions (e.g. @Fahad, @all) in bold accent color ─────────
  Widget _buildMessageText(String text, bool isMe, bool dark) {
    final baseColor = isMe
        ? Colors.white
        : dark
        ? AppColors.primaryTint
        : AppColors.primaryDark;
    final mentionColor = isMe ? AppColors.accent : AppColors.primary;

    final mentionRegex = RegExp(r'@\w+');
    final matches = mentionRegex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(fontSize: 14, color: baseColor, height: 1.4),
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(fontWeight: FontWeight.w700, color: mentionColor),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: baseColor, height: 1.4),
        children: spans,
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

// ── Image bubble (tap to view full screen) ────────────────────────────────────
class _ImageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool dark;
  const _ImageBubble(
      {required this.message, required this.isMe, required this.dark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FullScreenImage(url: message.attachmentUrl!),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: 220,
          ),
          child: Image.network(
            message.attachmentUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
              width: 160,
              height: 160,
              color: AppColors.primaryTint,
              child: const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            ),
            errorBuilder: (_, __, ___) => Container(
              width: 160,
              height: 160,
              color: AppColors.primaryTint,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }
}

// ── Audio bubble (play/pause voice message) ───────────────────────────────────
class _AudioBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final bool dark;
  const _AudioBubble(
      {required this.message, required this.isMe, required this.dark});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.message.audioDuration ?? 0);
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(UrlSource(widget.message.attachmentUrl!));
      setState(() => _isPlaying = true);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bg = widget.isMe
        ? AppColors.primary
        : widget.dark
        ? AppColors.primaryDark
        : Colors.white;
    final iconColor = widget.isMe ? Colors.white : AppColors.primary;
    final textColor = widget.isMe
        ? Colors.white
        : widget.dark
        ? AppColors.primaryTint
        : AppColors.primaryDark;

    final progress = _total.inSeconds > 0
        ? _position.inSeconds / _total.inSeconds
        : 0.0;

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: widget.isMe
            ? null
            : Border.all(
            color: widget.dark
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.primaryTint,
            width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: iconColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: iconColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(iconColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying ? _fmt(_position) : _fmt(_total),
                  style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          Icon(Icons.mic_rounded, size: 14, color: iconColor.withOpacity(0.6)),
        ],
      ),
    );
  }
}

// ── Date separator ────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = l10n.todayLabel;
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = l10n.yesterdayLabel;
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
              child: Divider(color: AppColors.primaryTint, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: Divider(color: AppColors.primaryTint, thickness: 0.5)),
        ],
      ),
    );
  }
}

// ── Message input bar ─────────────────────────────────────────────────────────
class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool isRecording;
  final int recordSeconds;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final VoidCallback onMicToggle;
  final MessageModel? replyingTo;
  final VoidCallback? onCancelReply;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.isRecording,
    required this.recordSeconds,
    required this.onSend,
    required this.onAttachment,
    required this.onMicToggle,
    this.replyingTo,
    this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final bg = dark ? AppColors.primaryDark : Colors.white;
    final borderColor =
    dark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryTint;
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Reply preview bar ────────────────────────────────────────
          if (replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(replyingTo!.senderName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                        Text(
                          replyingTo!.content.isNotEmpty ? replyingTo!.content : '📎',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: Icon(Icons.close_rounded, size: 18, color: AppColors.primaryLight),
                  ),
                ],
              ),
            ),

          isRecording
              ? Row(
            children: [
              Icon(Icons.fiber_manual_record_rounded,
                  color: AppColors.danger, size: 16),
              const SizedBox(width: 8),
              Text(l10n.recording,
                  style: TextStyle(
                      color: dark ? AppColors.primaryTint : AppColors.primaryDark)),
              const SizedBox(width: 8),
              Text('0:${recordSeconds.toString().padLeft(2, '0')}',
                  style: TextStyle(color: AppColors.primaryLight)),
              const Spacer(),
              GestureDetector(
                onTap: onMicToggle,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppColors.danger, shape: BoxShape.circle),
                  child: const Icon(Icons.stop_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          )
              : Row(
            children: [
              // Attachment button
              GestureDetector(
                onTap: isSending ? null : onAttachment,
                child: Icon(Icons.attach_file_rounded,
                    color: AppColors.primary.withOpacity(isSending ? 0.4 : 1)),
              ),
              const SizedBox(width: 8),

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
                    enabled: !isSending,
                    style: TextStyle(
                        fontSize: 14,
                        color: dark ? AppColors.primaryTint : AppColors.primaryDark),
                    decoration: InputDecoration(
                      hintText: l10n.messageHint,
                      hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.primaryLight.withOpacity(0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Mic or send button
              GestureDetector(
                onTap: isSending
                    ? null
                    : (hasText ? onSend : onMicToggle),
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
                      : Icon(
                    hasText ? Icons.send_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty chat state ──────────────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          Text(l10n.noMessagesYet,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: dark ? AppColors.primaryTint : AppColors.primaryDark)),
          const SizedBox(height: 8),
          Text(l10n.startTheConversation,
              style: TextStyle(fontSize: 13, color: AppColors.primary)),
        ],
      ),
    );
  }
}
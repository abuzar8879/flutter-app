import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/media_download_service.dart';
import '../../domain/group_member.dart';
import '../../domain/group_message.dart';
import '../../domain/group_summary.dart';
import '../providers/group_chat_controller.dart';
import '../providers/groups_providers.dart';
import 'group_info_screen.dart';

final _groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((
  ref,
  groupId,
) async {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) return const [];
  return ref
      .read(groupsRepositoryProvider)
      .listMembers(token: session.token, groupId: groupId);
});

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({required this.group, super.key});

  final GroupSummary group;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  static const double _autoScrollThresholdPx = 140;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  void _onMessageChanged() {
    ref
        .read(groupChatControllerProvider(widget.group.id).notifier)
        .onMessageChanged();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    final distanceToBottom = position.maxScrollExtent - position.pixels;
    return distanceToBottom <= _autoScrollThresholdPx;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    final state = ref.read(groupChatControllerProvider(widget.group.id));
    final notifier = ref.read(
      groupChatControllerProvider(widget.group.id).notifier,
    );
    if (text.isEmpty || state.isSending) return;

    notifier.setSending(true);
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      final socket = ref.read(chatSocketServiceProvider);
      var message = await socket?.sendGroupMessage(
        groupId: widget.group.id,
        type: 'text',
        content: text,
      );
      message ??= await ref
          .read(groupsRepositoryProvider)
          .sendMessage(
            token: session.token,
            groupId: widget.group.id,
            type: 'text',
            content: text,
          );
      notifier.addLocalMessage(message);
      _messageController.clear();
      _scrollToBottom();
    } finally {
      notifier.setSending(false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final state = ref.read(groupChatControllerProvider(widget.group.id));
    final notifier = ref.read(
      groupChatControllerProvider(widget.group.id).notifier,
    );
    if (state.isSending) return;

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    notifier.setSending(true);
    try {
      final bytes = await file.readAsBytes();
      final imagePath = await ref
          .read(groupsRepositoryProvider)
          .uploadImage(token: session.token, fileName: file.name, bytes: bytes);
      final socket = ref.read(chatSocketServiceProvider);
      var message = await socket?.sendGroupMessage(
        groupId: widget.group.id,
        type: 'image',
        imagePath: imagePath,
      );
      message ??= await ref
          .read(groupsRepositoryProvider)
          .sendMessage(
            token: session.token,
            groupId: widget.group.id,
            type: 'image',
            imagePath: imagePath,
          );
      notifier.addLocalMessage(message);
      _scrollToBottom();
    } finally {
      notifier.setSending(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authControllerProvider).session?.user.id ?? '';
    final chatState = ref.watch(groupChatControllerProvider(widget.group.id));
    final members = ref.watch(_groupMembersProvider(widget.group.id));
    final theme = Theme.of(context);

    ref.listen<GroupChatState>(groupChatControllerProvider(widget.group.id), (
      prev,
      next,
    ) {
      final prevLen = prev?.messages.length ?? 0;
      if (next.messages.length > prevLen && _isNearBottom()) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GroupInfoScreen(group: widget.group),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (chatState.typingUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Someone is typing...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      final isMine = message.senderId == currentUserId;
                      final isImageBubble =
                          message.type == GroupMessageType.image &&
                          !message.isDeleted;
                      final senderName = members.maybeWhen(
                        data: (items) {
                          for (final m in items) {
                            if (m.userId == message.senderId) {
                              return m.user?.name ?? 'User ${m.userId}';
                            }
                          }
                          return 'User ${message.senderId}';
                        },
                        orElse: () => 'User ${message.senderId}',
                      );
                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: isImageBubble
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                          decoration: BoxDecoration(
                            color: isImageBubble
                                ? Colors.transparent
                                : (isMine
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surface),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _GroupMessageContent(
                            message: message,
                            isMine: isMine,
                            senderName: senderName,
                            onDelete: () => ref
                                .read(
                                  groupChatControllerProvider(widget.group.id)
                                      .notifier,
                                )
                                .deleteMessage(message.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: chatState.isSending ? null : _pickAndSendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: chatState.isSending ? null : _sendText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMessageContent extends StatelessWidget {
  const _GroupMessageContent({
    required this.message,
    required this.isMine,
    required this.senderName,
    required this.onDelete,
  });

  final GroupMessage message;
  final bool isMine;
  final String senderName;
  final Future<void> Function() onDelete;

  TextStyle _senderStyle(ThemeData theme, Color textColor) {
    return theme.textTheme.labelSmall?.copyWith(
          color: textColor.withOpacity(0.62),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        ) ??
        TextStyle(
          color: textColor.withOpacity(0.62),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isMine ? Colors.white : theme.colorScheme.onSurface;
    final messenger = ScaffoldMessenger.of(context);

    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: TextStyle(
          color: textColor.withOpacity(0.65),
          fontSize: 15,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (message.type == GroupMessageType.image) {
      final url =
          message.imageUrl ??
          (message.imagePath != null
              ? '${AppConfig.apiBaseUrl}${message.imagePath}'
              : '');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                '@$senderName',
                style: _senderStyle(theme, textColor),
              ),
            ),
          _GroupDownloadableImage(
            imageUrl: url,
            textColor: textColor,
            isMine: isMine,
            onDownload: () async {
              try {
                await const MediaDownloadService().downloadImage(url: url);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Image downloaded.')),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Failed to download image.')),
                );
              }
            },
            onDelete: isMine ? onDelete : null,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMine)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text('@$senderName', style: _senderStyle(theme, textColor)),
          ),
        Text(message.content ?? '', style: TextStyle(color: textColor)),
      ],
    );
  }
}

class _GroupDownloadableImage extends StatelessWidget {
  const _GroupDownloadableImage({
    required this.imageUrl,
    required this.textColor,
    required this.isMine,
    required this.onDownload,
    this.onDelete,
  });

  final String imageUrl;
  final Color textColor;
  final bool isMine;
  final Future<void> Function() onDownload;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMine
        ? theme.colorScheme.primary.withOpacity(0.16)
        : theme.colorScheme.surface;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bubbleColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.broken_image, color: textColor),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(999),
            ),
            child: PopupMenuButton<String>(
              tooltip: 'Image actions',
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (value) async {
                if (value == 'download') {
                  await onDownload();
                }
                if (value == 'delete' && onDelete != null) {
                  await onDelete!();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Download'),
                    ],
                  ),
                ),
                if (onDelete != null)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Delete'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

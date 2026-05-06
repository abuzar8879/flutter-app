import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/media_download_service.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../users/domain/app_user.dart';
import '../../domain/chat_message.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.friend, super.key});

  final AppUser friend;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _audioRecorder = AudioRecorder();
  static const double _autoScrollThresholdPx = 140;
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  void _onMessageChanged() {
    ref
        .read(chatControllerProvider(widget.friend.id).notifier)
        .onMessageChanged();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
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

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    final distanceToBottom = position.maxScrollExtent - position.pixels;
    return distanceToBottom <= _autoScrollThresholdPx;
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    final chatState = ref.read(chatControllerProvider(widget.friend.id));
    final chatNotifier = ref.read(
      chatControllerProvider(widget.friend.id).notifier,
    );

    if (text.isEmpty || chatState.isSending) return;

    chatNotifier.setSending(true);

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      ChatMessage? message;
      if (_editingMessage != null) {
        message = await chatNotifier.editMessage(
          messageId: _editingMessage!.id,
          content: text,
        );
      } else {
        final socket = ref.read(chatSocketServiceProvider);
        message = await socket?.sendMessage(
          receiverId: widget.friend.id,
          type: 'text',
          content: text,
          replyToMessageId: _replyingTo?.id,
        );
        message ??= await ref
            .read(chatRepositoryProvider)
            .sendTextMessage(
              token: session.token,
              receiverId: widget.friend.id,
              content: text,
              replyToMessageId: _replyingTo?.id,
            );
      }
      final socketSvc = ref.read(chatSocketServiceProvider);
      if (chatState.conversationId != null) {
        socketSvc?.sendStopTyping(widget.friend.id, chatState.conversationId!);
      }
      if (_editingMessage == null && message != null) {
        chatNotifier.addLocalMessage(message);
      }
      _messageController.clear();
      _replyingTo = null;
      _editingMessage = null;
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : 'Failed to send message.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        chatNotifier.setSending(false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final chatState = ref.read(chatControllerProvider(widget.friend.id));
    final chatNotifier = ref.read(
      chatControllerProvider(widget.friend.id).notifier,
    );

    if (chatState.isSending) return;

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    chatNotifier.setSending(true);

    try {
      final bytes = await file.readAsBytes();
      final repository = ref.read(chatRepositoryProvider);
      final imagePath = await repository.uploadImage(
        token: session.token,
        fileName: file.name,
        bytes: bytes,
      );
      final socket = ref.read(chatSocketServiceProvider);
      var message = await socket?.sendMessage(
        receiverId: widget.friend.id,
        type: 'image',
        imagePath: imagePath,
        replyToMessageId: _replyingTo?.id,
      );
      message ??= await repository.sendImageMessage(
        token: session.token,
        receiverId: widget.friend.id,
        imagePath: imagePath,
        replyToMessageId: _replyingTo?.id,
      );
      chatNotifier.addLocalMessage(message);
      setState(() => _replyingTo = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : 'Failed to send image.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        chatNotifier.setSending(false);
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await _sendVoice(path);
      }
      return;
    }

    if (!await _audioRecorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() => _isRecording = true);
  }

  Future<void> _sendVoice(String path) async {
    final session = ref.read(authControllerProvider).session;
    final chatNotifier = ref.read(
      chatControllerProvider(widget.friend.id).notifier,
    );
    if (session == null) return;

    chatNotifier.setSending(true);
    try {
      final file = File(path);
      final repository = ref.read(chatRepositoryProvider);
      final audioPath = await repository.uploadAudio(
        token: session.token,
        fileName: path.split(Platform.pathSeparator).last,
        bytes: await file.readAsBytes(),
      );
      final socket = ref.read(chatSocketServiceProvider);
      var message = await socket?.sendMessage(
        receiverId: widget.friend.id,
        type: 'voice',
        audioPath: audioPath,
        replyToMessageId: _replyingTo?.id,
      );
      message ??= await repository.sendVoiceMessage(
        token: session.token,
        receiverId: widget.friend.id,
        audioPath: audioPath,
        replyToMessageId: _replyingTo?.id,
      );
      chatNotifier.addLocalMessage(message);
      setState(() => _replyingTo = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send voice message.')),
        );
      }
    } finally {
      chatNotifier.setSending(false);
    }
  }

  void _openMessageActions(ChatMessage message, bool isMine) {
    if (message.isDeleted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        const reactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  spacing: 10,
                  children: reactions
                      .map(
                        (reaction) => ActionChip(
                          label: Text(reaction),
                          onPressed: () {
                            Navigator.pop(context);
                            _reactToMessage(message, reaction);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyingTo = message);
                },
              ),
              if (isMine &&
                  (message.type == ChatMessageType.text ||
                      message.type == ChatMessageType.encrypted))
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessage = message;
                      _messageController.clear();
                    });
                  },
                ),
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(chatControllerProvider(widget.friend.id).notifier)
                        .deleteMessage(message.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _reactToMessage(ChatMessage message, String reaction) {
    final currentUserId =
        ref.read(authControllerProvider).session?.user.id ?? '';
    final nextReaction = message.reactions[currentUserId] == reaction
        ? ''
        : reaction;
    ref
        .read(chatControllerProvider(widget.friend.id).notifier)
        .reactToMessage(messageId: message.id, reaction: nextReaction);
  }

  @override
  Widget build(BuildContext context) {
    // Auto-scroll when a new message arrives, but only if the user is already
    // near the bottom (prevents jumping while reading older messages).
    ref.listen<ChatState>(chatControllerProvider(widget.friend.id), (
      prev,
      next,
    ) {
      final prevLen = prev?.messages.length ?? 0;
      final nextLen = next.messages.length;
      if (nextLen <= prevLen) return;
      if (_isNearBottom()) _scrollToBottom();
    });

    final currentUserId =
        ref.watch(authControllerProvider).session?.user.id ?? '';
    final chatState = ref.watch(chatControllerProvider(widget.friend.id));
    final theme = Theme.of(context);

    // If chatState recently loaded messages and we haven't scrolled yet, scroll to bottom
    if (!chatState.isLoading &&
        chatState.messages.isNotEmpty &&
        _scrollController.hasClients == false) {
      _scrollToBottom();
    }

    final isSelf = widget.friend.id == currentUserId;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    _initial(widget.friend.name),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (chatState.isFriendOnline && !isSelf)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friend.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isSelf
                      ? 'You'
                      : (chatState.isFriendOnline ? 'Online' : 'Offline'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: (chatState.isFriendOnline && !isSelf)
                        ? Colors.green
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            onPressed: isSelf ? null : () {},
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: isSelf ? null : () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.5),
        ),
        child: isSelf
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off_rounded,
                        size: 64,
                        color: theme.colorScheme.error.withOpacity(0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You cannot chat with yourself.',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please select a friend to start a conversation.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(child: _buildMessages(currentUserId, chatState)),
                  if (chatState.isFriendTyping)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${widget.friend.name} is typing...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildInputArea(theme, chatState),
                ],
              ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, ChatState chatState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null || _editingMessage != null)
              _ComposerContextBar(
                icon: _editingMessage != null
                    ? Icons.edit_rounded
                    : Icons.reply_rounded,
                title: _editingMessage != null ? 'Editing message' : 'Replying',
                subtitle: _messagePreview(_editingMessage ?? _replyingTo!),
                onCancel: () => setState(() {
                  _replyingTo = null;
                  _editingMessage = null;
                  _messageController.clear();
                }),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: chatState.isSending ? null : _pickAndSendImage,
                  icon: Icon(
                    Icons.add_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: chatState.isSending ? null : _toggleRecording,
                  icon: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  ),
                  color: _isRecording
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: chatState.isSending ? null : _sendText,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: chatState.isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(String currentUserId, ChatState chatState) {
    if (chatState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatState.error != null) {
      return Center(child: Text(chatState.error!));
    }

    if (chatState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            const Text('No messages yet. Start chatting!'),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: chatState.messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: TextButton(
                onPressed: chatState.isLoadingOlder
                    ? null
                    : () => ref
                          .read(
                            chatControllerProvider(widget.friend.id).notifier,
                          )
                          .loadOlderMessages(),
                child: chatState.isLoadingOlder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Load older messages',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          );
        }

        final message = chatState.messages[index - 1];
        final isMine = message.senderId == currentUserId;
        ChatMessage? replyTo;
        if (message.replyToMessageId != null) {
          for (final item in chatState.messages) {
            if (item.id == message.replyToMessageId) {
              replyTo = item;
              break;
            }
          }
        }

        // Show date header if it's a new day
        bool showDateHeader = false;
        if (index == 1) {
          showDateHeader = true;
        } else {
          final prevMessage = chatState.messages[index - 2];
          if (!_isSameDay(message.createdAtDate, prevMessage.createdAtDate)) {
            showDateHeader = true;
          }
        }

        return Column(
          children: [
            if (showDateHeader)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDate(message.createdAtDate),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onLongPress: () => _openMessageActions(message, isMine),
                child: _MessageBubble(
                  message: message,
                  isMine: isMine,
                  remotePublicKey: widget.friend.publicKey ?? '',
                  replyPreview: replyTo == null
                      ? null
                      : _messagePreview(replyTo),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ComposerContextBar extends StatelessWidget {
  const _ComposerContextBar({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onCancel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelMedium),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.remotePublicKey,
    this.replyPreview,
  });

  final ChatMessage message;
  final bool isMine;
  final String remotePublicKey;
  final String? replyPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = message.createdAtDate;

    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMine
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _MessageContent(
              message: message,
              remotePublicKey: remotePublicKey,
              isMine: isMine,
              replyPreview: replyPreview,
            ),
          ),
        ),
        if (message.reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 4,
              children: message.reactions.values
                  .map(
                    (reaction) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          reaction,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                Icon(
                  message.readAt != null
                      ? Icons.done_all_rounded
                      : Icons.done_rounded,
                  size: 14,
                  color: message.readAt != null
                      ? Colors.blue
                      : theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
              if (message.editedAt != null && !message.isDeleted) ...[
                const SizedBox(width: 4),
                Text(
                  'edited',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _MessageContent extends ConsumerWidget {
  const _MessageContent({
    required this.message,
    required this.remotePublicKey,
    required this.isMine,
    this.replyPreview,
  });

  final ChatMessage message;
  final String remotePublicKey;
  final bool isMine;
  final String? replyPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = isMine
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final messenger = ScaffoldMessenger.of(context);
    final friend = AppUser(
      id: message.senderId,
      name: '',
      email: '',
      publicKey: remotePublicKey,
    );

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

    Widget withReply(Widget child) {
      if (replyPreview == null || replyPreview!.isEmpty) return child;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isMine ? Colors.white : Colors.black).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              replyPreview!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12),
            ),
          ),
          child,
        ],
      );
    }

    if (message.type == ChatMessageType.encrypted && message.content != null) {
      final payload = ref.watch(
        messagePayloadProvider(
          MessageDecryptionRequest(message: message, friend: friend),
        ),
      );

      return payload.when(
        data: (data) {
          final type = data['type'] as String? ?? 'text';
          if (type == 'image') {
            final imagePath = data['imagePath'] as String? ?? '';
            if (imagePath.isEmpty) {
              return Text(
                'Photo',
                style: TextStyle(color: textColor, fontSize: 15),
              );
            }

            return withReply(
              _DownloadableImage(
                imageUrl: '${AppConfig.apiBaseUrl}$imagePath',
                textColor: textColor,
                onDownload: () async {
                  try {
                    await const MediaDownloadService().downloadImage(
                      url: '${AppConfig.apiBaseUrl}$imagePath',
                    );
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Image downloaded.')),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Failed to download image.'),
                      ),
                    );
                  }
                },
              ),
            );
          }

          return withReply(
            Text(
              data['content'] as String? ?? '',
              style: TextStyle(color: textColor, fontSize: 15),
            ),
          );
        },
        loading: () => Text(
          'Decrypting...',
          style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 15),
        ),
        error: (_, __) => Text(
          'Failed to decrypt',
          style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 15),
        ),
      );
    }

    if (message.type == ChatMessageType.image && message.imagePath != null) {
      final imageUrl =
          message.imageUrl ?? '${AppConfig.apiBaseUrl}${message.content}';
      return withReply(
        _DownloadableImage(
          imageUrl: imageUrl,
          textColor: textColor,
          onDownload: () async {
            try {
              await const MediaDownloadService().downloadImage(url: imageUrl);
              messenger.showSnackBar(
                const SnackBar(content: Text('Image downloaded.')),
              );
            } catch (_) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Failed to download image.')),
              );
            }
          },
        ),
      );
    }

    if (message.type == ChatMessageType.voice) {
      return withReply(
        _VoiceMessagePlayer(url: message.audioUrl ?? '', color: textColor),
      );
    }

    return withReply(
      Text(
        message.content ?? '',
        style: TextStyle(color: textColor, fontSize: 15),
      ),
    );
  }
}

class _DownloadableImage extends StatelessWidget {
  const _DownloadableImage({
    required this.imageUrl,
    required this.textColor,
    required this.onDownload,
  });

  final String imageUrl;
  final Color textColor;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.broken_image, color: textColor),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 18),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ),
      ],
    );
  }
}

class _VoiceMessagePlayer extends StatefulWidget {
  const _VoiceMessagePlayer({required this.url, required this.color});

  final String url;
  final Color color;

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.url.isEmpty) return;
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    await _player.setUrl(widget.url);
    setState(() => _playing = true);
    await _player.play();
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
            color: widget.color,
          ),
          const SizedBox(width: 8),
          Text('Voice message', style: TextStyle(color: widget.color)),
        ],
      ),
    );
  }
}

String _messagePreview(ChatMessage message) {
  if (message.isDeleted) return 'Deleted message';
  if (message.type == ChatMessageType.voice) return 'Voice message';
  if (message.type == ChatMessageType.image) return 'Photo';
  if (message.type == ChatMessageType.encrypted) return 'Encrypted message';
  return message.content ?? 'Message';
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  if (date.day == now.day && date.month == now.month && date.year == now.year) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (date.day == yesterday.day &&
      date.month == yesterday.month &&
      date.year == yesterday.year) {
    return 'Yesterday';
  }
  return '${date.day}/${date.month}/${date.year}';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

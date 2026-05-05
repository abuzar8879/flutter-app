import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
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
  static const double _autoScrollThresholdPx = 140;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  void _onMessageChanged() {
    ref.read(chatControllerProvider(widget.friend.id).notifier).onMessageChanged();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
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
    final chatNotifier = ref.read(chatControllerProvider(widget.friend.id).notifier);
    
    if (text.isEmpty || chatState.isSending) return;

    chatNotifier.setSending(true);

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      final encryptedPayload = await _encryptOutgoing({
        'type': 'text',
        'content': text,
      });
      if (encryptedPayload == null) return;

      final socket = ref.read(chatSocketServiceProvider);
      var message = await socket?.sendMessage(
        receiverId: widget.friend.id,
        type: 'encrypted',
        content: encryptedPayload,
      );
      message ??= await ref
          .read(chatRepositoryProvider)
          .sendEncryptedMessage(
            token: session.token,
            receiverId: widget.friend.id,
            content: encryptedPayload,
          );
      final socketSvc = ref.read(chatSocketServiceProvider);
      if (chatState.conversationId != null) {
        socketSvc?.sendStopTyping(widget.friend.id, chatState.conversationId!);
      }
      chatNotifier.addLocalMessage(message);
      _messageController.clear();
      _scrollToBottom();
    } finally {
      if (mounted) {
        chatNotifier.setSending(false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final chatState = ref.read(chatControllerProvider(widget.friend.id));
    final chatNotifier = ref.read(chatControllerProvider(widget.friend.id).notifier);

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
      final encryptedPayload = await _encryptOutgoing({
        'type': 'image',
        'imagePath': imagePath,
      });
      if (encryptedPayload == null) return;

      final socket = ref.read(chatSocketServiceProvider);
      var message = await socket?.sendMessage(
        receiverId: widget.friend.id,
        type: 'encrypted',
        content: encryptedPayload,
      );
      message ??= await repository.sendEncryptedMessage(
        token: session.token,
        receiverId: widget.friend.id,
        content: encryptedPayload,
      );
      chatNotifier.addLocalMessage(message);
      _scrollToBottom();
    } finally {
      if (mounted) {
        chatNotifier.setSending(false);
      }
    }
  }

  Future<String?> _encryptOutgoing(Map<String, dynamic> payload) async {
    final publicKey = widget.friend.publicKey;
    if (publicKey == null || publicKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This friend needs to open the app once before encrypted chat works.',
            ),
          ),
        );
      }
      return null;
    }

    await ref.read(encryptionBootstrapProvider.future);
    final session = ref.read(authControllerProvider).session;
    if (session == null) return null;
    return ref
        .read(messageCryptoServiceProvider)
        .encryptPayload(
          remotePublicKey: publicKey,
          payload: payload,
          scopeKey: session.user.id,
        );
  }



  @override
  Widget build(BuildContext context) {
    // Auto-scroll when a new message arrives, but only if the user is already
    // near the bottom (prevents jumping while reading older messages).
    ref.listen<ChatState>(chatControllerProvider(widget.friend.id), (prev, next) {
      final prevLen = prev?.messages.length ?? 0;
      final nextLen = next.messages.length;
      if (nextLen <= prevLen) return;
      if (_isNearBottom()) _scrollToBottom();
    });

    final currentUserId = ref.watch(authControllerProvider).session?.user.id ?? '';
    final chatState = ref.watch(chatControllerProvider(widget.friend.id));
    final theme = Theme.of(context);

    // If chatState recently loaded messages and we haven't scrolled yet, scroll to bottom
    if (!chatState.isLoading && chatState.messages.isNotEmpty && _scrollController.hasClients == false) {
      _scrollToBottom();
    }

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
                if (chatState.isFriendOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.surface, width: 2),
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
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  chatState.isFriendOnline ? 'Online' : 'Offline',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: chatState.isFriendOnline ? Colors.green : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_rounded), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.5),
        ),
        child: Column(
          children: [
            Expanded(child: _buildMessages(currentUserId, chatState)),
            if (chatState.isFriendTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${widget.friend.name} is typing...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
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
        child: Row(
          children: [
            IconButton(
              onPressed: chatState.isSending ? null : _pickAndSendImage,
              icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                  ),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 12),
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
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
              ),
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
            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Theme.of(context).dividerColor.withOpacity(0.1)),
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
                    : () => ref.read(chatControllerProvider(widget.friend.id).notifier).loadOlderMessages(),
                child: chatState.isLoadingOlder
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        'Load older messages',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
                      ),
              ),
            ),
          );
        }

        final message = chatState.messages[index - 1];
        final isMine = message.senderId == currentUserId;
        
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDate(message.createdAtDate),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: _MessageBubble(
                message: message,
                isMine: isMine,
                remotePublicKey: widget.friend.publicKey ?? '',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.remotePublicKey,
  });

  final ChatMessage message;
  final bool isMine;
  final String remotePublicKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = message.createdAtDate;

    return Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? theme.colorScheme.primary : theme.colorScheme.surface,
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
            ),
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
                  message.readAt != null ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 14,
                  color: message.readAt != null ? Colors.blue : theme.colorScheme.onSurface.withOpacity(0.4),
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
  });

  final ChatMessage message;
  final String remotePublicKey;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = isMine ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final friend = AppUser(
      id: message.senderId,
      name: '',
      email: '',
      publicKey: remotePublicKey,
    );

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

            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                '${AppConfig.apiBaseUrl}$imagePath',
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.broken_image, color: textColor),
              ),
            );
          }

          return Text(
            data['content'] as String? ?? '',
            style: TextStyle(color: textColor, fontSize: 15),
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

    if (message.type == ChatMessageType.image && message.content != null) {
      final imageUrl = message.imageUrl ?? '${AppConfig.apiBaseUrl}${message.content}';
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
              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: textColor),
            ),
          ),
        ],
      );
    }

    return Text(
      message.content ?? '',
      style: TextStyle(color: textColor, fontSize: 15),
    );
  }
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
  if (date.day == yesterday.day && date.month == yesterday.month && date.year == yesterday.year) {
    return 'Yesterday';
  }
  return '${date.day}/${date.month}/${date.year}';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

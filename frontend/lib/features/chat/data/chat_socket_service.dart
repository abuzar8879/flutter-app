import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_config.dart';
import '../domain/chat_message.dart';
import '../../groups/domain/group_message.dart';

class ChatSocketService {
  ChatSocketService({required this.token});

  final String token;
  io.Socket? _socket;

  final _messageListeners = <void Function(ChatMessage)>[];
  final _onlineListeners = <void Function(Set<int>)>[];
  final _typingListeners = <void Function(int userId, int conversationId)>[];
  final _stopTypingListeners = <void Function(int userId, int conversationId)>[];
  final _messagesReadListeners = <void Function(int conversationId, int readerId)>[];
  final _onlineUserIds = <int>{};

  // Group chat listeners
  final _groupMessageListeners = <void Function(GroupMessage)>[];
  final _groupTypingListeners = <void Function(int userId, int groupId)>[];
  final _groupStopTypingListeners = <void Function(int userId, int groupId)>[];
  final _groupReadListeners = <void Function(int groupId, int readerId, int lastReadMessageId)>[];
  Completer<void>? _connectedCompleter;

  void connect() {
    if (_socket?.connected == true) return;
    if (_socket != null) {
      _connectedCompleter ??= Completer<void>();
      _socket!.connect();
      return;
    }

    final socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(9999)
          .setReconnectionDelay(800)
          .setReconnectionDelayMax(3500)
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _connectedCompleter = Completer<void>();

    socket.onConnect((_) {
      if (_connectedCompleter?.isCompleted == false) {
        _connectedCompleter?.complete();
      }
    });

    socket.onDisconnect((_) {
      _connectedCompleter = Completer<void>();
    });

    socket.on('message_received', (data) {
      if (data is Map && data['message'] is Map) {
        final message = ChatMessage.fromJson(
          Map<String, dynamic>.from(data['message'] as Map),
        );
        for (final listener in _messageListeners) {
          listener(message);
        }
      }
    });

    socket.on('online_users', (data) {
      final ids = data is Map ? data['userIds'] : null;
      _onlineUserIds
        ..clear()
        ..addAll(_readIds(ids));
      _notifyOnline();
    });

    socket.on('user_online', (data) {
      final id = _readId(data is Map ? data['userId'] : null);
      if (id > 0) {
        _onlineUserIds.add(id);
        _notifyOnline();
      }
    });

    socket.on('user_offline', (data) {
      final id = _readId(data is Map ? data['userId'] : null);
      if (id > 0) {
        _onlineUserIds.remove(id);
        _notifyOnline();
      }
    });

    socket.on('user_typing', (data) {
      if (data is Map) {
        final userId = _readId(data['userId']);
        final conversationId = _readId(data['conversationId']);
        for (final listener in _typingListeners) {
          listener(userId, conversationId);
        }
      }
    });

    socket.on('user_stop_typing', (data) {
      if (data is Map) {
        final userId = _readId(data['userId']);
        final conversationId = _readId(data['conversationId']);
        for (final listener in _stopTypingListeners) {
          listener(userId, conversationId);
        }
      }
    });

    socket.on('messages_read', (data) {
      if (data is Map) {
        final readerId = _readId(data['readerId']);
        final conversationId = _readId(data['conversationId']);
        for (final listener in _messagesReadListeners) {
          listener(conversationId, readerId);
        }
      }
    });

    // -----------------------
    // Group events
    // -----------------------
    socket.on('group_message_received', (data) {
      if (data is Map && data['message'] is Map) {
        final message = GroupMessage.fromJson(
          Map<String, dynamic>.from(data['message'] as Map),
        );
        for (final listener in _groupMessageListeners) {
          listener(message);
        }
      }
    });

    socket.on('group_user_typing', (data) {
      if (data is Map) {
        final userId = _readId(data['userId']);
        final groupId = _readId(data['groupId']);
        for (final listener in _groupTypingListeners) {
          listener(userId, groupId);
        }
      }
    });

    socket.on('group_user_stop_typing', (data) {
      if (data is Map) {
        final userId = _readId(data['userId']);
        final groupId = _readId(data['groupId']);
        for (final listener in _groupStopTypingListeners) {
          listener(userId, groupId);
        }
      }
    });

    socket.on('group_messages_read', (data) {
      if (data is Map) {
        final readerId = _readId(data['readerId']);
        final groupId = _readId(data['groupId']);
        final lastReadMessageId = _readId(data['lastReadMessageId']);
        for (final listener in _groupReadListeners) {
          listener(groupId, readerId, lastReadMessageId);
        }
      }
    });

    _socket = socket;
    socket.connect();
  }

  Future<bool> _ensureConnected() async {
    if (_socket?.connected == true) return true;
    connect();
    final completer = _connectedCompleter;
    if (completer == null) return _socket?.connected == true;
    try {
      await completer.future.timeout(const Duration(seconds: 4));
      return _socket?.connected == true;
    } catch (_) {
      return false;
    }
  }

  Future<ChatMessage?> sendMessage({
    required int receiverId,
    String? content,
    String? imagePath,
    String type = 'text',
  }) async {
    final ready = await _ensureConnected();
    final socket = _socket;
    if (!ready || socket == null || socket.connected != true) return null;

    final completer = Completer<ChatMessage?>();
    final payload = <String, Object>{'receiverId': receiverId, 'type': type};
    if (content != null) payload['content'] = content;
    if (imagePath != null) payload['imagePath'] = imagePath;

    socket.emitWithAck(
      'send_message',
      payload,
      ack: (data) {
        if (data is Map && data['ok'] == true && data['message'] is Map) {
          completer.complete(
            ChatMessage.fromJson(
              Map<String, dynamic>.from(data['message'] as Map),
            ),
          );
          return;
        }
        completer.completeError(
          Exception(
            data is Map
                ? data['message'] ?? 'Message failed.'
                : 'Message failed.',
          ),
        );
      },
    );

    return completer.future.timeout(const Duration(seconds: 8));
  }

  Future<GroupMessage?> sendGroupMessage({
    required int groupId,
    String? content,
    String? imagePath,
    String type = 'text',
  }) async {
    final ready = await _ensureConnected();
    final socket = _socket;
    if (!ready || socket == null || socket.connected != true) return null;

    final completer = Completer<GroupMessage?>();
    final payload = <String, Object>{'groupId': groupId, 'type': type};
    if (content != null) payload['content'] = content;
    if (imagePath != null) payload['imagePath'] = imagePath;

    socket.emitWithAck(
      'send_group_message',
      payload,
      ack: (data) {
        if (data is Map && data['ok'] == true && data['message'] is Map) {
          completer.complete(
            GroupMessage.fromJson(
              Map<String, dynamic>.from(data['message'] as Map),
            ),
          );
          return;
        }
        completer.completeError(
          Exception(
            data is Map ? data['message'] ?? 'Message failed.' : 'Message failed.',
          ),
        );
      },
    );

    return completer.future.timeout(const Duration(seconds: 8));
  }

  void sendTyping(int receiverId, int conversationId) {
    unawaited(
      _ensureConnected().then((ready) {
        if (!ready) return;
        _socket?.emit('typing', {'receiverId': receiverId, 'conversationId': conversationId});
      }),
    );
  }

  void sendStopTyping(int receiverId, int conversationId) {
    unawaited(
      _ensureConnected().then((ready) {
        if (!ready) return;
        _socket?.emit('stop_typing', {'receiverId': receiverId, 'conversationId': conversationId});
      }),
    );
  }

  void sendMarkRead(int senderId, int conversationId) {
    unawaited(
      _ensureConnected().then((ready) {
        if (!ready) return;
        _socket?.emit('mark_read', {'senderId': senderId, 'conversationId': conversationId});
      }),
    );
  }

  void sendGroupTyping(int groupId) {
    unawaited(
      _ensureConnected().then((ready) {
        if (!ready) return;
        _socket?.emit('group_typing', {'groupId': groupId});
      }),
    );
  }

  void sendGroupStopTyping(int groupId) {
    unawaited(
      _ensureConnected().then((ready) {
        if (!ready) return;
        _socket?.emit('group_stop_typing', {'groupId': groupId});
      }),
    );
  }

  void sendMarkGroupRead(int groupId, int lastReadMessageId) {
    unawaited(
      _ensureConnected().then((ready) {
        if (!ready) return;
        _socket?.emit('mark_group_read', {'groupId': groupId, 'lastReadMessageId': lastReadMessageId});
      }),
    );
  }

  Future<bool> joinGroup(int groupId) async {
    final ready = await _ensureConnected();
    final socket = _socket;
    if (!ready || socket == null || socket.connected != true) return false;

    final completer = Completer<bool>();
    socket.emitWithAck(
      'join_group',
      {'groupId': groupId},
      ack: (data) {
        completer.complete(data is Map && data['ok'] == true);
      },
    );
    return completer.future.timeout(const Duration(seconds: 8), onTimeout: () => false);
  }

  void addMessageListener(void Function(ChatMessage) listener) {
    _messageListeners.add(listener);
  }

  void removeMessageListener(void Function(ChatMessage) listener) {
    _messageListeners.remove(listener);
  }

  void addOnlineListener(void Function(Set<int>) listener) {
    _onlineListeners.add(listener);
    listener(Set.unmodifiable(_onlineUserIds));
  }

  void removeOnlineListener(void Function(Set<int>) listener) {
    _onlineListeners.remove(listener);
  }

  void addTypingListener(void Function(int userId, int conversationId) listener) {
    _typingListeners.add(listener);
  }

  void removeTypingListener(void Function(int userId, int conversationId) listener) {
    _typingListeners.remove(listener);
  }

  void addStopTypingListener(void Function(int userId, int conversationId) listener) {
    _stopTypingListeners.add(listener);
  }

  void removeStopTypingListener(void Function(int userId, int conversationId) listener) {
    _stopTypingListeners.remove(listener);
  }

  void addMessagesReadListener(void Function(int conversationId, int readerId) listener) {
    _messagesReadListeners.add(listener);
  }

  void removeMessagesReadListener(void Function(int conversationId, int readerId) listener) {
    _messagesReadListeners.remove(listener);
  }

  void addGroupMessageListener(void Function(GroupMessage) listener) {
    _groupMessageListeners.add(listener);
  }

  void removeGroupMessageListener(void Function(GroupMessage) listener) {
    _groupMessageListeners.remove(listener);
  }

  void addGroupTypingListener(void Function(int userId, int groupId) listener) {
    _groupTypingListeners.add(listener);
  }

  void removeGroupTypingListener(void Function(int userId, int groupId) listener) {
    _groupTypingListeners.remove(listener);
  }

  void addGroupStopTypingListener(void Function(int userId, int groupId) listener) {
    _groupStopTypingListeners.add(listener);
  }

  void removeGroupStopTypingListener(void Function(int userId, int groupId) listener) {
    _groupStopTypingListeners.remove(listener);
  }

  void addGroupReadListener(
    void Function(int groupId, int readerId, int lastReadMessageId) listener,
  ) {
    _groupReadListeners.add(listener);
  }

  void removeGroupReadListener(
    void Function(int groupId, int readerId, int lastReadMessageId) listener,
  ) {
    _groupReadListeners.remove(listener);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _messageListeners.clear();
    _onlineListeners.clear();
    _typingListeners.clear();
    _stopTypingListeners.clear();
    _messagesReadListeners.clear();
    _groupMessageListeners.clear();
    _groupTypingListeners.clear();
    _groupStopTypingListeners.clear();
    _groupReadListeners.clear();
  }

  void _notifyOnline() {
    final snapshot = Set<int>.unmodifiable(_onlineUserIds);
    for (final listener in _onlineListeners) {
      listener(snapshot);
    }
  }
}

Iterable<int> _readIds(Object? value) {
  if (value is Iterable) {
    return value.map(_readId).where((id) => id > 0);
  }
  return const [];
}

int _readId(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/app_navigator.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../features/auth/presentation/screens/auth_gate.dart';
import '../features/calls/domain/call_state.dart';
import '../features/calls/presentation/providers/call_provider.dart';
import '../features/calls/presentation/widgets/incoming_call_overlay.dart';
import '../features/chat/presentation/providers/chat_providers.dart';

class ChatApp extends ConsumerStatefulWidget {
  const ChatApp({super.key});

  @override
  ConsumerState<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends ConsumerState<ChatApp> with WidgetsBindingObserver {
  bool _incomingDialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Eagerly initialise the call provider so incoming calls are caught immediately
    ref.read(callProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(chatSocketServiceProvider)?.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(chatSocketServiceProvider);
    ref.watch(callProvider);
    ref.listen<ActiveCall?>(callProvider, (previous, next) {
      final wasRinging = previous?.status == CallStatus.ringing;
      final isRinging = next?.status == CallStatus.ringing;
      if (isRinging && !wasRinging && next != null) {
        _showIncomingCallDialog(next);
      } else if (!isRinging && _incomingDialogVisible) {
        appNavigatorKey.currentState?.pop();
        _incomingDialogVisible = false;
      }
    });

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Rabta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        return IncomingCallOverlay(child: child ?? const SizedBox.shrink());
      },
      home: const AuthGate(),
    );
  }

  void _showIncomingCallDialog(ActiveCall call) {
    final context = appNavigatorKey.currentContext;
    if (context == null || _incomingDialogVisible) return;
    _incomingDialogVisible = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isVideo = call.type == CallType.video;
        return AlertDialog(
          title: Text(call.peerName),
          content: Row(
            children: [
              Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded),
              const SizedBox(width: 12),
              Text(isVideo ? 'Incoming video call' : 'Incoming voice call'),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.call_end_rounded),
              label: const Text('Decline'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _incomingDialogVisible = false;
                ref.read(callProvider.notifier).rejectCall();
              },
            ),
            FilledButton.icon(
              icon: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded),
              label: const Text('Answer'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _incomingDialogVisible = false;
                ref.read(callProvider.notifier).answerCall();
              },
            ),
          ],
        );
      },
    ).whenComplete(() {
      _incomingDialogVisible = false;
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/call_state.dart';
import '../providers/call_provider.dart';

/// A widget that wraps the entire app and shows an incoming call sheet
/// whenever the call state is [CallStatus.ringing].
class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callProvider);
    final isRinging = call?.status == CallStatus.ringing;

    return Stack(
      children: [
        child,
        if (isRinging && call != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _IncomingCallSheet(call: call),
          ),
      ],
    );
  }
}

class _IncomingCallSheet extends ConsumerWidget {
  const _IncomingCallSheet({required this.call});
  final ActiveCall call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = call.type == CallType.video;
    final initial = call.peerName.isNotEmpty ? call.peerName[0].toUpperCase() : '?';

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1e1b4b), Color(0xFF312e81)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name & type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    call.peerName,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: Colors.white60,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Decline
            GestureDetector(
              onTap: () => ref.read(callProvider.notifier).rejectCall(),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.shade600,
                ),
                child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 12),

            // Accept
            GestureDetector(
              onTap: () => ref.read(callProvider.notifier).answerCall(),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade600,
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

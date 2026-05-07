import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/call_state.dart';
import '../providers/call_provider.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({required this.peerName, required this.callType, super.key});

  final String peerName;
  final CallType callType;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  Timer? _durationTimer;
  int _seconds = 0;
  bool _renderersReady = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    final notifier = ref.read(callProvider.notifier);
    _localRenderer.srcObject = notifier.localStream;
    _remoteRenderer.srcObject = notifier.remoteStream;

    if (mounted) setState(() => _renderersReady = true);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);

    // Start timer when connected
    ref.listen<ActiveCall?>(callProvider, (prev, next) {
      if (prev?.status != CallStatus.connected &&
          next?.status == CallStatus.connected) {
        _startTimer();
        // Refresh renderers now that streams are ready
        final notifier = ref.read(callProvider.notifier);
        _localRenderer.srcObject = notifier.localStream;
        _remoteRenderer.srcObject = notifier.remoteStream;
      }
    });

    // Pop if call ended
    if (call == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    final isVideo = widget.callType == CallType.video;
    final isConnected = call?.status == CallStatus.connected;
    final isCalling = call?.status == CallStatus.calling;

    if (isVideo && isConnected && _renderersReady) {
      return _VideoCallView(
        localRenderer: _localRenderer,
        remoteRenderer: _remoteRenderer,
        peerName: widget.peerName,
        duration: _formatDuration(_seconds),
        call: call!,
        onMute: () => ref.read(callProvider.notifier).toggleMute(),
        onCameraToggle: () => ref.read(callProvider.notifier).toggleCamera(),
        onSwitchCamera: () => ref.read(callProvider.notifier).switchCamera(),
        onEnd: () => ref.read(callProvider.notifier).endCall(),
      );
    }

    return _VoiceCallView(
      peerName: widget.peerName,
      callType: widget.callType,
      status: isCalling ? 'Calling...' : isConnected ? _formatDuration(_seconds) : 'Connecting...',
      call: call,
      isConnected: isConnected,
      onMute: () => ref.read(callProvider.notifier).toggleMute(),
      onEnd: () => ref.read(callProvider.notifier).endCall(),
    );
  }
}

// Voice / connecting view

class _VoiceCallView extends StatelessWidget {
  const _VoiceCallView({
    required this.peerName,
    required this.callType,
    required this.status,
    required this.call,
    required this.isConnected,
    required this.onMute,
    required this.onEnd,
  });

  final String peerName;
  final CallType callType;
  final String status;
  final ActiveCall? call;
  final bool isConnected;
  final VoidCallback onMute;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top: name and status
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Text(
                      peerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          callType == CallType.video
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          color: Colors.white.withOpacity(0.6),
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          callType == CallType.video
                              ? 'Video Call'
                              : 'Voice Call',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: TextStyle(
                        color: isConnected ? const Color(0xFF4ade80) : Colors.white60,
                        fontSize: 16,
                        fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              // Middle: animated avatar
              _PulsingAvatar(name: peerName, isActive: !isConnected),

              // Bottom: controls
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlButton(
                      icon: call?.isMuted == true ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: call?.isMuted == true ? 'Unmute' : 'Mute',
                      color: call?.isMuted == true ? Colors.white : Colors.white54,
                      onTap: onMute,
                    ),
                    _EndCallButton(onTap: onEnd),
                    _ControlButton(
                      icon: Icons.volume_up_rounded,
                      label: 'Speaker',
                      color: Colors.white54,
                      onTap: () {},
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

// Video call view

class _VideoCallView extends StatelessWidget {
  const _VideoCallView({
    required this.localRenderer,
    required this.remoteRenderer,
    required this.peerName,
    required this.duration,
    required this.call,
    required this.onMute,
    required this.onCameraToggle,
    required this.onSwitchCamera,
    required this.onEnd,
  });

  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final String peerName;
  final String duration;
  final ActiveCall call;
  final VoidCallback onMute;
  final VoidCallback onCameraToggle;
  final VoidCallback onSwitchCamera;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          Positioned.fill(
            child: RTCVideoView(
              remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // Dark gradient overlay at top & bottom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0, height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top info
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        peerName,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(duration, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Local video (PiP)
          Positioned(
            top: 100,
            right: 16,
            width: 100,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: call.isCameraOff
                  ? Container(color: Colors.grey.shade900, child: const Icon(Icons.videocam_off, color: Colors.white54))
                  : RTCVideoView(
                      localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlButton(
                      icon: call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: call.isMuted ? 'Unmute' : 'Mute',
                      color: call.isMuted ? Colors.white : Colors.white60,
                      onTap: onMute,
                    ),
                    _ControlButton(
                      icon: call.isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      label: call.isCameraOff ? 'Camera Off' : 'Camera',
                      color: call.isCameraOff ? Colors.white : Colors.white60,
                      onTap: onCameraToggle,
                    ),
                    _EndCallButton(onTap: onEnd),
                    _ControlButton(
                      icon: Icons.flip_camera_ios_rounded,
                      label: 'Flip',
                      color: Colors.white60,
                      onTap: onSwitchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable widgets

class _PulsingAvatar extends StatefulWidget {
  const _PulsingAvatar({required this.name, required this.isActive});
  final String name;
  final bool isActive;

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = widget.isActive ? _pulse.value : 1.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isActive) ...[
              Transform.scale(
                scale: scale * 1.3,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Transform.scale(
                scale: scale * 1.15,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
            ],
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366f1).withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade600,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 6),
          const Text('End', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

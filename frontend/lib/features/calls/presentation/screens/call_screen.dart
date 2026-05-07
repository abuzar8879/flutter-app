import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    // Force full-screen immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initRenderers();
    _resetControlsTimer();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    final notifier = ref.read(callProvider.notifier);
    _localRenderer.srcObject = notifier.localStream;
    _remoteRenderer.srcObject = notifier.remoteStream;

    notifier.addRemoteStreamListener((stream) {
      if (!mounted) return;
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    });

    if (mounted) setState(() => _renderersReady = true);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _controlsTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.callType == CallType.video) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);

    // Start timer when connected
    if (call?.status == CallStatus.connected && _durationTimer == null) {
      _startTimer();
      // Re-sync renderer sources
      final notifier = ref.read(callProvider.notifier);
      _localRenderer.srcObject ??= notifier.localStream;
      _remoteRenderer.srcObject ??= notifier.remoteStream;
    } else if (call?.status != CallStatus.connected) {
      _durationTimer?.cancel();
      _durationTimer = null;
    }

    // Pop when call ends
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

    if (isVideo && _renderersReady) {
      return GestureDetector(
        onTap: _resetControlsTimer,
        child: _VideoCallView(
          localRenderer: _localRenderer,
          remoteRenderer: _remoteRenderer,
          peerName: widget.peerName,
          duration: _formatDuration(_seconds),
          call: call,
          isConnected: isConnected,
          controlsVisible: _controlsVisible,
          onMute: () => ref.read(callProvider.notifier).toggleMute(),
          onCameraToggle: () => ref.read(callProvider.notifier).toggleCamera(),
          onSwitchCamera: () => ref.read(callProvider.notifier).switchCamera(),
          onSpeaker: () => ref.read(callProvider.notifier).toggleSpeaker(),
          onEnd: () => ref.read(callProvider.notifier).endCall(),
        ),
      );
    }

    return _VoiceCallView(
      peerName: widget.peerName,
      callType: widget.callType,
      status: isCalling
          ? 'Calling...'
          : isConnected
              ? _formatDuration(_seconds)
              : 'Connecting...',
      call: call,
      isConnected: isConnected,
      onMute: () => ref.read(callProvider.notifier).toggleMute(),
      onSpeaker: () => ref.read(callProvider.notifier).toggleSpeaker(),
      onEnd: () => ref.read(callProvider.notifier).endCall(),
    );
  }
}

// ─── Voice Call View ────────────────────────────────────────────────────────

class _VoiceCallView extends StatelessWidget {
  const _VoiceCallView({
    required this.peerName,
    required this.callType,
    required this.status,
    required this.call,
    required this.isConnected,
    required this.onMute,
    required this.onSpeaker,
    required this.onEnd,
  });

  final String peerName;
  final CallType callType;
  final String status;
  final ActiveCall? call;
  final bool isConnected;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top: name + status ──────────────────────────────────────
              const SizedBox(height: 48),
              Text(
                peerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    callType == CallType.video
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    color: Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    callType == CallType.video ? 'Video Call' : 'Voice Call',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                status,
                style: TextStyle(
                  color: isConnected
                      ? const Color(0xFF4ade80)
                      : Colors.white60,
                  fontSize: 16,
                  fontWeight:
                      isConnected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),

              // ── Middle: pulsing avatar ──────────────────────────────────
              const Spacer(),
              _PulsingAvatar(name: peerName, isActive: !isConnected),
              const Spacer(),

              // ── Bottom: controls ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlButton(
                      icon: call?.isMuted == true
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: call?.isMuted == true ? 'Unmute' : 'Mute',
                      active: call?.isMuted == true,
                      onTap: onMute,
                    ),
                    _EndCallButton(onTap: onEnd),
                    _ControlButton(
                      icon: call?.isSpeakerOn == false
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      label: call?.isSpeakerOn == false ? 'Earpiece' : 'Speaker',
                      active: call?.isSpeakerOn ?? true,
                      onTap: onSpeaker,
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

// ─── Video Call View ─────────────────────────────────────────────────────────

class _VideoCallView extends StatelessWidget {
  const _VideoCallView({
    required this.localRenderer,
    required this.remoteRenderer,
    required this.peerName,
    required this.duration,
    required this.call,
    required this.isConnected,
    required this.controlsVisible,
    required this.onMute,
    required this.onCameraToggle,
    required this.onSwitchCamera,
    required this.onSpeaker,
    required this.onEnd,
  });

  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final String peerName;
  final String duration;
  final ActiveCall? call;
  final bool isConnected;
  final bool controlsVisible;
  final VoidCallback onMute;
  final VoidCallback onCameraToggle;
  final VoidCallback onSwitchCamera;
  final VoidCallback onSpeaker;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Remote video (true full-screen background) ─────────────────
          remoteRenderer.srcObject != null
              ? RTCVideoView(
                  remoteRenderer,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : _VideoPlaceholder(peerName: peerName, isConnected: isConnected),

          // ── Dark gradient at top ────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Dark gradient at bottom ─────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Top info bar ────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Positioned(
              top: safePadding.top + 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        peerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 6, color: Color(0x54000000))
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected ? duration : 'Connecting...',
                        style: TextStyle(
                          color: isConnected
                              ? const Color(0xFF4ade80)
                              : Colors.white70,
                          fontSize: 14,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Color(0x54000000))
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Local video PiP ─────────────────────────────────────────────
          Positioned(
            top: safePadding.top + 80,
            right: 16,
            width: 100,
            height: 140,
            child: AnimatedOpacity(
              opacity: controlsVisible ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: call?.isCameraOff == true
                    ? Container(
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Icon(
                            Icons.videocam_off,
                            color: Colors.white54,
                            size: 28,
                          ),
                        ),
                      )
                    : localRenderer.srcObject != null
                        ? RTCVideoView(
                            localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          )
                        : Container(
                            color: Colors.grey.shade900,
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white38,
                                size: 36,
                              ),
                            ),
                          ),
              ),
            ),
          ),

          // ── Bottom controls ─────────────────────────────────────────────
          AnimatedOpacity(
            opacity: controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Positioned(
              bottom: safePadding.bottom + 24,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: call?.isMuted == true
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: call?.isMuted == true ? 'Unmute' : 'Mute',
                        active: call?.isMuted == true,
                        onTap: onMute,
                      ),
                      _ControlButton(
                        icon: call?.isCameraOff == true
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        label: call?.isCameraOff == true
                            ? 'Cam Off'
                            : 'Camera',
                        active: call?.isCameraOff == true,
                        onTap: onCameraToggle,
                      ),
                      _EndCallButton(onTap: onEnd),
                      _ControlButton(
                        icon: call?.isSpeakerOn == false
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        label: call?.isSpeakerOn == false
                            ? 'Earpiece'
                            : 'Speaker',
                        active: call?.isSpeakerOn ?? true,
                        onTap: onSpeaker,
                      ),
                      _ControlButton(
                        icon: Icons.flip_camera_ios_rounded,
                        label: 'Flip',
                        active: false,
                        onTap: onSwitchCamera,
                      ),
                    ],
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

// ─── Video Placeholder ───────────────────────────────────────────────────────

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder(
      {required this.peerName, required this.isConnected});

  final String peerName;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF0f172a), Color(0xFF020617)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingAvatar(name: peerName, isActive: !isConnected),
            const SizedBox(height: 20),
            Text(
              isConnected ? 'Camera Off' : 'Connecting...',
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pulsing Avatar ──────────────────────────────────────────────────────────

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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
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
                    color: Colors.white.withValues(alpha: 0.05),
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
                    color: Colors.white.withValues(alpha: 0.08),
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
                    color: const Color(0xFF6366f1).withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Control Button ──────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.15),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: active ? Colors.black87 : Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── End Call Button ─────────────────────────────────────────────────────────

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
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade600,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'End',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

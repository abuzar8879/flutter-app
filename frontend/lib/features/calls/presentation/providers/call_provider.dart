import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../users/domain/app_user.dart';
import '../../data/call_signaling_service.dart';
import '../../domain/call_state.dart';
import '../screens/call_screen.dart';

/// Surfaces call errors (e.g. no microphone) to the UI as a one-shot message.
final callErrorProvider = NotifierProvider<CallErrorController, String?>(
  CallErrorController.new,
);

class CallErrorController extends Notifier<String?> {
  @override
  String? build() => null;

  void setMessage(String message) {
    state = message;
  }

  void clear() {
    state = null;
  }
}

final callProvider = NotifierProvider<CallNotifier, ActiveCall?>(CallNotifier.new);

class CallNotifier extends Notifier<ActiveCall?> {
  CallSignalingService? _signalingService;
  bool _isInitializing = false;

  @override
  ActiveCall? build() {
    final socketSvc = ref.watch(chatSocketServiceProvider);
    if (socketSvc != null) {
      socketSvc.addIncomingCallListener(_onIncomingCall);
      socketSvc.addCallAnsweredListener(_onCallAnswered);
      socketSvc.addCallRejectedListener(_onCallRejected);
      socketSvc.addCallEndedListener(_onCallEnded);
      socketSvc.addRemoteIceCandidateListener(_onRemoteIceCandidate);

      ref.onDispose(() {
        socketSvc.removeIncomingCallListener(_onIncomingCall);
        socketSvc.removeCallAnsweredListener(_onCallAnswered);
        socketSvc.removeCallRejectedListener(_onCallRejected);
        socketSvc.removeCallEndedListener(_onCallEnded);
        socketSvc.removeRemoteIceCandidateListener(_onRemoteIceCandidate);
        _signalingService?.dispose();
        _signalingService = null;
      });
    }
    return null;
  }

  // Incoming call (callee side)
  void _onIncomingCall(
    String callerId,
    String callerName,
    Map<String, dynamic> sdp,
    String type,
  ) {
    if (state != null) return; // already in a call
    state = ActiveCall(
      peerId: callerId,
      peerName: callerName.isNotEmpty ? callerName : 'Unknown',
      type: type == 'video' ? CallType.video : CallType.voice,
      status: CallStatus.ringing,
      isOutgoing: false,
      pendingOfferSdp: sdp,
    );
  }

  Future<void> _onCallAnswered(String calleeId, Map<String, dynamic> sdp) async {
    final current = state;
    if (current == null || current.peerId != calleeId) return;
    await _signalingService?.setRemoteDescription(sdp);
    state = current.copyWith(status: CallStatus.connected);
  }

  void _onCallRejected(String calleeId) {
    final current = state;
    if (current == null || current.peerId != calleeId) return;
    _cleanup();
    appNavigatorKey.currentState?.pop();
  }

  void _onCallEnded(String peerId) {
    if (state == null || state!.peerId != peerId) return;
    _cleanup();
    appNavigatorKey.currentState?.pop();
  }

  void _onRemoteIceCandidate(String peerId, Map<String, dynamic> candidate) {
    _signalingService?.addIceCandidate(candidate);
  }

  // Outgoing call
  Future<void> startCall({required AppUser peer, required CallType type}) async {
    if (state != null || _isInitializing) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final socket = ref.read(chatSocketServiceProvider);
    if (socket == null) return;

    _isInitializing = true;
    final svc = CallSignalingService();
    _signalingService = svc;

    try {
      await svc.initialize(isVideo: type == CallType.video);
    } catch (e) {
      svc.dispose();
      _signalingService = null;
      _isInitializing = false;
      ref
          .read(callErrorProvider.notifier)
          .setMessage(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    _isInitializing = false;

    state = ActiveCall(
      peerId: peer.id,
      peerName: peer.name,
      type: type,
      status: CallStatus.calling,
      isOutgoing: true,
    );

    svc.addIceCandidateListener((c) {
      socket.emitIceCandidate(peerId: peer.id, candidate: {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    });

    svc.addConnectionStateListener((s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        endCall();
      }
    });

    final offer = await svc.createOffer();
    await socket.emitCallOffer(
      calleeId: peer.id,
      sdp: offer,
      type: type == CallType.video ? 'video' : 'voice',
      callerName: session.user.name,
    );

    appNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/call'),
        builder: (_) => CallScreen(peerName: peer.name, callType: type),
      ),
    );
  }

  // Answer incoming call
  Future<void> answerCall() async {
    final current = state;
    if (current == null || current.status != CallStatus.ringing || _isInitializing) return;
    final socket = ref.read(chatSocketServiceProvider);
    if (socket == null) return;

    _isInitializing = true;
    final svc = CallSignalingService();
    _signalingService = svc;

    try {
      await svc.initialize(isVideo: current.type == CallType.video);
    } catch (e) {
      svc.dispose();
      _signalingService = null;
      _isInitializing = false;
      // Reject the call since we can't initialize media
      socket.emitCallRejected(callerId: current.peerId);
      _cleanup();
      ref
          .read(callErrorProvider.notifier)
          .setMessage(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    _isInitializing = false;

    svc.addIceCandidateListener((c) {
      socket.emitIceCandidate(peerId: current.peerId, candidate: {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    });

    svc.addConnectionStateListener((s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        endCall();
      }
    });

    if (current.pendingOfferSdp != null) {
      await svc.setRemoteDescription(current.pendingOfferSdp!);
    }
    final answer = await svc.createAnswer();
    socket.emitCallAnswer(callerId: current.peerId, sdp: answer);

    state = current.copyWith(status: CallStatus.connected, pendingOfferSdp: null);

    appNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/call'),
        builder: (_) => CallScreen(peerName: current.peerName, callType: current.type),
      ),
    );
  }

  // Reject
  void rejectCall() {
    final current = state;
    if (current == null) return;
    ref.read(chatSocketServiceProvider)?.emitCallRejected(callerId: current.peerId);
    _cleanup();
  }

  // End
  void endCall() {
    final current = state;
    if (current == null) return;
    ref.read(chatSocketServiceProvider)?.emitCallEnded(peerId: current.peerId);
    _cleanup();
    appNavigatorKey.currentState?.pop();
  }

  // Controls
  void toggleMute() {
    final current = state;
    if (current == null) return;
    final next = !current.isMuted;
    _signalingService?.setMuted(next);
    state = current.copyWith(isMuted: next);
  }

  void toggleCamera() {
    final current = state;
    if (current == null) return;
    final next = !current.isCameraOff;
    _signalingService?.setCameraEnabled(!next);
    state = current.copyWith(isCameraOff: next);
  }

  void switchCamera() => _signalingService?.switchCamera();

  MediaStream? get localStream => _signalingService?.localStream;
  MediaStream? get remoteStream => _signalingService?.remoteStream;

  void _cleanup() {
    _signalingService?.dispose();
    _signalingService = null;
    state = null;
  }
}

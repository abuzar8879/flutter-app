import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Manages the WebRTC peer connection, local/remote streams, and media controls.
class CallSignalingService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isVideo = false;
  bool _isSpeakerOn = true;
  bool _hasRemoteDescription = false;
  final _pendingRemoteCandidates = <Map<String, dynamic>>[];

  final _iceCandidateListeners = <void Function(RTCIceCandidate)>[];
  final _remoteStreamListeners = <void Function(MediaStream)>[];
  final _connectionStateListeners = <void Function(RTCPeerConnectionState)>[];

  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  Future<void> initialize({required bool isVideo}) async {
    _isVideo = isVideo;
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideo ? {'facingMode': 'user'} : false,
      });
    } catch (e) {
      if (isVideo) {
        throw Exception(
          'Camera or microphone not found. Please connect a device and grant camera and microphone permissions.',
        );
      } else {
        throw Exception(
          'Microphone not found. Please connect a microphone and grant browser permissions.',
        );
      }
    }

    _peerConnection = await createPeerConnection(_iceConfig);
    try {
      await Helper.setSpeakerphoneOn(true);
    } catch (_) {}

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        for (final l in _remoteStreamListeners) {
          l(_remoteStream!);
        }
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      for (final l in _iceCandidateListeners) {
        l(candidate);
      }
    };

    _peerConnection!.onConnectionState = (state) {
      for (final l in _connectionStateListeners) {
        l(state);
      }
    };
  }

  Future<Map<String, dynamic>> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _isVideo,
    });
    await _peerConnection!.setLocalDescription(offer);
    return {'type': offer.type, 'sdp': offer.sdp};
  }

  Future<Map<String, dynamic>> createAnswer() async {
    final answer = await _peerConnection!.createAnswer({});
    await _peerConnection!.setLocalDescription(answer);
    return {'type': answer.type, 'sdp': answer.sdp};
  }

  Future<void> setRemoteDescription(Map<String, dynamic> sdpMap) async {
    final sdp = RTCSessionDescription(
      sdpMap['sdp'] as String?,
      sdpMap['type'] as String?,
    );
    await _peerConnection!.setRemoteDescription(sdp);
    _hasRemoteDescription = true;

    final pending = List<Map<String, dynamic>>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in pending) {
      await addIceCandidate(candidate);
    }
  }

  Future<void> addIceCandidate(Map<String, dynamic> candidateMap) async {
    try {
      if (!_hasRemoteDescription) {
        _pendingRemoteCandidates.add(candidateMap);
        return;
      }
      final lineIndex = candidateMap['sdpMLineIndex'];
      final candidate = RTCIceCandidate(
        candidateMap['candidate'] as String?,
        candidateMap['sdpMid'] as String?,
        lineIndex is int ? lineIndex : int.tryParse('$lineIndex'),
      );
      await _peerConnection?.addCandidate(candidate);
    } catch (_) {}
  }

  void setMuted(bool muted) {
    for (final track in _localStream?.getAudioTracks() ?? []) {
      track.enabled = !muted;
    }
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
    } catch (_) {}
  }

  bool get isSpeakerOn => _isSpeakerOn;

  void setCameraEnabled(bool enabled) {
    for (final track in _localStream?.getVideoTracks() ?? []) {
      track.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
    }
  }

  void addIceCandidateListener(void Function(RTCIceCandidate) l) =>
      _iceCandidateListeners.add(l);
  void addRemoteStreamListener(void Function(MediaStream) l) =>
      _remoteStreamListeners.add(l);
  void addConnectionStateListener(void Function(RTCPeerConnectionState) l) =>
      _connectionStateListeners.add(l);

  void dispose() {
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.close();
    _peerConnection?.dispose();
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _isVideo = false;
    _hasRemoteDescription = false;
    _pendingRemoteCandidates.clear();
    _iceCandidateListeners.clear();
    _remoteStreamListeners.clear();
    _connectionStateListeners.clear();
  }
}

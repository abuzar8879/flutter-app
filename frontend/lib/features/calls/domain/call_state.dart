enum CallType { voice, video }

enum CallStatus { idle, calling, ringing, connected }

class ActiveCall {
  const ActiveCall({
    required this.peerId,
    required this.peerName,
    required this.type,
    required this.status,
    required this.isOutgoing,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isSpeakerOn = true,
    this.pendingOfferSdp,
  });

  final String peerId;
  final String peerName;
  final CallType type;
  final CallStatus status;
  final bool isOutgoing;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final Map<String, dynamic>? pendingOfferSdp;

  ActiveCall copyWith({
    String? peerId,
    String? peerName,
    CallType? type,
    CallStatus? status,
    bool? isOutgoing,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeakerOn,
    Map<String, dynamic>? pendingOfferSdp,
  }) {
    return ActiveCall(
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      type: type ?? this.type,
      status: status ?? this.status,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      pendingOfferSdp: pendingOfferSdp ?? this.pendingOfferSdp,
    );
  }
}

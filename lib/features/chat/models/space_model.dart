class SpaceModel {
  final String id;
  final String title;
  final String? description;
  final String mode;
  final String hostName;
  final bool isHost;
  final String regionCode;
  final int participantCount;
  final List<Map<String, dynamic>> friendsPresent;
  final bool recordingEnabled;
  final DateTime? scheduledAt;

  const SpaceModel({
    required this.id,
    required this.title,
    this.description,
    this.mode = 'voice',
    this.hostName = 'Griot user',
    this.isHost = false,
    this.regionCode = 'GLOBAL',
    this.participantCount = 0,
    this.friendsPresent = const [],
    this.recordingEnabled = false,
    this.scheduledAt,
  });

  factory SpaceModel.fromJson(Map<String, dynamic> json) => SpaceModel(
    id: '${json['id'] ?? json['_id'] ?? json['spaceId'] ?? json['space_id'] ?? ''}',
    title:
        '${json['title'] ?? json['name'] ?? json['topic'] ?? 'Untitled Campfire'}',
    description: (json['description'] ?? json['summary'])?.toString(),
    mode: _canonicalCampfireMode(json['mode'] ?? json['type']),
    hostName: _displayIdentity(
      json['host_name'] ?? json['hostName'] ?? 'Griot user',
    ),
    isHost: json['is_host'] == true || json['isHost'] == true,
    regionCode:
        '${json['region_code'] ?? json['regionCode'] ?? json['region'] ?? 'GLOBAL'}',
    participantCount:
        int.tryParse(
          '${json['participant_count'] ?? json['participantCount'] ?? json['listenersCount'] ?? json['participantsCount'] ?? (json['participants'] is List ? (json['participants'] as List).length : 0)}',
        ) ??
        0,
    friendsPresent: _parseFriends(
      json['friends_present'] ?? json['friendsPresent'],
    ),
    recordingEnabled:
        json['recording_enabled'] == true || json['recordingEnabled'] == true,
    scheduledAt: DateTime.tryParse(
      '${json['scheduled_at'] ?? json['scheduledAt'] ?? ''}',
    ),
  );

  static String _canonicalCampfireMode(Object? value) {
    return value?.toString().toLowerCase() == 'video' ? 'video' : 'voice';
  }

  static List<Map<String, dynamic>> _parseFriends(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) {
          final mapped = Map<String, dynamic>.from(item);
          final name = mapped['displayName'] ?? mapped['display_name'];
          if (name != null) {
            mapped['displayName'] = _displayIdentity(name);
          }
          return mapped;
        })
        .toList(growable: false);
  }

  static String _displayIdentity(Object? value) {
    final text = value?.toString().trim() ?? '';
    final walletLike =
        text.length >= 12 &&
        (text.startsWith('0x') || RegExp(r'^[a-fA-F0-9]+$').hasMatch(text));
    if (walletLike) {
      return '${text.substring(0, 3)}…${text.substring(text.length - 3)}';
    }
    return text.isEmpty ? 'Griot user' : text;
  }
}

class SpaceParticipant {
  final String id;
  final String name;
  final String role;
  final bool muted;
  final bool isOwner;
  final bool isSelf;
  final bool speakerRequested;
  final String? avatarUrl;

  const SpaceParticipant({
    required this.id,
    required this.name,
    required this.role,
    required this.muted,
    required this.isOwner,
    required this.isSelf,
    required this.speakerRequested,
    this.avatarUrl,
  });

  factory SpaceParticipant.fromJson(Map<String, dynamic> json) =>
      SpaceParticipant(
        id: '${json['id'] ?? json['user_id'] ?? ''}',
        name: _participantName(json),
        role: '${json['role'] ?? 'listener'}',
        muted: json['muted'] == true,
        isOwner: json['is_owner'] == true || json['isOwner'] == true,
        isSelf: json['is_self'] == true || json['isSelf'] == true,
        speakerRequested:
            json['speaker_requested_at'] != null ||
            json['speakerRequested'] == true,
        avatarUrl: _participantAvatarUrl(json),
      );

  static String? _participantAvatarUrl(Map<String, dynamic> json) {
    final profile = json['profile'];
    final profileMap = profile is Map
        ? Map<String, dynamic>.from(profile)
        : const <String, dynamic>{};
    final value =
        json['avatar_url'] ??
        json['avatarUrl'] ??
        json['profile_url'] ??
        json['profileUrl'] ??
        json['image_url'] ??
        json['imageUrl'] ??
        profileMap['avatar_url'] ??
        profileMap['avatarUrl'] ??
        profileMap['profile_url'] ??
        profileMap['profileUrl'];
    final url = value?.toString().trim();
    return url == null || url.isEmpty ? null : url;
  }

  static String _participantName(Map<String, dynamic> json) {
    bool usable(Object? value) {
      final s = value?.toString().trim() ?? '';
      return s.isNotEmpty && s.toLowerCase() != 'griot user';
    }

    for (final value in [
      json['display_name'],
      json['displayName'],
      json['username'],
      json['name'],
    ]) {
      if (usable(value)) {
        final text = value.toString().trim();
        final walletLike =
            text.length >= 12 &&
            (text.startsWith('0x') || RegExp(r'^[a-fA-F0-9]+$').hasMatch(text));
        if (walletLike) {
          return '${text.substring(0, 3)}…${text.substring(text.length - 3)}';
        }
        return text;
      }
    }
    final wallet = '${json['wallet_address'] ?? json['walletAddress'] ?? ''}'
        .trim();
    if (wallet.length > 6) {
      return '${wallet.substring(0, 3)}…${wallet.substring(wallet.length - 3)}';
    }
    return wallet.isEmpty ? 'Griot user' : wallet;
  }
}

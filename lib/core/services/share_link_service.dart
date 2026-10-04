import '../../features/chat/models/conversation_model.dart';
import '../../features/users/models/user_model.dart';

/// Canonical public links shared by the app.
///
/// Conversation links intentionally require a username. An ID is not a valid
/// value for the `/username/:username` API route, so callers must handle a
/// missing username instead of generating a link that can never resolve.
class ShareLinkService {
  ShareLinkService._();

  static const _origin = 'https://griot.network';

  /// Builds the one canonical referral URL used by every share surface.
  static String referral(String code) {
    final normalized = _pathValue(code) ?? code.trim();
    return '$_origin/join?ref=${Uri.encodeQueryComponent(normalized)}';
  }

  static String? conversation(Conversation conversation) {
    if (conversation.type != ConversationType.group &&
        conversation.type != ConversationType.channel) {
      return null;
    }

    final username = _username(conversation.username);
    if (username == null) return null;

    // Keep the URL path aligned with the actual conversation type.  The
    // username itself is already the canonical identifier; the @ prefix is a
    // display convention, not part of the public link.
    final segment = conversation.type == ConversationType.channel
        ? 'channel'
        : 'group';
    return '$_origin/$segment/${Uri.encodeComponent(username)}';
  }

  static String? profile(UserModel user) {
    final username = _username(user.username);
    if (username != null) {
      return '$_origin/profile/${Uri.encodeComponent(username)}';
    }

    final id = user.id.trim();
    if (id.isEmpty) return null;
    return '$_origin/profile/${Uri.encodeComponent(id)}';
  }

  static String? _username(String? value) {
    final normalized = _pathValue(value);
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String? _pathValue(String? value) {
    final normalized = value
        ?.trim()
        .replaceFirst(RegExp(r'^@+'), '')
        .replaceAll(RegExp(r'^/+|/+$'), '');
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

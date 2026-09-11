import 'user_model.dart';

class AuthenticationResponse {
  final UserModel user;
  final bool isNewUser;
  final String accessToken;
  final String refreshToken;

  const AuthenticationResponse({
    required this.user,
    required this.isNewUser,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthenticationResponse.fromJson(Map<String, dynamic> json) {
    final resp = AuthenticationResponse(
      user: UserModel.fromJson(
        json['user'] as Map<String, dynamic>,
      ),
      isNewUser: (json['isNewUser'] ?? json['is_new_user']) == true,
      accessToken:
          (json['accessToken'] ?? json['access_token'])?.toString() ?? '',
      refreshToken:
          (json['refreshToken'] ?? json['refresh_token'])?.toString() ?? '',
    );

    if (resp.accessToken.isEmpty || resp.refreshToken.isEmpty) {
      throw Exception(
        'Authentication failed: Missing tokens in server response.',
      );
    }

    return resp;
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'isNewUser': isNewUser,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}

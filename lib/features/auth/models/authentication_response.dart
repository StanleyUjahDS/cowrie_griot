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

  factory AuthenticationResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    return AuthenticationResponse(
      user: UserModel.fromJson(
        json['user'] as Map<String, dynamic>,
      ),
      isNewUser: json['isNewUser'] == true,
      accessToken:
      json['accessToken']?.toString() ?? '',
      refreshToken:
      json['refreshToken']?.toString() ?? '',
    );
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
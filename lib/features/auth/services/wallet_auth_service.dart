import '../models/authentication_response.dart';
import 'auth_api_service.dart';
import '/features/wallet/services/wallet_service.dart';

class WalletAuthService {
  final WalletService _walletService;
  final AuthApiService _authApiService;

  WalletAuthService({
    required WalletService walletService,
    required AuthApiService authApiService,
  })  : _walletService = walletService,
        _authApiService = authApiService;

  // ============================================================
  // AUTHENTICATE WALLET
  // ============================================================

  Future<AuthenticationResponse> authenticateWallet() async {
    // ----------------------------------------------------------
    // GET WALLET ADDRESS
    // ----------------------------------------------------------

    final walletAddress =
    await _walletService.getAddress();

    if (walletAddress == null ||
        walletAddress.isEmpty) {
      throw Exception(
        'Wallet address not found.',
      );
    }

    // ----------------------------------------------------------
    // REQUEST NONCE
    // ----------------------------------------------------------

    final nonceResponse =
    await _authApiService.requestNonce(
      walletAddress: walletAddress,
    );

    // ----------------------------------------------------------
    // SIGN AUTHENTICATION MESSAGE
    // ----------------------------------------------------------

    final signature =
    await _walletService.signMessage(
      nonceResponse.message,
    );

    if (signature == null ||
        signature.isEmpty) {
      throw Exception(
        'Unable to sign authentication message.',
      );
    }

    // ----------------------------------------------------------
    // VERIFY WALLET
    // ----------------------------------------------------------

    final authenticationResponse =
    await _authApiService.verifyWallet(
      walletAddress: walletAddress,
      nonce: nonceResponse.nonce,
      signature: signature,
    );

    // ----------------------------------------------------------
    // RETURN AUTHENTICATION RESULT
    // ----------------------------------------------------------

    return authenticationResponse;
  }
}
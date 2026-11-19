import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import '../models/plus_status_model.dart';
import '../services/plus_api_service.dart';

class IapProvider extends ChangeNotifier {
  final PlusApiService _apiService;
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  static const String monthlyId = 'griot_plus_monthly';
  static const String yearlyId = 'griot_plus_yearly';
  static const Set<String> _productIds = {monthlyId, yearlyId};

  PlusStatus _status = PlusStatus.none();
  List<ProductDetails> _products = [];
  bool _isStoreAvailable = false;
  bool _isLoading = true;
  bool _isVerifying = false;
  bool _initialStoreRestoreRequested = false;
  String? _error;
  final Map<String, PurchaseDetails> _pendingVerifications = {};
  final Set<String> _verificationInFlight = {};
  int _verificationGeneration = 0;

  PlusStatus get status => _status;
  List<ProductDetails> get products => _products;
  bool get isStoreAvailable => _isStoreAvailable;
  bool get isLoading => _isLoading;
  bool get isVerifying => _isVerifying;
  String? get error => _error;
  bool get hasPendingVerification => _pendingVerifications.isNotEmpty;

  IapProvider({required PlusApiService apiService}) : _apiService = apiService {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
    refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Fetch backend status (source of truth)
      try {
        _status = await _apiService.getStatus();
      } catch (e) {
        debugPrint('IAP: Backend status check failed: $e');
        _error = 'Unable to confirm your Plus membership.';
      }

      // 2. Initialize store
      _isStoreAvailable = await _iap.isAvailable();
      if (_isStoreAvailable) {
        final ProductDetailsResponse response = await _iap.queryProductDetails(
          _productIds,
        );

        if (response.error != null) {
          debugPrint('IAP: StoreKit error: ${response.error?.message}');
          _handleStoreFailure('Subscriptions are temporarily unavailable.');
        } else if (response.productDetails.isEmpty) {
          debugPrint('IAP: No products found.');
          _handleStoreFailure(
            'No subscription products are currently available.',
          );
        } else {
          _products = response.productDetails;
          _products.sort((a, b) => a.id.contains('monthly') ? -1 : 1);
          if ((Platform.isIOS || Platform.isAndroid) &&
              !_initialStoreRestoreRequested) {
            _initialStoreRestoreRequested = true;
            // Store restores replay existing transactions to purchaseStream,
            // allowing the backend to re-verify subscribers after an update
            // or reinstall.
            unawaited(_restoreStorePurchases());
          }
        }
      } else {
        _handleStoreFailure('The app store is unavailable.');
      }
    } catch (e) {
      debugPrint('IAP: initialization error: $e');
      _handleStoreFailure('Subscriptions are temporarily unavailable.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _useMockProducts() {
    if (!kDebugMode) {
      _setUnavailable('Subscriptions are temporarily unavailable.');
      return;
    }

    _products = [
      _MockProductDetails(
        id: monthlyId,
        title: 'Griot Plus Monthly',
        description: 'Premium Griot features monthly',
        price: '\$4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      ),
      _MockProductDetails(
        id: yearlyId,
        title: 'Griot Plus Yearly',
        description: 'Premium Griot features yearly',
        price: '\$49.99',
        rawPrice: 49.99,
        currencyCode: 'USD',
      ),
    ];
    _isStoreAvailable = true;
  }

  void _handleStoreFailure(String message) {
    if (kDebugMode) {
      _useMockProducts();
    } else {
      _setUnavailable(message);
    }
  }

  void _setUnavailable(String message) {
    _products = [];
    _isStoreAvailable = false;
    _error = message;
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _restoreStorePurchases({bool bestEffort = true}) async {
    try {
      if (Platform.isIOS) {
        // StoreKit 2 can keep the transaction on the App Store while the
        // local queue is stale. Synchronise first so Restore Purchases can
        // replay the transaction to purchaseStream.
        final addition = _iap
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        try {
          await addition.sync();
        } catch (error) {
          // A StoreKit sync failure must not prevent the normal restore queue
          // from replaying the purchase.
          debugPrint(
            'IAP: StoreKit sync failed; continuing with restore: $error',
          );
        }
      }
      await _iap.restorePurchases();
    } catch (error) {
      // Startup restore is best-effort. An explicit restore call rethrows so
      // the UI can tell the user that StoreKit could not complete the request.
      debugPrint('IAP: automatic restore failed: $error');
      if (!bestEffort) rethrow;
    }
  }

  Future<void> restorePurchases() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final verificationGeneration = _verificationGeneration;
      await _restoreStorePurchases(bestEffort: false);
      // StoreKit delivers restored purchases asynchronously through
      // purchaseStream. Do not read the backend entitlement until the replayed
      // transactions have had time to enter and leave verification.
      await _waitForRestoreVerification(verificationGeneration);
      // StoreKit may replay the transaction asynchronously through the
      // purchase stream. Retry any transaction that previously reached Apple
      // but failed while our API was unavailable.
      await _retryPendingVerifications();
      // The purchase stream is asynchronous. Always re-read the server
      // entitlement as the final source of truth after restore.
      _status = await _apiService.getStatus();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _waitForRestoreVerification(int generationAtStart) async {
    // StoreKit returns from restore before it dispatches restored transactions
    // to purchaseStream. Wait for an actual verification callback instead of
    // reading the backend after a short fixed delay.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (_verificationGeneration > generationAtStart &&
          _verificationInFlight.isEmpty) {
        // Allow any duplicate restored transaction callbacks to settle before
        // the final entitlement read.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    debugPrint('IAP: restore verification wait timed out');
  }

  String _purchaseKey(PurchaseDetails purchase) =>
      '${purchase.productID}:${purchase.purchaseID}:${purchase.transactionDate ?? ''}';

  Future<void> _retryPendingVerifications() async {
    final pending = List<PurchaseDetails>.from(_pendingVerifications.values);
    for (final purchase in pending) {
      final success = await _verifyAndComplete(purchase);
      if (success && purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _isLoading = true;
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _error = purchase.error?.message;
        _isLoading = false;
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final success = await _verifyAndComplete(purchase);
        if (success && purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }

      if (purchase.status == PurchaseStatus.canceled &&
          purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<bool> _verifyAndComplete(PurchaseDetails purchase) async {
    final key = _purchaseKey(purchase);
    if (!_verificationInFlight.add(key)) return false;
    _isVerifying = true;
    notifyListeners();

    try {
      debugPrint(
        'IAP: verifying product=${purchase.productID} '
        'status=${purchase.status} '
        'purchaseId=${purchase.purchaseID ?? '(missing)'} '
        'source=${purchase.verificationData.source}',
      );
      String provider = Platform.isIOS ? 'apple' : 'google';
      String? receipt;
      String? purchaseToken;
      String? originalTransactionId;

      if (Platform.isIOS) {
        // StoreKit 2 exposes a JWS transaction in serverVerificationData,
        // while Apple's legacy verifyReceipt endpoint expects the refreshed
        // base64 app receipt. Always refresh it before sending to the API.
        final addition = _iap
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        final refreshed = await addition.refreshPurchaseVerificationData();
        final refreshedVerification =
            refreshed?.serverVerificationData.trim() ?? '';
        final purchaseVerification = purchase
            .verificationData
            .serverVerificationData
            .trim();
        // StoreKit 1 exposes the base64 app receipt through local verification
        // data. Keep it as a final fallback for devices where the refreshed
        // receipt has not populated the server field yet.
        final localVerification = purchase
            .verificationData
            .localVerificationData
            .trim();
        // The current backend uses Apple's verifyReceipt endpoint, which
        // expects the base64 app receipt. StoreKit 2 may expose a JWS in
        // serverVerificationData instead; never send that JWS to the legacy
        // endpoint (Apple returns status 21002). Prefer the non-JWS receipt
        // candidate and retain JWS only as a final compatibility fallback.
        final candidates = <String>[
          localVerification,
          refreshedVerification,
          purchaseVerification,
        ];
        receipt = candidates.firstWhere(
          (value) => value.trim().isNotEmpty && !_looksLikeJws(value),
          orElse: () => candidates.firstWhere(
            (value) => value.trim().isNotEmpty,
            orElse: () => '',
          ),
        );
        if (purchase is AppStorePurchaseDetails) {
          originalTransactionId = purchase
              .skPaymentTransaction
              .originalTransaction
              ?.transactionIdentifier;
        }
        // StoreKit 2 exposes the current transaction ID through purchaseID;
        // the backend derives the subscription's original ID from the
        // verified receipt when StoreKit does not expose one locally.
        // A receipt can be empty immediately after a StoreKit transaction
        // (especially on a fresh install). Refresh it before asking the
        // backend to verify, otherwise Apple may have charged the user while
        // our entitlement remains pending.
        if (receipt.trim().isEmpty) {
          throw StateError(
            'Apple could not provide a purchase receipt. Tap Restore Purchases and try again.',
          );
        }
      } else if (Platform.isAndroid) {
        final googleDetails = purchase as GooglePlayPurchaseDetails;
        purchaseToken = googleDetails.verificationData.serverVerificationData;
      }

      final newStatus = await _apiService.verifyPurchase(
        provider: provider,
        productId: purchase.productID,
        // StoreKit can expose the transaction identifier through the native
        // transaction object while purchaseID is still null during the first
        // purchase update. Always send a usable identifier to the backend.
        transactionId: purchase.purchaseID ?? originalTransactionId ?? '',
        originalTransactionId: originalTransactionId,
        receipt: receipt,
        purchaseToken: purchaseToken,
      );

      _status = newStatus;
      _verificationGeneration++;
      _error = null;
      debugPrint(
        'IAP: backend entitlement provider=$provider '
        'isPlus=${newStatus.isPlus} status=${newStatus.status.name}',
      );
      _pendingVerifications.remove(key);
      return true;
    } catch (e) {
      _error = "Verification failed: $e";
      debugPrint('IAP: backend verification failed: $e');
      // Keep the successful App Store transaction available for Restore
      // Purchases/retry. Do not acknowledge it until our backend has granted
      // the entitlement, otherwise the user can be charged with no Plus.
      _pendingVerifications[key] = purchase;
      return false;
    } finally {
      _verificationInFlight.remove(key);
      _isVerifying = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _looksLikeJws(String value) {
    final trimmed = value.trim();
    return trimmed.split('.').length == 3 && trimmed.startsWith('eyJ');
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _MockProductDetails implements ProductDetails {
  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final String price;
  @override
  final double rawPrice;
  @override
  final String currencyCode;
  @override
  final String currencySymbol = '\$';

  _MockProductDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
  });
}

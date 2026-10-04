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
  String? _error;

  PlusStatus get status => _status;
  List<ProductDetails> get products => _products;
  bool get isStoreAvailable => _isStoreAvailable;
  bool get isLoading => _isLoading;
  bool get isVerifying => _isVerifying;
  String? get error => _error;

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

  Future<void> restorePurchases() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
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
    _isVerifying = true;
    notifyListeners();

    try {
      String provider = Platform.isIOS ? 'apple' : 'google';
      String? receipt;
      String? purchaseToken;
      String? originalTransactionId;

      if (Platform.isIOS) {
        final skDetails = purchase as AppStorePurchaseDetails;
        receipt = skDetails.verificationData.serverVerificationData;
        originalTransactionId =
            skDetails.skPaymentTransaction.transactionIdentifier;
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
      _error = null;
      return true;
    } catch (e) {
      _error = "Verification failed: $e";
      return false;
    } finally {
      _isVerifying = false;
      _isLoading = false;
      notifyListeners();
    }
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IapProvider extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  final List<ProductDetails> _products = [];
  final List<PurchaseDetails> _purchases = [];
  bool _isAvailable = false;
  bool _isLoading = true;
  String? _error;

  List<ProductDetails> get products => _products;
  List<PurchaseDetails> get purchases => _purchases;
  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  String? get error => _error;

  IapProvider() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: _onSubscriptionDone,
      onError: _onSubscriptionError,
    );
    initialize();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isAvailable = await _iap.isAvailable();
    if (_isAvailable) {
      await _loadProducts();
    } else {
      _error = "Store not available";
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    const Set<String> kIds = {'griot_plus_lifetime'}; // Replace with actual IDs
    final ProductDetailsResponse response = await _iap.queryProductDetails(kIds);

    if (response.error != null) {
      _error = response.error?.message;
      return;
    }

    _products.clear();
    _products.addAll(response.productDetails);
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      if (product.id == 'griot_plus_lifetime') {
         await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
         await _iap.buyConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    _purchases.addAll(purchaseDetailsList);

    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        _completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        _error = purchase.error?.message;
      }
      
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  void _completePurchase(PurchaseDetails purchase) {
    // Logic to update user status to "PLUS"
  }

  void _onSubscriptionDone() {
    _subscription.cancel();
  }

  void _onSubscriptionError(dynamic error) {
    _error = error.toString();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';

class NavigationScrollService extends ChangeNotifier {
  static final NavigationScrollService instance =
      NavigationScrollService._internal();
  NavigationScrollService._internal();

  int? _tappedIndex;
  int? get tappedIndex => _tappedIndex;
  int _scrollNonce = 0;
  int get scrollNonce => _scrollNonce;
  int _refreshNonce = 0;
  int get refreshNonce => _refreshNonce;
  bool _navigationVisible = true;
  bool get navigationVisible => _navigationVisible;

  void setNavigationVisible(bool visible) {
    if (_navigationVisible == visible) return;
    _navigationVisible = visible;
    notifyListeners();
  }

  void scrollToTop(int index) {
    _tappedIndex = index;
    _scrollNonce++;
    notifyListeners();
    // We don't null it out here because we want listeners to see which index was tapped.
    // Listeners should check if the index matches theirs.
  }

  /// Requests a fresh load for a navigation branch, typically after the user
  /// double-taps its active bottom-navigation item.
  void refreshBranch(int index) {
    _tappedIndex = index;
    _refreshNonce++;
    notifyListeners();
  }

  /// Emits one coherent return-to-top and refresh event so listeners do not
  /// animate or reload twice for a single double tap.
  void refreshAndScrollToTop(int index) {
    _tappedIndex = index;
    _scrollNonce++;
    _refreshNonce++;
    notifyListeners();
  }
}

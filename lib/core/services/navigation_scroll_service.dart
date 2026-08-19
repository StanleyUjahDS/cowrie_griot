import 'package:flutter/material.dart';

class NavigationScrollService extends ChangeNotifier {
  static final NavigationScrollService instance = NavigationScrollService._internal();
  NavigationScrollService._internal();

  int? _tappedIndex;
  int? get tappedIndex => _tappedIndex;

  void scrollToTop(int index) {
    _tappedIndex = index;
    notifyListeners();
    // We don't null it out here because we want listeners to see which index was tapped.
    // Listeners should check if the index matches theirs.
  }
}

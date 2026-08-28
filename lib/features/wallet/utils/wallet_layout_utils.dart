import 'package:flutter/material.dart';

class RaisedEndFloatLocation extends FloatingActionButtonLocation {
  final double bottomDistance;
  final double rightDistance;

  const RaisedEndFloatLocation({
    this.bottomDistance = 110,
    this.rightDistance = 16,
  });

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double x = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        rightDistance;
    final double y = scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        bottomDistance;
    return Offset(x, y);
  }
}

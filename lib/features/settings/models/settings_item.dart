import 'package:flutter/material.dart';

class SettingsItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
}
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../../core/ui/widgets/griot_loader.dart';
import '../../../../../core/services/notification_service.dart';

class UsernameEditSheet extends StatefulWidget {
  final String initialValue;
  final Future<void> Function(String username) onSave;
  final Future<bool> Function(String username)? onCheckAvailability;

  const UsernameEditSheet({
    super.key,
    required this.initialValue,
    required this.onSave,
    this.onCheckAvailability,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String initialValue,
    required Future<void> Function(String username) onSave,
    Future<bool> Function(String username)? onCheckAvailability,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      enableDrag: true,
      isDismissible: true,
      builder: (_) {
        return UsernameEditSheet(
          initialValue: initialValue,
          onSave: onSave,
          onCheckAvailability: onCheckAvailability,
        );
      },
    );
  }

  @override
  State<UsernameEditSheet> createState() =>
      _UsernameEditSheetState();
}

class _UsernameEditSheetState
    extends State<UsernameEditSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  Timer? _availabilityTimer;

  bool _isSaving = false;

  final ValueNotifier<bool> _isCheckingAvailability =
  ValueNotifier<bool>(false);

  final ValueNotifier<bool?> _isUsernameAvailable =
  ValueNotifier<bool?>(null);

  String _lastCheckedUsername = '';

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.initialValue,
    );

    _focusNode = FocusNode();

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _availabilityTimer?.cancel();

    _controller.removeListener(_onTextChanged);

    _controller.dispose();
    _focusNode.dispose();

    _isCheckingAvailability.dispose();
    _isUsernameAvailable.dispose();

    super.dispose();
  }

  // ============================================================
  // TEXT CHANGED
  // ============================================================

  void _onTextChanged() {
    final username =
    _controller.text.trim().toLowerCase();

    _availabilityTimer?.cancel();

    if (username == _lastCheckedUsername) {
      return;
    }

    _isUsernameAvailable.value = null;
    _isCheckingAvailability.value = false;

    if (!_isLocallyValidUsername(username)) {
      return;
    }

    final initialUsername =
    widget.initialValue.trim().toLowerCase();

    if (username == initialUsername) {
      _isUsernameAvailable.value = true;
      return;
    }

    if (widget.onCheckAvailability == null) {
      return;
    }

    _availabilityTimer = Timer(
      const Duration(milliseconds: 550),
          () => _checkAvailability(username),
    );
  }

  // ============================================================
  // LOCAL VALIDATION
  // ============================================================

  bool _isLocallyValidUsername(
      String username,
      ) {
    if (username.length < 3) {
      return false;
    }

    if (username.length > 30) {
      return false;
    }

    return RegExp(
      r'^[a-zA-Z0-9_]+$',
    ).hasMatch(username);
  }

  // ============================================================
  // CHECK AVAILABILITY
  // ============================================================

  Future<void> _checkAvailability(
      String username,
      ) async {
    if (!mounted) {
      return;
    }

    final checker =
        widget.onCheckAvailability;

    if (checker == null) {
      return;
    }

    if (!_isLocallyValidUsername(username)) {
      return;
    }

    final initialUsername =
    widget.initialValue.trim().toLowerCase();

    if (username == initialUsername) {
      _isCheckingAvailability.value = false;
      _isUsernameAvailable.value = true;
      return;
    }

    _isCheckingAvailability.value = true;
    _isUsernameAvailable.value = null;

    try {
      final available = await checker(username);

      if (!mounted) {
        return;
      }

      final currentUsername =
      _controller.text.trim().toLowerCase();

      if (currentUsername != username) {
        return;
      }

      _lastCheckedUsername = username;

      _isCheckingAvailability.value = false;
      _isUsernameAvailable.value = available;
    } catch (_) {
      if (!mounted) {
        return;
      }

      final currentUsername =
      _controller.text.trim().toLowerCase();

      if (currentUsername != username) {
        return;
      }

      _isCheckingAvailability.value = false;
      _isUsernameAvailable.value = null;
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _save() async {
    if (_isSaving ||
        _isCheckingAvailability.value) {
      return;
    }

    FocusScope.of(context).unfocus();

    final username =
    _controller.text.trim().toLowerCase();

    if (username.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    if (!_isLocallyValidUsername(username)) {
      _showMessage(
        context,
        'Username must be 3–30 characters and use only letters, numbers and underscores.',
      );
      return;
    }

    final initialUsername =
    widget.initialValue.trim().toLowerCase();

    if (username == initialUsername) {
      Navigator.of(context).pop(false);
      return;
    }

    if (widget.onCheckAvailability != null &&
        _isUsernameAvailable.value != true) {
      _showMessage(
        context,
        'Please choose an available username.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(username);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        context,
        _cleanError(error),
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      BuildContext context,
      String message,
      ) {
    NotificationService.showError(context, message);
  }

  String _cleanError(
      Object error,
      ) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }

  // ============================================================
  // AVAILABILITY STATUS
  // ============================================================

  Widget _availabilityStatus(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: _isCheckingAvailability,
      builder: (
          context,
          isChecking,
          _,
          ) {
        return ValueListenableBuilder<bool?>(
          valueListenable: _isUsernameAvailable,
          builder: (
              context,
              available,
              _,
              ) {
            if (isChecking) {
              return Padding(
                padding: const EdgeInsets.only(
                  top: 10,
                  left: 4,
                ),
                child: Row(
                  children: [
                    const GriotLoader(
                      size: 15,
                      strokeWidth: 1.8,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Checking username...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                        colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (available == true) {
              return Padding(
                padding: const EdgeInsets.only(
                  top: 10,
                  left: 4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Username is available',
                      style:
                      theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (available == false) {
              return Padding(
                padding: const EdgeInsets.only(
                  top: 10,
                  left: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Username is already taken',
                      style:
                      theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox(
              height: 0,
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: bottomInset,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              12,
              0,
              12,
              12,
            ),
            padding: const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              22,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius:
              BorderRadius.circular(30),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 35,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.25),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary
                                .withValues(alpha: 0.16),
                            colorScheme.primary
                                .withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius:
                        BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.alternate_email_rounded,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Username',
                            style: theme
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose a unique Griot username (min. 3 characters)',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLength: 30,
                  textInputAction:
                  TextInputAction.done,
                  textCapitalization:
                  TextCapitalization.none,
                  keyboardType:
                  TextInputType.text,
                  onSubmitted: (_) => _save(),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText:
                    'Enter your username (min. 3 characters)',
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                    ),
                    filled: true,
                    fillColor:
                    colorScheme.onSurface
                        .withValues(alpha: 0.035),
                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 17,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(18),
                    ),
                    enabledBorder:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: colorScheme.outline
                            .withValues(alpha: 0.12),
                      ),
                    ),
                    focusedBorder:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color:
                        colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                // Only this small area changes when
                // availability is checked.
                _availabilityStatus(context),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed:
                    _isSaving ||
                        _isCheckingAvailability
                            .value
                        ? null
                        : _save,
                    style: FilledButton.styleFrom(
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(17),
                      ),
                    ),
                    child: _isSaving
                        ? const GriotLoader(
                            size: 22,
                            strokeWidth: 2.4,
                            color: Colors.white,
                          )
                        : const Text(
                      'Save Username',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                    Navigator.of(context)
                        .pop(false);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: colorScheme
                          .onSurfaceVariant,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
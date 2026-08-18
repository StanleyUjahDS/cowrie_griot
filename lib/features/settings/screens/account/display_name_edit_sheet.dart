// lib/features/settings/screens/account/display_name_edit_sheet.dart

import 'package:flutter/material.dart';

class DisplayNameEditSheet extends StatefulWidget {
  final String initialValue;
  final Future<void> Function(String value) onSave;

  /// Maximum characters allowed for the display name.
  final int maxLength;

  const DisplayNameEditSheet({
    super.key,
    required this.initialValue,
    required this.onSave,
    this.maxLength = 50,
  });

  // ============================================================
  // SHOW
  // ============================================================

  static Future<bool?> show({
    required BuildContext context,
    required String initialValue,
    required Future<void> Function(String value) onSave,
    int maxLength = 50,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      enableDrag: true,
      isDismissible: true,
      builder: (_) {
        return DisplayNameEditSheet(
          initialValue: initialValue,
          onSave: onSave,
          maxLength: maxLength,
        );
      },
    );
  }

  @override
  State<DisplayNameEditSheet> createState() =>
      _DisplayNameEditSheetState();
}

class _DisplayNameEditSheetState
    extends State<DisplayNameEditSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  bool _isSaving = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.initialValue,
    );

    _focusNode = FocusNode();

    _controller.addListener(_onTextChanged);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // TEXT CHANGED
  // ============================================================

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String? _validate(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Display name cannot be empty';
    }

    if (text.length > widget.maxLength) {
      return 'Display name must be ${widget.maxLength} characters or less';
    }

    return null;
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final value = _controller.text.trim();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (value == widget.initialValue.trim()) {
      if (mounted) {
        Navigator.of(context).pop(false);
      }

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(value);

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
        _cleanError(error),
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final keyboardInset =
        MediaQuery.of(context).viewInsets.bottom;

    final characterCount =
        _controller.text.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: keyboardInset,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.48,
        maxChildSize: 0.92,
        builder: (
            context,
            scrollController,
            ) {
          return Container(
            margin: const EdgeInsets.fromLTRB(
              10,
              0,
              10,
              10,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius:
              const BorderRadius.vertical(
                top: Radius.circular(30),
                bottom: Radius.circular(30),
              ),
              border: Border.all(
                color: colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.20,
                  ),
                  blurRadius: 35,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                // ==================================================
                // HANDLE
                // ==================================================

                Padding(
                  padding: const EdgeInsets.only(
                    top: 12,
                  ),
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme
                          .onSurfaceVariant
                          .withValues(
                        alpha: 0.25,
                      ),
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                  ),
                ),

                // ==================================================
                // CONTENT
                // ==================================================

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                    padding:
                    const EdgeInsets.fromLTRB(
                      18,
                      18,
                      18,
                      30,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                        children: [
                          // ==================================================
                          // HEADER
                          // ==================================================

                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration:
                                BoxDecoration(
                                  gradient:
                                  LinearGradient(
                                    begin:
                                    Alignment.topLeft,
                                    end: Alignment
                                        .bottomRight,
                                    colors: [
                                      colorScheme
                                          .primary
                                          .withValues(
                                        alpha: 0.16,
                                      ),
                                      colorScheme
                                          .primary
                                          .withValues(
                                        alpha: 0.06,
                                      ),
                                    ],
                                  ),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    16,
                                  ),
                                ),
                                child: Icon(
                                  Icons
                                      .badge_outlined,
                                  color:
                                  colorScheme
                                      .primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(
                                width: 13,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                                  children: [
                                    Text(
                                      'Display Name',
                                      style: theme
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                        fontWeight:
                                        FontWeight
                                            .w800,
                                        letterSpacing:
                                        -0.2,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                      'This is the name people will see on your profile',
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

                          const SizedBox(
                            height: 26,
                          ),

                          // ==================================================
                          // LABEL
                          // ==================================================

                          Text(
                            'Your display name',
                            style: theme
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),

                          const SizedBox(
                            height: 9,
                          ),

                          // ==================================================
                          // INPUT
                          // ==================================================

                          TextFormField(
                            controller:
                            _controller,
                            focusNode:
                            _focusNode,
                            autofocus: true,
                            minLines: 1,
                            maxLines: 2,
                            maxLength:
                            widget.maxLength,
                            textInputAction:
                            TextInputAction.done,
                            onFieldSubmitted:
                                (_) => _save(),
                            textCapitalization:
                            TextCapitalization
                                .words,
                            keyboardType:
                            TextInputType
                                .name,
                            validator:
                            _validate,
                            style: theme
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w600,
                            ),
                            decoration:
                            InputDecoration(
                              hintText:
                              'Enter your display name',
                              hintStyle: theme
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                color: colorScheme
                                    .onSurfaceVariant
                                    .withValues(
                                  alpha: 0.55,
                                ),
                              ),
                              counterText:
                              '$characterCount/${widget.maxLength}',
                              counterStyle: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: characterCount >
                                    widget.maxLength
                                    ? colorScheme
                                    .error
                                    : colorScheme
                                    .onSurfaceVariant,
                                fontWeight:
                                FontWeight.w500,
                              ),
                              filled: true,
                              fillColor: colorScheme
                                  .onSurface
                                  .withValues(
                                alpha: 0.035,
                              ),
                              prefixIcon: const Icon(
                                Icons
                                    .person_outline_rounded,
                              ),
                              contentPadding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 17,
                                vertical: 18,
                              ),
                              border:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  20,
                                ),
                                borderSide:
                                BorderSide(
                                  color: colorScheme
                                      .outline
                                      .withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              enabledBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  20,
                                ),
                                borderSide:
                                BorderSide(
                                  color: colorScheme
                                      .outline
                                      .withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              focusedBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  20,
                                ),
                                borderSide:
                                BorderSide(
                                  color: colorScheme
                                      .primary,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  20,
                                ),
                                borderSide:
                                BorderSide(
                                  color: colorScheme
                                      .error
                                      .withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                              focusedErrorBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  20,
                                ),
                                borderSide:
                                BorderSide(
                                  color: colorScheme
                                      .error,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // HELPER
                          // ==================================================

                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration:
                            BoxDecoration(
                              color: colorScheme
                                  .primary
                                  .withValues(
                                alpha: 0.055,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                14,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Icon(
                                  Icons
                                      .info_outline_rounded,
                                  size: 18,
                                  color:
                                  colorScheme
                                      .primary,
                                ),
                                const SizedBox(
                                  width: 9,
                                ),
                                Expanded(
                                  child: Text(
                                    'Your display name can be changed at any time. Your Griot username remains your unique identity.',
                                    style: theme
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      height: 1.4,
                                      color: colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                            height: 24,
                          ),

                          // ==================================================
                          // SAVE
                          // ==================================================

                          SizedBox(
                            width:
                            double.infinity,
                            height: 56,
                            child: FilledButton(
                              onPressed:
                              _isSaving
                                  ? null
                                  : _save,
                              style: FilledButton
                                  .styleFrom(
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    18,
                                  ),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth:
                                  2.4,
                                ),
                              )
                                  : const Text(
                                'Save Display Name',
                                style:
                                TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          // ==================================================
                          // CANCEL
                          // ==================================================

                          TextButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                              Navigator.of(
                                context,
                              ).pop(false);
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
              ],
            ),
          );
        },
      ),
    );
  }
}
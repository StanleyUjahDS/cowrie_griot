import 'package:flutter/material.dart';
import '../../../../../core/ui/widgets/griot_loader.dart';

class BioEditSheet extends StatefulWidget {
  final String initialValue;
  final Future<void> Function(String bio) onSave;
  final int maxLength;

  const BioEditSheet({
    super.key,
    required this.initialValue,
    required this.onSave,
    this.maxLength = 160,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String initialValue,
    required Future<void> Function(String bio) onSave,
    int maxLength = 160,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) {
        return BioEditSheet(
          initialValue: initialValue,
          onSave: onSave,
          maxLength: maxLength,
        );
      },
    );
  }

  @override
  State<BioEditSheet> createState() =>
      _BioEditSheetState();
}

class _BioEditSheetState extends State<BioEditSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  bool _isSaving = false;

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
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final value = _controller.text.trim();

    if (value.length > widget.maxLength) {
      _showMessage(
        'Bio must be ${widget.maxLength} characters or less.',
      );
      return;
    }

    if (value == widget.initialValue.trim()) {
      Navigator.of(context).pop(false);
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

      _showMessage(_cleanError(error));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    final remaining =
        widget.maxLength - _controller.text.length;

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
              borderRadius: BorderRadius.circular(30),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant
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
                            colorScheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            colorScheme.primary.withValues(
                              alpha: 0.06,
                            ),
                          ],
                        ),
                        borderRadius:
                        BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
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
                            'Bio',
                            style: theme
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Tell people a little about yourself',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color:
                              colorScheme.onSurfaceVariant,
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
                  maxLength: widget.maxLength,
                  maxLines: 7,
                  minLines: 7,
                  textInputAction: TextInputAction.newline,
                  textCapitalization:
                  TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  style:
                  theme.textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText:
                    'Write something about yourself...',
                    hintStyle:
                    theme.textTheme.bodyLarge?.copyWith(
                      color:
                      colorScheme.onSurfaceVariant
                          .withValues(
                        alpha: 0.55,
                      ),
                    ),
                    filled: true,
                    fillColor:
                    colorScheme.onSurface.withValues(
                      alpha: 0.035,
                    ),
                    alignLabelWithHint: true,
                    contentPadding:
                    const EdgeInsets.all(17),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                    enabledBorder:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color:
                        colorScheme.outline.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                    focusedBorder:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$remaining characters remaining',
                    style:
                    theme.textTheme.bodySmall?.copyWith(
                      color: remaining < 20
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed:
                    _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
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
                      'Save Bio',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color:
                      colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
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
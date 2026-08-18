import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '/core/ui/scaffolds/gradient_scaffold.dart';

// ============================================================
// TYPES
// ============================================================

typedef LoadingOperation = Future<Object?> Function();

typedef LoadingSuccess = void Function(
    BuildContext context,
    Object? result,
    );

// ============================================================
// APP LOADING ROUTE DATA
// ============================================================
//
// Generic loading configuration.
//
// The caller decides:
// - title
// - message
// - icon
// - operation
// - success behaviour
//
// No business-specific assumptions are made here.
// ============================================================

class AppLoadingRouteData {
  final String message;
  final String? title;

  /// Icon representing the operation currently being performed.
  final IconData icon;

  /// Size of the main operation icon.
  final double iconSize;

  /// Text displayed after successful completion.
  final String successTitle;

  /// Async operation to execute.
  final LoadingOperation operation;

  /// Called after the operation succeeds.
  final LoadingSuccess onSuccess;

  const AppLoadingRouteData({
    required this.message,
    required this.icon,
    required this.operation,
    required this.onSuccess,
    this.title,
    this.iconSize = 58,
    this.successTitle = 'Ready',
  });
}

// ============================================================
// APP LOADING SCREEN
// ============================================================

class AppLoadingScreen extends StatefulWidget {
  final String message;
  final String? title;

  final IconData icon;
  final double iconSize;

  final String successTitle;

  final LoadingOperation operation;
  final LoadingSuccess onSuccess;

  const AppLoadingScreen({
    super.key,
    required this.message,
    required this.icon,
    required this.operation,
    required this.onSuccess,
    this.title,
    this.iconSize = 58,
    this.successTitle = 'Ready',
  });

  @override
  State<AppLoadingScreen> createState() =>
      _AppLoadingScreenState();
}

// ============================================================
// STATE
// ============================================================

class _AppLoadingScreenState
    extends State<AppLoadingScreen> {
  bool _isComplete = false;

  Object? _error;

  StackTrace? _stackTrace;

  bool _hasStarted = false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOperation();
    });
  }

  // ==========================================================
  // RUN OPERATION
  // ==========================================================

  Future<void> _startOperation() async {
    if (_hasStarted) {
      return;
    }

    _hasStarted = true;

    try {
      final Object? result =
      await widget.operation();

      if (!mounted) {
        return;
      }

      // ------------------------------------------------------
      // SUCCESS STATE
      // ------------------------------------------------------

      setState(() {
        _isComplete = true;
      });

      // Give the user a short moment to see "Ready".
      await Future<void>.delayed(
        const Duration(
          milliseconds: 600,
        ),
      );

      if (!mounted) {
        return;
      }

      // ------------------------------------------------------
      // CALLER DECIDES WHERE TO GO
      // ------------------------------------------------------

      widget.onSuccess(
        context,
        result,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'AppLoadingScreen operation failed: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  // ==========================================================
  // RETRY
  // ==========================================================

  Future<void> _retry() async {
    if (_hasStarted) {
      return;
    }

    setState(() {
      _error = null;
      _stackTrace = null;
      _isComplete = false;
      _hasStarted = false;
    });

    await _startOperation();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Column(
                children: [
                  const Spacer(),

                  // ==================================================
                  // MAIN OPERATION VISUAL
                  // ==================================================

                  _buildAnimation(context),

                  const SizedBox(
                    height: 28,
                  ),

                  // ==================================================
                  // BRAND
                  // ==================================================

                  Text(
                    'Griot',
                    style:
                    textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  )
                      .animate()
                      .fadeIn(
                    duration: 700.ms,
                  )
                      .slideY(
                    begin: 0.15,
                    end: 0,
                    duration: 700.ms,
                    curve: Curves.easeOut,
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    'By Cowrie',
                    style:
                    textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                      .animate()
                      .fadeIn(
                    delay: 150.ms,
                    duration: 700.ms,
                  ),

                  const Spacer(),

                  // ==================================================
                  // STATUS
                  // ==================================================

                  AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 400,
                    ),
                    transitionBuilder:
                        (
                        child,
                        animation,
                        ) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.92,
                            end: 1,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve:
                              Curves.easeOutBack,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: _buildStatus(context),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // ==================================================
                  // SECURITY MESSAGE
                  // ==================================================

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: colorScheme.onSurface
                            .withValues(
                          alpha: 0.40,
                        ),
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      Text(
                        _error != null
                            ? 'Something went wrong'
                            : 'Please keep this screen open',
                        style:
                        textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface
                              .withValues(
                            alpha: 0.40,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // MAIN ANIMATION
  // ==========================================================

  Widget _buildAnimation(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ==================================================
          // OUTER GLOW
          // ==================================================

          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary
                      .withValues(
                    alpha: 0.18,
                  ),
                  blurRadius: 70,
                  spreadRadius: 15,
                ),
              ],
            ),
          )
              .animate(
            onPlay: (controller) {
              controller.repeat(
                reverse: true,
              );
            },
          )
              .scale(
            begin: const Offset(
              0.85,
              0.85,
            ),
            end: const Offset(
              1.15,
              1.15,
            ),
            duration: 1800.ms,
            curve: Curves.easeInOut,
          )
              .fade(
            begin: 0.45,
            end: 1,
            duration: 1800.ms,
          ),

          // ==================================================
          // OUTER RING
          // ==================================================

          Container(
            width: 122,
            height: 122,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary
                  .withValues(
                alpha: 0.07,
              ),
              border: Border.all(
                color: colorScheme.primary
                    .withValues(
                  alpha: 0.18,
                ),
                width: 1.5,
              ),
            ),
          )
              .animate(
            onPlay: (controller) {
              controller.repeat(
                reverse: true,
              );
            },
          )
              .scale(
            begin: const Offset(
              0.94,
              0.94,
            ),
            end: const Offset(
              1.06,
              1.06,
            ),
            duration: 1600.ms,
            curve: Curves.easeInOut,
          ),

          // ==================================================
          // MAIN ICON
          // ==================================================

          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary
                      .withValues(
                    alpha: 0.30,
                  ),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: colorScheme.onPrimary,
            ),
          )
              .animate()
              .fadeIn(
            duration: 500.ms,
          )
              .scale(
            begin: const Offset(
              0.70,
              0.70,
            ),
            end: const Offset(
              1,
              1,
            ),
            duration: 700.ms,
            curve: Curves.easeOutBack,
          )
              .then()
              .shimmer(
            duration: 1800.ms,
            color: colorScheme.onPrimary
                .withValues(
              alpha: 0.25,
            ),
          ),

          // ==================================================
          // ORBIT DOT
          // ==================================================

          Positioned(
            top: 34,
            right: 53,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary
                        .withValues(
                      alpha: 0.50,
                    ),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          )
              .animate(
            onPlay: (controller) {
              controller.repeat();
            },
          )
              .rotate(
            duration: 2600.ms,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS
  // ==========================================================

  Widget _buildStatus(
      BuildContext context,
      ) {
    if (_error != null) {
      return _buildError(context);
    }

    if (_isComplete) {
      return _buildSuccess(context);
    }

    return _buildLoading(context);
  }

  // ==========================================================
  // LOADING
  // ==========================================================

  Widget _buildLoading(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey(
        'loading',
      ),
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colorScheme.primary,
          ),
        )
            .animate(
          onPlay: (controller) {
            controller.repeat();
          },
        )
            .rotate(
          duration: 1200.ms,
        ),

        const SizedBox(
          height: 22,
        ),

        // ==================================================
        // TITLE
        // ==================================================

        if (widget.title != null) ...[
          Text(
            widget.title!,
            textAlign: TextAlign.center,
            style:
            textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          )
              .animate()
              .fadeIn(
            duration: 500.ms,
          ),

          const SizedBox(
            height: 8,
          ),
        ],

        // ==================================================
        // MESSAGE
        // ==================================================

        Text(
          widget.message,
          textAlign: TextAlign.center,
          style:
          textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface
                .withValues(
              alpha: 0.65,
            ),
            height: 1.45,
          ),
        )
            .animate()
            .fadeIn(
          duration: 500.ms,
        )
            .slideY(
          begin: 0.12,
          end: 0,
          duration: 500.ms,
          curve: Curves.easeOut,
        ),
      ],
    );
  }

  // ==========================================================
  // SUCCESS
  // ==========================================================

  Widget _buildSuccess(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey(
        'success',
      ),
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: colorScheme.primary
                .withValues(
              alpha: 0.12,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 34,
            color: colorScheme.primary,
          ),
        )
            .animate()
            .scale(
          begin: const Offset(
            0.4,
            0.4,
          ),
          end: const Offset(
            1,
            1,
          ),
          duration: 500.ms,
          curve: Curves.easeOutBack,
        )
            .fadeIn(),

        const SizedBox(
          height: 16,
        ),

        Text(
          widget.successTitle,
          style:
          textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        )
            .animate()
            .fadeIn(
          delay: 100.ms,
        ),
      ],
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  Widget _buildError(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey(
        'error',
      ),
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: colorScheme.error,
        )
            .animate()
            .shake(
          duration: 600.ms,
        ),

        const SizedBox(
          height: 14,
        ),

        Text(
          'Unable to continue',
          style:
          textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        Text(
          'Something went wrong while '
              'preparing your request.',
          textAlign: TextAlign.center,
          style:
          textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface
                .withValues(
              alpha: 0.65,
            ),
          ),
        ),

        const SizedBox(
          height: 18,
        ),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _retry,
            child: const Text(
              'Try Again',
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
      duration: 500.ms,
    )
        .slideY(
      begin: 0.12,
      end: 0,
    );
  }
}
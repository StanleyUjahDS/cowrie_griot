import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isPopping = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_isPopping) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;

      if (value != null && value.isNotEmpty) {
        _isPopping = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR'),
        actions: [
          IconButton(
            iconSize: 32,
            onPressed: controller.toggleTorch,
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(
                      Icons.flash_on,
                      color: Colors.yellow,
                    );

                  case TorchState.off:
                    return const Icon(
                      Icons.flash_off,
                      color: Colors.grey,
                    );

                  case TorchState.unavailable:
                    return const Icon(
                      Icons.flash_off,
                      color: Colors.red,
                    );

                  case TorchState.auto:
                    return const Icon(
                      Icons.flash_auto,
                      color: Colors.white,
                    );
                }
              },
            ),
          ),
          IconButton(
            iconSize: 32,
            onPressed: controller.switchCamera,
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);

                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);

                  case CameraFacing.external:
                    return const Icon(Icons.camera);

                  case CameraFacing.unknown:
                    return const Icon(Icons.camera_alt);
                }
              },
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _handleDetection,
            errorBuilder: (context, error) {
              final isPermissionDenied =
                  error.errorCode ==
                      MobileScannerErrorCode.permissionDenied;

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Error',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        isPermissionDenied
                            ? 'Camera permission denied. Please enable it in settings.'
                            : 'Could not start camera. Please try again.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (isPermissionDenied) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: ScannerOverlayPainter(
                borderColor: theme.colorScheme.primary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;

  const ScannerOverlayPainter({
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final rect = Offset.zero & size;

    final scanRectSize = size.width * 0.7;

    final scanRect = Rect.fromCenter(
      center: Offset(
        size.width / 2,
        size.height / 2,
      ),
      width: scanRectSize,
      height: scanRectSize,
    );

    final backgroundPath = Path()..addRect(rect);
    final scanPath = Path()..addRect(scanRect);

    final cutoutPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scanPath,
    );

    canvas.drawPath(
      cutoutPath,
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.square;

    const cornerLength = 40.0;

    final path = Path();

    // Top left.
    path
      ..moveTo(
        scanRect.left,
        scanRect.top + cornerLength,
      )
      ..lineTo(
        scanRect.left,
        scanRect.top,
      )
      ..lineTo(
        scanRect.left + cornerLength,
        scanRect.top,
      );

    // Top right.
    path
      ..moveTo(
        scanRect.right - cornerLength,
        scanRect.top,
      )
      ..lineTo(
        scanRect.right,
        scanRect.top,
      )
      ..lineTo(
        scanRect.right,
        scanRect.top + cornerLength,
      );

    // Bottom right.
    path
      ..moveTo(
        scanRect.right,
        scanRect.bottom - cornerLength,
      )
      ..lineTo(
        scanRect.right,
        scanRect.bottom,
      )
      ..lineTo(
        scanRect.right - cornerLength,
        scanRect.bottom,
      );

    // Bottom left.
    path
      ..moveTo(
        scanRect.left + cornerLength,
        scanRect.bottom,
      )
      ..lineTo(
        scanRect.left,
        scanRect.bottom,
      )
      ..lineTo(
        scanRect.left,
        scanRect.bottom - cornerLength,
      );

    canvas.drawPath(
      path,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(
      covariant ScannerOverlayPainter oldDelegate,
      ) {
    return oldDelegate.borderColor != borderColor;
  }
}
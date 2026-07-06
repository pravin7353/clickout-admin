import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class PosScannerDialog extends StatefulWidget {
  final Function(String) onScan;

  const PosScannerDialog({super.key, required this.onScan});

  @override
  State<PosScannerDialog> createState() => _PosScannerDialogState();
}

class _PosScannerDialogState extends State<PosScannerDialog> {
  // 🚀 FIX: Removed 'facing' property. Laptop webcams crash if forced to look for "front/back". Default auto-detects laptop camera instantly.
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 450,
        height: 500,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: context.colors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Stack(
          children: [
            // 📷 THE CAMERA FEED
            MobileScanner(
              controller: _controller,
              onDetect: (capture) async {
                if (_isProcessing) return;
                final List<Barcode> barcodes = capture.barcodes;

                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    setState(() => _isProcessing = true);

                    // Trigger the function in Cashier Screen
                    await widget.onScan(barcode.rawValue!);

                    // Wait a second before allowing the next scan
                    await Future.delayed(const Duration(seconds: 1));
                    if (mounted) setState(() => _isProcessing = false);
                    break;
                  }
                }
              },
            ),

            // 🎯 SCANNER TARGET BOX (UI)
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.black54,
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 150,
                      width: 250,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Container(
                height: 150,
                width: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // ❌ CLOSE BUTTON
            Positioned(
              top: 15,
              right: 15,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // ⚙️ LOADING INDICATOR
            if (_isProcessing)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.greenAccent,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Adding item...",
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

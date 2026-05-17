import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:html' as html; // 🚀 WEBSAFE DOWNLOAD ENGINE
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // 🚀 FOR REPAINT BOUNDARY
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/auth_provider.dart';
import '../../../core/store/providers/store_provider.dart';

class StoreEntryQRCard extends ConsumerStatefulWidget {
  const StoreEntryQRCard({super.key});

  @override
  ConsumerState<StoreEntryQRCard> createState() => _StoreEntryQRCardState();
}

class _StoreEntryQRCardState extends ConsumerState<StoreEntryQRCard> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isDownloading = false;
  Future<String>?
  _nameFuture; // 🚀 FIX: Removed 'late' to prevent Hot Reload crash!

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🚀 Safe Initialization: Runs only once, immune to Hot Reloads
    if (_nameFuture == null) {
      final adminData = ref.read(adminRoleProvider).value;
      final activeStore = ref.read(activeStoreProvider);

      final tenantId = adminData?['tenantId'] ?? '';
      final branchCode =
          activeStore?.branchCode ?? adminData?['branchCode'] ?? '';
      final localStoreName =
          activeStore?.storeName ?? adminData?['storeName'] ?? '';

      _nameFuture = _getRealStoreName(tenantId, branchCode, localStoreName);
    }
  }

  Future<String> _getRealStoreName(
    String tenantId,
    String branchCode,
    String localFallback,
  ) async {
    if (localFallback.isNotEmpty && localFallback != 'ClickOut Store') {
      return localFallback;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('tenantId', isEqualTo: tenantId)
          .where('branchCode', isEqualTo: branchCode)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        return data['storeName'] ??
            data['name'] ??
            data['companyName'] ??
            branchCode;
      }
      return branchCode;
    } catch (e) {
      return branchCode;
    }
  }

  Future<void> _downloadQR(String storeName) async {
    setState(() => _isDownloading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 150));

      RenderRepaintBoundary? boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw "Widget boundary not found! Screen refresh issue.";
      }

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      ui.Image image = await boundary.toImage(pixelRatio: 2.0);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();

        final blob = html.Blob([pngBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "ClickOut_QR_$storeName.png")
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ QR Code Downloaded Successfully!"),
              backgroundColor: Color(0xFF00C853),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Download error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🚨 Failed to download: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminData = ref.watch(adminRoleProvider).value;
    final activeStore = ref.watch(activeStoreProvider);

    final tenantId = adminData?['tenantId'] ?? '';
    final branchCode =
        activeStore?.branchCode ?? adminData?['branchCode'] ?? '';

    if (tenantId.isEmpty || branchCode.isEmpty) {
      return Dialog(
        backgroundColor: const Color(0xFF111811),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "🚨 Error: Missing Tenant or Branch Identity.",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return FutureBuilder<String>(
      future: _nameFuture, // 🚀 FIX: Cached future reference used here
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF00C853)),
            ),
          );
        }

        final dynamicStoreName = snapshot.data ?? branchCode;

        // 🔒 SECURITY FIX: Raw JSON
        final String rawJson = jsonEncode({
          "action": "STORE_ENTRY",
          "tenantId": tenantId,
          "branchCode": branchCode,
          "storeName": dynamicStoreName,
          "timestamp": DateTime.now().millisecondsSinceEpoch,
        });

        // 🔒 SECURITY FIX: Base64 Encoding with "CLICKOUT::" prefix!
        final String qrPayload =
            "CLICKOUT::${base64Encode(utf8.encode(rawJson))}";

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 30,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111811),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00C853).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.storefront,
                        color: Color(0xFF00C853),
                        size: 38,
                      ),
                      const SizedBox(height: 10),

                      Text(
                        dynamicStoreName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      Text(
                        "STORE ID: $branchCode",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 30),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: qrPayload,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        "Scan to enter via ClickOut App",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "CLOSE",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _isDownloading
                        ? null
                        : () => _downloadQR(dynamicStoreName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      _isDownloading ? "DOWNLOADING..." : "DOWNLOAD QR",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

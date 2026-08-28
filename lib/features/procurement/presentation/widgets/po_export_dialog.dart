import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/core/theme/app_theme.dart'; // 🚀 Added Theme Support

class PoExportDialog extends StatefulWidget {
  final String supplierName;
  final String supplierEmail;
  final String supplierPhone;
  final String poId;
  final List<dynamic> items;
  final String senderName;
  final VoidCallback onMarkAsRead;

  const PoExportDialog({
    super.key,
    required this.supplierName,
    required this.supplierEmail,
    required this.supplierPhone,
    required this.poId,
    required this.items,
    required this.senderName,
    required this.onMarkAsRead,
  });

  @override
  State<PoExportDialog> createState() => _PoExportDialogState();
}

class _PoExportDialogState extends State<PoExportDialog> {
  bool _isSaving = false;
  bool _isCopied = false;

  String _generateMessage() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("🔔 *URGENT: Purchase Order from ClickOut*");
    buffer.writeln("PO Reference: #${widget.poId}\n");
    buffer.writeln("To: ${widget.supplierName}");
    buffer.writeln(
      "Email: ${widget.supplierEmail.isEmpty ? 'N/A' : widget.supplierEmail}",
    );
    buffer.writeln(
      "Phone: ${widget.supplierPhone.isEmpty ? 'N/A' : widget.supplierPhone}\n",
    );
    buffer.writeln("Hello Team,");
    buffer.writeln(
      "Please process the following requirements at the earliest:\n",
    );

    buffer.writeln("📦 *ORDER DETAILS:*");
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      buffer.writeln("${i + 1}. ${item['name']} ➔ Qty: ${item['orderQty']}");
    }

    buffer.writeln("\nPlease confirm once dispatched.");
    buffer.writeln("Thanks & Regards,\n${widget.senderName}");

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String messageText = _generateMessage();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        decoration: BoxDecoration(
          color: c.scaffoldBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎩 HEADER
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFFFF6D00),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Export Purchase Order",
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: c.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 💼 BODY
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚨 BIG ALARM MESSAGE
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFFF6D00),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "🚨 ALERT: Automated features are currently under development!",
                                style: TextStyle(
                                  color: const Color(0xFFFF6D00),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Please copy and send this order manually via WhatsApp or Email for now.",
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order Content",
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCopied ? c.success : c.cardBg,
                          foregroundColor: _isCopied
                              ? Colors.black
                              : c.textPrimary,
                          side: BorderSide(
                            color: _isCopied ? Colors.transparent : c.border,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: messageText),
                          );
                          setState(() => _isCopied = true);
                        },
                        icon: Icon(
                          _isCopied ? Icons.check : Icons.copy,
                          size: 16,
                        ),
                        label: Text(
                          _isCopied ? "COPIED!" : "COPY TEXT",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.transparent
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: SelectableText(
                      messageText,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ⚡ ACTIONS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Keep Pending",
                      style: TextStyle(
                        color: c.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.success,
                      foregroundColor: Colors.black, // Premium Dark text
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            widget.onMarkAsRead();
                            Navigator.pop(context);
                          },
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.done_all, size: 18),
                    label: const Text(
                      "MARK SENT & MOVE TO HISTORY",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

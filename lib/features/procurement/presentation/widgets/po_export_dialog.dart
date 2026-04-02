import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PoExportDialog extends StatefulWidget {
  final String supplierName;
  final String supplierEmail;
  final String supplierPhone;
  final String poId;
  final List<dynamic> items;
  final String senderName; // 🚀 NAYA: Sender ka asli naam/email
  final VoidCallback onMarkAsRead; // 🚀 NAYA: DB Approval trigger

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
    buffer.writeln(
      "Thanks & Regards,\n${widget.senderName}",
    ); // 🚀 Asli Sender Name

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF080B08);
    const Color cardDark = Color(0xFF111811);
    const Color accentOrange = Color(0xFFD4580A);
    const Color accentGreen = Color(0xFF00C853);
    final String messageText = _generateMessage();

    return Dialog(
      backgroundColor: bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentOrange.withOpacity(0.5), width: 1.5),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🚨 BIG ALARM MESSAGE
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: accentOrange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accentOrange.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment
                        .start, // 🚀 Line break hone par alignment sahi rakhega
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: accentOrange,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        // 🚀 MAGIC FIX: Expanded lagane se overflow nahi hoga
                        child: Text(
                          "🚨 ALERT: Automated features are currently under development!",
                          style: TextStyle(
                            color: accentOrange,
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
                      color: const Color(
                        0xFFF0F0F0,
                      ).withOpacity(0.8), // 🚀 FIX: Direct Color Code
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Order Content",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCopied ? accentGreen : Colors.white,
                    foregroundColor: _isCopied ? Colors.white : bgDark,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: messageText));
                    setState(() => _isCopied = true);
                  },
                  icon: Icon(_isCopied ? Icons.check : Icons.copy, size: 16),
                  label: Text(
                    _isCopied ? "COPIED!" : "COPY TEXT",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: SelectableText(
                messageText,
                style: const TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              // 🚀 MAGIC FIX: Row ki jagah Wrap use kiya
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12, // Horizontal space
              runSpacing: 12, // Vertical space agar buttons agli line me jayein
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Keep Pending",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                // 🚀 THE MAGIC BUTTON: Moves to history ONLY when clicked
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          widget.onMarkAsRead(); // Trigger Database update
                          Navigator.pop(context); // Close dialog
                        },
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.done_all, size: 16),
                  label: const Text(
                    "MARK SENT & MOVE TO HISTORY",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

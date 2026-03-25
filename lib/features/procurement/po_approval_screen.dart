import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import 'providers/po_engine_service.dart';
import 'presentation/widgets/expiry_dashboard.dart';
import 'presentation/add_distributor_dialog.dart';

class POApprovalScreen extends ConsumerStatefulWidget {
  const POApprovalScreen({super.key});

  @override
  ConsumerState<POApprovalScreen> createState() => _POApprovalScreenState();
}

class _POApprovalScreenState extends ConsumerState<POApprovalScreen> {
  int _selectedTab = 0;
  bool _isUploadingCsv = false;

  Future<void> _processSupplierCsvImport() async {
    setState(() => _isUploadingCsv = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() => _isUploadingCsv = false);
        return;
      }

      final bytes = result.files.single.bytes!;
      final csvString = utf8.decode(bytes);
      List<String> lines = csvString.split('\n');

      if (lines.length <= 1) throw "🚨 CSV is empty or missing data rows!";

      final batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;

        List<String> row = line.split(',');
        if (row.isEmpty || row.length < 2 || row[1].trim().isEmpty) continue;

        final docRef = FirebaseFirestore.instance.collection('suppliers').doc();
        batch.set(docRef, {
          'supplierID': row[0].trim(),
          'name': row[1].trim(),
          'email': row.length > 2 ? row[2].trim() : '',
          'phone': row.length > 3 ? row[3].trim() : '',
          'categories': row.length > 4 ? row[4].trim() : '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ $count Distributors Imported Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚨 Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUploadingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEngineRunning = ref.watch(poEngineProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 20,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B3674).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // 🚀 BUG FIX: Universally supported icon
                        child: const Icon(
                          Icons.business_center,
                          color: Color(0xFF2B3674),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Procurement & Supply Chain",
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2B3674),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Smart Sourcing & Global Vendor Intelligence",
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2B3674),
                          elevation: 0,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isUploadingCsv
                            ? null
                            : _processSupplierCsvImport,
                        icon: _isUploadingCsv
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined, size: 20),
                        label: Text(
                          _isUploadingCsv ? "Uploading..." : "Import CSV",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2B3674),
                          elevation: 0,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) => const AddDistributorDialog(),
                        ),
                        icon: const Icon(Icons.domain_add_outlined, size: 20),
                        label: const Text(
                          "Add Distributor",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isEngineRunning
                              ? null
                              : () async {
                                  try {
                                    int count = await ref
                                        .read(poEngineProvider.notifier)
                                        .generateDraftPOs();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            count > 0
                                                ? "✅ $count POs Auto-Generated!"
                                                : "👍 Stock is healthy.",
                                          ),
                                          backgroundColor: count > 0
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                      );
                                      setState(() => _selectedTab = 1);
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Error: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          icon: isEngineRunning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 20,
                                ),
                          label: Text(
                            isEngineRunning
                                ? "GENERATING..."
                                : "RUN AUTO-PO ENGINE",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 🚀 100% WIDTH ENGINE
              const SizedBox(
                width: double.infinity,
                child: ExpiryAlertDashboard(),
              ),

              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton(
                      0,
                      "🤖 AI Suggestions",
                      Icons.psychology,
                      Colors.purple,
                    ),
                    const SizedBox(width: 16),
                    _buildTabButton(
                      1,
                      "Pending Approvals",
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                    const SizedBox(width: 16),
                    _buildTabButton(
                      2,
                      "PO History",
                      Icons.history,
                      Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              StreamBuilder<QuerySnapshot>(
                stream: _selectedTab == 0
                    ? FirebaseFirestore.instance
                          .collection('ai_po_suggestions')
                          .orderBy('createdAt', descending: true)
                          .snapshots()
                    : FirebaseFirestore.instance
                          .collection('purchase_orders')
                          .where(
                            'status',
                            whereIn: _selectedTab == 1
                                ? ['DRAFT', 'PENDING_APPROVAL']
                                : ['APPROVED'],
                          )
                          .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedTab == 0
                                ? Icons.check_circle
                                : (_selectedTab == 1
                                      ? Icons.inventory_2_outlined
                                      : Icons.history),
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedTab == 0
                                ? "AI has no suggestions today. Stock is optimized! ✨"
                                : (_selectedTab == 1
                                      ? "No Pending POs!"
                                      : "No approved orders yet."),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs.toList();

                  if (_selectedTab == 0) {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: Colors.purple.shade200,
                              width: 2,
                            ),
                          ),
                          color: Colors.purple.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          color: Colors.purple,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "AI Restock Alert",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      data['supplierId'] ?? 'DEFAULT',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Text(
                                  data['productName'] ?? 'Unknown Item',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "Reason: ${data['reason'] ?? 'Stock is low'}",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Suggested Qty: ${data['recommendedQty']} Units",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () => ref
                                              .read(poEngineProvider.notifier)
                                              .rejectAiSuggestion(
                                                data['suggestionId'],
                                              ),
                                          child: const Text(
                                            "Dismiss",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple,
                                          ),
                                          onPressed: () async {
                                            await ref
                                                .read(poEngineProvider.notifier)
                                                .approveAIPo(
                                                  data,
                                                  data['recommendedQty'] ?? 0,
                                                  "MUM01",
                                                );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "✅ AI PO Approved & Email Sent!",
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.flash_on,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            "APPROVE & SEND",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }

                  docs.sort((a, b) {
                    String timeField = _selectedTab == 1
                        ? 'createdAt'
                        : 'approvedAt';
                    final aTime =
                        (a.data() as Map<String, dynamic>)[timeField]
                            as Timestamp?;
                    final bTime =
                        (b.data() as Map<String, dynamic>)[timeField]
                            as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final items = data['items'] as List<dynamic>? ?? [];
                      DateTime date =
                          (data[_selectedTab == 1 ? 'createdAt' : 'approvedAt']
                                  as Timestamp?)
                              ?.toDate() ??
                          DateTime.now();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.domain,
                                        color: _selectedTab == 1
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        "Supplier: ${data['supplierId']}",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    DateFormat('dd MMM, hh:mm a').format(date),
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              const Divider(height: 30),
                              ...items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "• ${item['name']}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          "Req: ${item['orderQty']} units",
                                          style: const TextStyle(
                                            color: Colors.blueAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: _selectedTab == 1
                                    ? [
                                        TextButton.icon(
                                          onPressed: () => FirebaseFirestore
                                              .instance
                                              .collection('purchase_orders')
                                              .doc(doc.id)
                                              .delete(),
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          label: const Text(
                                            "Discard",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                          ),
                                          onPressed: () async {
                                            await ref
                                                .read(poEngineProvider.notifier)
                                                .approvePO(doc.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "PO Approved! Moved to History. 🚀",
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.send,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            "APPROVE & SEND PO",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ]
                                    : [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.verified,
                                                color: Colors.green,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "Approved by ${data['approvedBy'] ?? 'Admin'}",
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(
    int index,
    String title,
    IconData icon,
    Color activeColor,
  ) {
    bool isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? activeColor : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 🚀 Added for actual Barcode/QR generation
import '../providers/idt_deposit_provider.dart';
import '../../coach/widgets/info_button.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode_widget/barcode_widget.dart'; // 🚀 UI me 1D Barcode dikhane ke liye

class IdtDepositsScreen extends ConsumerWidget {
  const IdtDepositsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositState = ref.watch(idtDepositProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      body: depositState.isLoading
          ? Center(child: CircularProgressIndicator(color: c.ctaBackground))
          : depositState.errorMsg.isNotEmpty
          ? Center(
              child: Text(
                depositState.errorMsg,
                style: TextStyle(color: c.danger, fontWeight: FontWeight.bold),
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!depositState.isFetchingMore &&
                    depositState.hasMore &&
                    scrollInfo.metrics.pixels >=
                        scrollInfo.metrics.maxScrollExtent - 200) {
                  ref.read(idtDepositProvider.notifier).fetchMore();
                  return true;
                }
                return false;
              },
              child: FlatDepositTable(records: depositState.records),
            ),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length >= 3) {
      final newText = '${text.substring(0, 2)}/${text.substring(2)}';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    return newValue;
  }
}

class FlatDepositTable extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> records;
  const FlatDepositTable({super.key, required this.records});

  @override
  ConsumerState<FlatDepositTable> createState() => _FlatDepositTableState();
}

class _FlatDepositTableState extends ConsumerState<FlatDepositTable> {
  final List<Map<String, dynamic>> _dbItems = [];
  final List<Map<String, dynamic>> _localItems = [];
  Set<int> _selectedIndices = {};

  final TextEditingController _bulkHsnCtrl = TextEditingController();
  final TextEditingController _bulkExpiryCtrl = TextEditingController();
  String? _bulkGst;
  final List<String> _gstSlabs = ["0", "5", "12", "18", "28"];

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _scanCtrl = TextEditingController();
  final FocusNode _scanFocus = FocusNode();
  final ScrollController _horizontalScrollController = ScrollController();
  bool _isProcessing = false; // 🚀 FIX: Master Processing-Lock guard

  @override
  void initState() {
    super.initState();
    _flattenRecords();
    _loadDraft();
  }

  @override
  void dispose() {
    _bulkHsnCtrl.dispose();
    _bulkExpiryCtrl.dispose();
    _horizontalScrollController.dispose();
    _searchCtrl.dispose();
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FlatDepositTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records) _flattenRecords();
  }

  void _flattenRecords() {
    // 🚀 FIX: Prevent checkbox shifting when background data updates
    int oldDbCount = _dbItems.length;
    _dbItems.clear();

    List<int> localSelections = [];
    for (int idx in _selectedIndices) {
      if (idx >= oldDbCount) {
        localSelections.add(idx - oldDbCount);
      }
    }
    _selectedIndices.clear();

    for (var record in widget.records) {
      List items = record['items'] ?? [];
      for (int i = 0; i < items.length; i++) {
        var item = Map<String, dynamic>.from(items[i]);
        item['_docId'] = record['docId'];
        item['_originalIndex'] = i;
        _dbItems.add(item);
      }
    }

    for (int lIdx in localSelections) {
      _selectedIndices.add(_dbItems.length + lIdx);
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('idt_local_draft', jsonEncode(_localItems));
    } catch (e) {
      debugPrint("Draft Error: $e");
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = prefs.getString('idt_local_draft');
      if (draft != null) {
        final List<dynamic> decoded = jsonDecode(draft);
        setState(() {
          _localItems.clear();
          _localItems.addAll(decoded.map((e) => Map<String, dynamic>.from(e)));
          for (int i = 0; i < _localItems.length; i++) {
            _selectedIndices.add(_dbItems.length + i);
          }
        });
      }
    } catch (e) {
      debugPrint("Load Error: $e");
    }
  }

  void _playSuccessSound() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  void _playErrorSound() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  Future<void> _handleScan(String barcode) async {
    final bc = barcode.trim().replaceAll(RegExp(r'\s+'), '');
    if (bc.isEmpty) {
      _scanFocus.requestFocus();
      return;
    }

    int existingIndex = _localItems.indexWhere((item) => item['barcode'] == bc);

    if (existingIndex >= 0) {
      setState(() {
        int currentQty =
            int.tryParse(
              _localItems[existingIndex]['quantity']?.toString() ?? '1',
            ) ??
            1;
        _localItems[existingIndex]['quantity'] = (currentQty + 1).toString();
      });
      _playSuccessSound();
      _saveDraft();
    } else {
      final pData = await ref.read(idtDepositProvider.notifier).getProduct(bc);
      setState(() {
        _localItems.add({
          'barcode': bc,
          'name': pData?['name'] ?? '',
          'quantity': 1,
          'price': pData?['price'] ?? '',
          'unitCost': pData?['unitCost'] ?? '',
          'physicalStock': pData?['physicalStock'] ?? '',
          'weight': pData?['weight'] ?? '',
          'hsn': pData?['hsn'] ?? '',
          'gst': pData?['gst'] ?? '',
          'expiryDate': pData?['expiryDate'] ?? '',
          'isLocal': true,
          '_localId': DateTime.now().millisecondsSinceEpoch,
        });
        _selectedIndices.add(_dbItems.length + _localItems.length - 1);
      });

      if (pData != null) {
        _playSuccessSound();
      } else {
        _playErrorSound();
      }
      _saveDraft();
    }

    _scanCtrl.clear();
    Future.delayed(
      const Duration(milliseconds: 50),
      () => _scanFocus.requestFocus(),
    );
  }

  // 🚀 FIXED & PREMIUM PREVIEW STICKER DIALOG
  // 🚀 ACTUAL THERMAL STICKER PRINTING ENGINE
  Future<void> _printThermalSticker(Map<String, dynamic> item) async {
    final pdf = pw.Document();

    // 🛠️ STRICT PAPER SIZE: 50mm width x 25mm height (Standard 2x1 inch Thermal Sticker)
    // Margin zero rakha hai taaki thermal printer khud adjust kar le
    final stickerFormat = PdfPageFormat(
      50 * PdfPageFormat.mm,
      25 * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: stickerFormat,
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                item['name']?.toString().toUpperCase() ?? 'ITEM',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 1,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                "MRP: Rs. ${item['price'] ?? '0'}",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              // 🚀 CODE-128 BARCODE: Supports any length and alphanumeric characters
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: item['barcode']?.toString() ?? '0000',
                width: 120,
                height: 25,
                drawText: true,
                textStyle: pw.TextStyle(fontSize: 6),
              ),
            ],
          );
        },
      ),
    );

    // 🖨️ FIRE PRINT COMMAND
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sticker_${item['barcode']}',
    );
  }

  // 🚀 PREMIUM PREVIEW DIALOG WITH 1D BARCODE
  void _showStickerDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
            children: [
              const Text(
                "THERMAL STICKER PREVIEW",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),

              // 🔲 EXACT STICKER PREVIEW BOX
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    Text(
                      item['name']?.toString().toUpperCase() ?? 'UNKNOWN ITEM',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "MRP: ₹${item['price'] ?? '0'}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 🚀 ACTUAL 1D BARCODE (Code 128)
                    SizedBox(
                      height: 60,
                      child: BarcodeWidget(
                        barcode: Barcode.code128(), // 🛡️ Failsafe Code-128
                        data: item['barcode']?.toString() ?? '0000',
                        drawText: true,
                        color: Colors.black,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text(
                      "CANCEL",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text(
                      "PRINT STICKER",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _printThermalSticker(
                        item,
                      ); // 🖨️ TRIGGERS REAL THERMAL PDF
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyBulkUpdate() {
    if (_selectedIndices.isEmpty) return;
    final allItems = [..._dbItems, ..._localItems];
    setState(() {
      for (int i in _selectedIndices) {
        if (_bulkHsnCtrl.text.isNotEmpty)
          allItems[i]['hsn'] = _bulkHsnCtrl.text;
        if (_bulkExpiryCtrl.text.isNotEmpty)
          allItems[i]['expiryDate'] = _bulkExpiryCtrl.text;
        if (_bulkGst != null) allItems[i]['gst'] = _bulkGst;
      }
    });
    _saveDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Bulk Update Applied!"),
        backgroundColor: context.colors.success,
      ),
    );
  }

  void _deleteSelected() async {
    if (_selectedIndices.isEmpty) return;
    final allItems = [..._dbItems, ..._localItems];
    List<Map<String, dynamic>> toDeleteDb = [];

    setState(() {
      final indicesList = _selectedIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (int i in indicesList) {
        final item = allItems[i];
        if (item['isLocal'] == true) {
          _localItems.removeWhere((l) => l['_localId'] == item['_localId']);
        } else {
          toDeleteDb.add(item);
        }
      }
      _selectedIndices.clear();
    });
    _saveDraft();

    if (toDeleteDb.isNotEmpty) {
      try {
        await ref.read(idtDepositProvider.notifier).deleteItems(toDeleteDb);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: context.colors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allItems = [..._dbItems, ..._localItems];

    List<Map<String, dynamic>> displayedItems = allItems;
    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      displayedItems = allItems
          .where(
            (i) =>
                (i['barcode'] ?? '').toString().toLowerCase().contains(q) ||
                (i['name'] ?? '').toString().toLowerCase().contains(q),
          )
          .toList();
    }

    List<DataRow> tableRows = displayedItems.asMap().entries.map((entry) {
      int index = entry.key;
      var item = entry.value;
      bool isLocalRow = item['isLocal'] == true;

      return DataRow(
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered))
            return c.success.withValues(alpha: 0.05);
          if (isLocalRow) return c.success.withValues(alpha: 0.08);
          return index % 2 == 0
              ? Colors.transparent
              : c.cardBg.withValues(alpha: 0.3);
        }),
        cells: [
          DataCell(
            Checkbox(
              value: _selectedIndices.contains(index),
              activeColor: c.ctaBackground,
              onChanged: (v) {
                setState(() {
                  if (v == true)
                    _selectedIndices.add(index);
                  else
                    _selectedIndices.remove(index);
                });
              },
            ),
          ),
          DataCell(
            Text(
              item['barcode'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
          ),
          DataCell(_compactInput(item, 'name', width: 220)),
          DataCell(_compactInput(item, 'quantity', width: 70, isNum: true)),
          DataCell(_compactInput(item, 'price', width: 85, isNum: true)),
          DataCell(
            Tooltip(
              message: "Kharidi Bhav",
              child: _compactInput(item, 'unitCost', width: 85, isNum: true),
            ),
          ),
          DataCell(
            Tooltip(
              message: "Already Available Stock",
              child: Text(
                item['physicalStock']?.toString() ?? '0',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
          DataCell(_compactInput(item, 'weight', width: 90)),
          DataCell(_compactInput(item, 'hsn', width: 90)),
          DataCell(
            SizedBox(
              width: 95,
              height: 40,
              child: DropdownButtonFormField<String>(
                value: _gstSlabs.contains(item['gst']?.toString())
                    ? item['gst'].toString()
                    : null,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                dropdownColor: c.cardBg,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                items: _gstSlabs
                    .map((s) => DropdownMenuItem(value: s, child: Text("$s%")))
                    .toList(),
                onChanged: (v) {
                  item['gst'] = v;
                  _saveDraft();
                },
              ),
            ),
          ),
          DataCell(
            _compactInput(
              item,
              'expiryDate',
              width: 100,
              hint: "MM/YYYY",
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
                _ExpiryDateFormatter(),
              ],
            ),
          ),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.print,
                    color: Colors.blueGrey,
                    size: 20,
                  ),
                  tooltip: "Print Barcode",
                  onPressed: () => _showStickerDialog(item),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: c.danger, size: 20),
                  tooltip: "Delete Row",
                  onPressed: () async {
                    if (isLocalRow) {
                      setState(() {
                        _localItems.removeWhere(
                          (l) => l['_localId'] == item['_localId'],
                        );
                        _selectedIndices.remove(index);
                      });
                      _saveDraft();
                    } else {
                      try {
                        await ref.read(idtDepositProvider.notifier).deleteItems(
                          [item],
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: c.danger,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();

    if (_searchCtrl.text.isEmpty) {
      tableRows.add(
        DataRow(
          color: WidgetStateProperty.all(
            c.ctaBackground.withValues(alpha: 0.08),
          ),
          cells: [
            const DataCell(SizedBox.shrink()),
            DataCell(
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _scanCtrl,
                  focusNode: _scanFocus,
                  autofocus: true,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: "Scan Barcode...",
                    hintStyle: TextStyle(
                      color: c.textSecondary.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.qr_code_scanner,
                      size: 16,
                      color: c.ctaBackground,
                    ),
                    filled: true,
                    fillColor: c.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: c.ctaBackground),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onSubmitted: _handleScan,
                ),
              ),
            ),
            DataCell(
              Text(
                "Scan barcode to add row...",
                style: TextStyle(
                  color: c.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const DataCell(Text("")),
            const DataCell(Text("")),
            const DataCell(Text("")),
            const DataCell(Text("")),
            const DataCell(Text("")),
            const DataCell(Text("")),
            const DataCell(Text("")),
            const DataCell(Text("")),
            const DataCell(Text("")),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 🟦 PREMIUM HEADER & BULK TOOLS
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: c.cardBg,
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "IDT Deposits",
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const InfoButton(
                    title: 'IDT — Inventory Deposit Terminal',
                    en: 'IDT is your stock intake system. Scan barcodes to add items instantly. Enter mandatory details (Qty, Price, Cost, Wt/Vol), select the rows, and click "Verify & Go Live" to push them to your active store inventory.',
                    hi: 'IDT stock intake system hai. Barcode scan karein, quantity aur price daalein, aur "Verify & Go Live" daba kar seedha store me live karein.',
                  ),
                ],
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 250,
                height: 40,
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: c.textPrimary),
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Search deposits...",
                    hintStyle: TextStyle(
                      color: c.textSecondary.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: c.textSecondary,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.scaffoldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        "BULK TOOL",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    _buildSmallField(_bulkHsnCtrl, "HSN", isDark),
                    const SizedBox(width: 6),
                    _buildSmallField(
                      _bulkExpiryCtrl,
                      "MM/YYYY",
                      isDark,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                        _ExpiryDateFormatter(),
                      ],
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 90,
                      height: 36,
                      child: DropdownButtonFormField<String>(
                        value: _bulkGst,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        dropdownColor: c.cardBg,
                        decoration: InputDecoration(
                          hintText: "GST",
                          hintStyle: TextStyle(color: c.textSecondary),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                        ),
                        items: _gstSlabs
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text("$s%"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _bulkGst = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.ctaBackground,
                        foregroundColor: c.ctaText,
                        elevation: 0,
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: _applyBulkUpdate,
                      child: const Text(
                        "APPLY",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedIndices.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.delete, color: c.danger),
                  onPressed: _deleteSelected,
                  tooltip: "Delete Selected",
                ),
              IconButton(
                icon: Icon(Icons.refresh, color: c.textPrimary),
                onPressed: () =>
                    ref.read(idtDepositProvider.notifier).fetchInitial(),
              ),
            ],
          ),
        ),

        // 💡 SMART INSTRUCTION BANNER
        if (allItems.isEmpty)
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.ctaBackground.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.ctaBackground.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: c.ctaBackground, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "How to use IDT Deposits?",
                        style: TextStyle(
                          color: c.ctaBackground,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Connect your barcode scanner and start scanning products. Enter their quantity, price, and cost. Select the rows and click 'Verify & Go Live' to add them to your billing inventory.",
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ⬜ MAIN DATA TABLE
        Expanded(
          child: GestureDetector(
            onTap: () => _scanFocus.requestFocus(),
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowHeight: 56,
                        headingRowColor: WidgetStateProperty.all(
                          isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.grey.shade50,
                        ),
                        columnSpacing: 24,
                        horizontalMargin: 20,
                        dividerThickness: 0.5,
                        headingTextStyle: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: c.textPrimary,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                        columns: [
                          DataColumn(
                            label: Checkbox(
                              value:
                                  _selectedIndices.length == allItems.length &&
                                  allItems.isNotEmpty,
                              activeColor: c.ctaBackground,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedIndices = Set.from(
                                      Iterable.generate(allItems.length),
                                    );
                                  } else {
                                    _selectedIndices.clear();
                                  }
                                });
                              },
                            ),
                          ),
                          const DataColumn(label: Text("BARCODE")),
                          const DataColumn(label: Text("PRODUCT NAME *")),
                          DataColumn(
                            label: Text(
                              "QTY *",
                              style: TextStyle(color: c.ctaBackground),
                            ),
                          ),
                          const DataColumn(label: Text("PRICE (₹) *")),
                          const DataColumn(
                            label: Tooltip(
                              message: "Kharidi Bhav",
                              child: Text("COST (₹) *"),
                            ),
                          ),
                          DataColumn(
                            label: Tooltip(
                              message: "Already Available Stock",
                              child: Text(
                                "CUR. STOCK",
                                style: TextStyle(color: c.textSecondary),
                              ),
                            ),
                          ),
                          const DataColumn(label: Text("WT/VOL *")),
                          const DataColumn(label: Text("HSN")),
                          const DataColumn(label: Text("GST (%)")),
                          const DataColumn(label: Text("EXPIRY")),
                          const DataColumn(label: Text("ACTION")),
                        ],
                        rows: tableRows,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 🟩 PREMIUM FOOTER
        if (allItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            decoration: BoxDecoration(
              color: c.cardBg,
              border: Border(top: BorderSide(color: c.border)),
            ),
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.success,
                foregroundColor:
                    Colors.black, // Dark text on green for premium look
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 18,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (_isProcessing) return; // 🚀 FIX: Double-click lock!

                if (_selectedIndices.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Select items to Go Live!"),
                      backgroundColor: c.danger,
                    ),
                  );
                  return;
                }

                List<Map<String, dynamic>> itemsToProcess = [];
                for (int i in _selectedIndices) {
                  itemsToProcess.add(allItems[i]);
                }

                for (var item in itemsToProcess) {
                  if ((item['name']?.toString().trim().isEmpty ?? true) ||
                      (item['quantity']?.toString().trim().isEmpty ?? true) ||
                      (item['price']?.toString().trim().isEmpty ?? true) ||
                      (item['unitCost']?.toString().trim().isEmpty ?? true) ||
                      (item['weight']?.toString().trim().isEmpty ?? true)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "Missing Mandatory Fields! (Name, Qty, Price, Cost, Wt/Vol)",
                        ),
                        backgroundColor: c.danger,
                      ),
                    );
                    return;
                  }
                }

                // 🚀 NEW: CONFIRMATION DIALOG BEFORE GO LIVE
                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: c.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Row(
                      children: [
                        Icon(Icons.rocket_launch, color: c.success),
                        const SizedBox(width: 10),
                        Text(
                          "Confirm Go Live",
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      "Are you sure you want to push ${itemsToProcess.length} items to the live inventory? This action will immediately make them available for billing.",
                      style: TextStyle(color: c.textSecondary, height: 1.5),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          "CANCEL",
                          style: TextStyle(
                            color: c.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.success,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          "YES, GO LIVE",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return; // User cancelled

                setState(() => _isProcessing = true); // 🚀 Lock UI

                try {
                  await ref
                      .read(idtDepositProvider.notifier)
                      .markMultipleAsProcessed(itemsToProcess);

                  if (!context.mounted) return;

                  setState(() {
                    final processedLocalIds = itemsToProcess
                        .where((i) => i['isLocal'] == true)
                        .map((i) => i['_localId'])
                        .toSet();

                    _localItems.removeWhere(
                      (l) => processedLocalIds.contains(l['_localId']),
                    );
                    _selectedIndices.clear();
                  });

                  _saveDraft();
                  _playSuccessSound();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Verified & Stock Live! ✅"),
                        backgroundColor: c.success,
                      ),
                    );
                  }
                } catch (e) {
                  _playErrorSound();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: c.danger,
                      ),
                    );
                  }
                } finally {
                  if (mounted)
                    setState(() => _isProcessing = false); // 🚀 Unlock UI
                }
              },
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.rocket_launch, size: 20),
              label: Text(
                _isProcessing ? "PROCESSING..." : "VERIFY & GO LIVE",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSmallField(
    TextEditingController ctrl,
    String hint,
    bool isDark, {
    List<TextInputFormatter>? formatters,
  }) {
    return SizedBox(
      width: 90,
      height: 36,
      child: TextField(
        controller: ctrl,
        inputFormatters: formatters,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.colors.textSecondary),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  // 🚀 FIXED: ValueKey was causing input focus loss on every keystroke
  Widget _compactInput(
    Map<String, dynamic> item,
    String key, {
    double width = 80,
    bool isNum = false,
    List<TextInputFormatter>? formatters,
    String hint = '',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = context.colors;

    return SizedBox(
      width: width,
      height: 40,
      child: TextFormField(
        key: ValueKey(
          '${item['_docId'] ?? item['_localId']}_${item['_originalIndex'] ?? 0}_$key',
        ),
        initialValue: item[key]?.toString() ?? '',
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        inputFormatters: formatters,
        // 🚀 ABSOLUTE FIX: Explicitly forcing White text in Dark Mode so it never shows black
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.5)),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.ctaBackground, width: 1.5),
          ),
        ),
        onChanged: (v) {
          item[key] = v;
          _saveDraft();
        },
      ),
    );
  }
}

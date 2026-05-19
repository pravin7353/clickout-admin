import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/idt_deposit_provider.dart';

class IdtDepositsScreen extends ConsumerWidget {
  const IdtDepositsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositState = ref.watch(idtDepositProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentViolet = isDark
        ? const Color(0xFFB388FF)
        : const Color(0xFF6200EA);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: depositState.isLoading
          ? Center(child: CircularProgressIndicator(color: accentViolet))
          : depositState.errorMsg.isNotEmpty
          ? Center(
              child: Text(
                depositState.errorMsg,
                style: const TextStyle(color: Colors.redAccent),
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
  const FlatDepositTable({Key? key, required this.records}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _flattenRecords();
    _loadDraft(); // 🚀 FEATURE 3: Load Anti-Crash Drafts on Startup
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
    _dbItems.clear();
    _selectedIndices.removeWhere(
      (idx) => idx < _dbItems.length,
    ); // Keep local selections safe
    for (var record in widget.records) {
      List items = record['items'] ?? [];
      for (int i = 0; i < items.length; i++) {
        var item = Map<String, dynamic>.from(items[i]);
        item['_docId'] = record['docId'];
        item['_originalIndex'] = i;
        _dbItems.add(item);
      }
    }
  }

  // 🚀 FEATURE 3: ANTI-CRASH SAVING
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
          // Auto-select loaded items
          for (int i = 0; i < _localItems.length; i++) {
            _selectedIndices.add(_dbItems.length + i);
          }
        });
      }
    } catch (e) {
      debugPrint("Load Error: $e");
    }
  }

  // 🚀 FEATURE 2: AUDIO FEEDBACK
  void _playSuccessSound() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  void _playErrorSound() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  // 🚀 FEATURE 1 & 2: SMART MERGE + SOUND
  Future<void> _handleScan(String barcode) async {
    final bc = barcode.trim().replaceAll(RegExp(r'\s+'), '');
    if (bc.isEmpty) {
      _scanFocus.requestFocus();
      return;
    }

    int existingIndex = _localItems.indexWhere((item) => item['barcode'] == bc);

    if (existingIndex >= 0) {
      // 🔄 AUTO-MERGE DUPLICATE SCANS
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
      // ADD NEW
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
        _playErrorSound(); // 🚨 UNKNOWN ITEM ALERT
      }
      _saveDraft();
    }

    _scanCtrl.clear();
    Future.delayed(
      const Duration(milliseconds: 50),
      () => _scanFocus.requestFocus(),
    );
  }

  // 🚀 FEATURE 4: BARCODE STICKER GENERATOR
  void _showStickerDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "THERMAL STICKER PREVIEW",
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.white,
              ),
              width: 250,
              child: Column(
                children: [
                  Text(
                    item['name']?.toString().toUpperCase() ?? 'UNKNOWN ITEM',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "MRP: ₹${item['price'] ?? '0'}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fake Barcode Graphic
                  const Icon(Icons.view_week, size: 60, color: Colors.black),
                  const SizedBox(height: 4),
                  Text(
                    item['barcode'] ?? '',
                    style: const TextStyle(
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.print, size: 18),
            label: const Text("PRINT STICKER"),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Sending to Thermal Printer 🖨️..."),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
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
      const SnackBar(
        content: Text("Bulk Update Applied!"),
        backgroundColor: Colors.blue,
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
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardDark = theme.cardColor;
    final accentViolet = isDark
        ? const Color(0xFFB388FF)
        : const Color(0xFF6200EA);
    final inputBg = isDark ? const Color(0xFF1A221A) : const Color(0xFFF4F5F7);

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
        color: WidgetStateProperty.all(
          isLocalRow
              ? Colors.green.withOpacity(0.05)
              : (index % 2 == 0
                    ? Colors.transparent
                    : accentViolet.withOpacity(0.04)),
        ),
        cells: [
          DataCell(
            Checkbox(
              value: _selectedIndices.contains(index),
              activeColor: accentViolet,
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(_compactInput(item, 'name', width: 200)),
          DataCell(_compactInput(item, 'quantity', width: 60, isNum: true)),
          DataCell(_compactInput(item, 'price', width: 75, isNum: true)),
          DataCell(
            Tooltip(
              message: "Kharidi Bhav",
              child: _compactInput(item, 'unitCost', width: 75, isNum: true),
            ),
          ),
          DataCell(
            Tooltip(
              message: "Already Available Stock",
              child: Text(
                item['physicalStock']?.toString() ?? '0',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          DataCell(_compactInput(item, 'weight', width: 80)),
          DataCell(_compactInput(item, 'hsn', width: 85)),
          DataCell(
            SizedBox(
              width: 95,
              height: 36,
              child: DropdownButtonFormField<String>(
                value: _gstSlabs.contains(item['gst']?.toString())
                    ? item['gst'].toString()
                    : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
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
              width: 95,
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
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
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
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
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
            isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
          ),
          cells: [
            const DataCell(SizedBox.shrink()),
            DataCell(
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _scanCtrl,
                  focusNode: _scanFocus,
                  autofocus: true,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: "Scan Barcode...",
                    prefixIcon: const Icon(Icons.qr_code_scanner, size: 16),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.blueAccent),
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
                  color: Colors.grey.shade500,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: cardDark,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              Text(
                "IDT Deposits",
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 250,
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Search deposits...",
                    prefixIcon: Icon(
                      Icons.search,
                      color: accentViolet,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              const Text(
                "BULK TOOL:  ",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              _buildSmallField(_bulkHsnCtrl, "HSN", inputBg),
              const SizedBox(width: 8),
              _buildSmallField(
                _bulkExpiryCtrl,
                "MM/YYYY",
                inputBg,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                  _ExpiryDateFormatter(),
                ],
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                height: 36,
                child: DropdownButtonFormField<String>(
                  value: _bulkGst,
                  decoration: InputDecoration(
                    hintText: "GST",
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  items: _gstSlabs
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text("$s%")),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _bulkGst = v),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentViolet,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                ),
                onPressed: _applyBulkUpdate,
                child: const Text(
                  "APPLY",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              if (_selectedIndices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: _deleteSelected,
                    tooltip: "Delete Selected",
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.read(idtDepositProvider.notifier).fetchInitial(),
              ),
            ],
          ),
        ),

        Expanded(
          child: GestureDetector(
            onTap: () => _scanFocus.requestFocus(),
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          isDark
                              ? const Color(0xFF1A221A)
                              : const Color(0xFFEDE7F6),
                        ),
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        dividerThickness: 0.5,
                        columns: [
                          DataColumn(
                            label: Checkbox(
                              value:
                                  _selectedIndices.length == allItems.length &&
                                  allItems.isNotEmpty,
                              activeColor: accentViolet,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true)
                                    _selectedIndices = Set.from(
                                      Iterable.generate(allItems.length),
                                    );
                                  else
                                    _selectedIndices.clear();
                                });
                              },
                            ),
                          ),
                          const DataColumn(label: Text("BARCODE")),
                          const DataColumn(label: Text("PRODUCT NAME *")),
                          const DataColumn(
                            label: Text(
                              "QTY *",
                              style: TextStyle(color: Colors.deepPurple),
                            ),
                          ),
                          const DataColumn(label: Text("PRICE (₹) *")),
                          const DataColumn(
                            label: Tooltip(
                              message: "Kharidi Bhav",
                              child: Text("COST (₹) *"),
                            ),
                          ),
                          const DataColumn(
                            label: Tooltip(
                              message: "Already Available Stock",
                              child: Text(
                                "CUR. STOCK",
                                style: TextStyle(color: Colors.grey),
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

        if (allItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: cardDark,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentViolet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (_selectedIndices.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Select items to Go Live!"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                List<Map<String, dynamic>> itemsToProcess = [];
                for (int i in _selectedIndices) itemsToProcess.add(allItems[i]);

                for (var item in itemsToProcess) {
                  if ((item['name']?.toString().trim().isEmpty ?? true) ||
                      (item['quantity']?.toString().trim().isEmpty ?? true) ||
                      (item['price']?.toString().trim().isEmpty ?? true) ||
                      (item['unitCost']?.toString().trim().isEmpty ?? true) ||
                      (item['weight']?.toString().trim().isEmpty ?? true)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Missing Mandatory Fields! (Name, Qty, Price, Cost, Wt/Vol)",
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                }

                try {
                  await ref
                      .read(idtDepositProvider.notifier)
                      .markMultipleAsProcessed(itemsToProcess);
                  setState(() {
                    _localItems.removeWhere((l) => itemsToProcess.contains(l));
                    _selectedIndices.clear();
                  });
                  _saveDraft(); // Clear draft after success
                  _playSuccessSound();
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Verified & Stock Live! ✅"),
                        backgroundColor: Colors.green,
                      ),
                    );
                } catch (e) {
                  _playErrorSound();
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                }
              },
              icon: const Icon(Icons.rocket_launch, size: 18),
              label: const Text(
                "VERIFY & GO LIVE",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSmallField(
    TextEditingController ctrl,
    String hint,
    Color bg, {
    List<TextInputFormatter>? formatters,
  }) {
    return SizedBox(
      width: 90,
      height: 36,
      child: TextField(
        controller: ctrl,
        inputFormatters: formatters,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _compactInput(
    Map<String, dynamic> item,
    String key, {
    double width = 80,
    bool isNum = false,
    List<TextInputFormatter>? formatters,
    String hint = '',
  }) {
    final theme = Theme.of(context);
    final inputBg = theme.brightness == Brightness.dark
        ? const Color(0xFF1A221A)
        : const Color(0xFFF4F5F7);
    return SizedBox(
      width: width,
      height: 36,
      child: TextFormField(
        key: ValueKey(
          '${item['_docId'] ?? item['_localId']}_${item['_originalIndex'] ?? 0}_${key}_${item[key]}',
        ),
        initialValue: item[key]?.toString() ?? '',
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        inputFormatters: formatters,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) {
          item[key] = v;
          _saveDraft(); // 🚀 FEATURE 3: Auto-Save Draft on every keystroke
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        : const Color(0xFF6200EA); // 💎 Royal Violet

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
          : depositState.records.isEmpty
          ? Center(
              child: Text(
                "No deposits pending.",
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
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

// 🚀 CUSTOM FORMATTER: Auto add "/" after MM
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
  final List<Map<String, dynamic>> _flatItems = [];
  Set<int> _selectedIndices = {};

  final TextEditingController _bulkHsnCtrl = TextEditingController();
  final TextEditingController _bulkExpiryCtrl = TextEditingController();
  String? _bulkGst;
  final List<String> _gstSlabs = ["0", "5", "12", "18", "28"];

  final ScrollController _horizontalScrollController =
      ScrollController(); // 🚀 SCROLL FIX

  @override
  void dispose() {
    _bulkHsnCtrl.dispose();
    _bulkExpiryCtrl.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _flattenRecords();
  }

  @override
  void didUpdateWidget(covariant FlatDepositTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records) {
      _flattenRecords();
    }
  }

  void _flattenRecords() {
    _flatItems.clear();
    _selectedIndices.clear();
    for (var record in widget.records) {
      List items = record['items'] ?? [];
      for (int i = 0; i < items.length; i++) {
        var item = Map<String, dynamic>.from(items[i]);
        item['_docId'] = record['docId'];
        item['_originalIndex'] = i;
        _flatItems.add(item);
      }
    }
  }

  void _applyBulkUpdate() {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select items using checkboxes first!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      for (int i in _selectedIndices) {
        if (_bulkHsnCtrl.text.isNotEmpty)
          _flatItems[i]['hsn'] = _bulkHsnCtrl.text;
        if (_bulkExpiryCtrl.text.isNotEmpty)
          _flatItems[i]['expiryDate'] = _bulkExpiryCtrl.text;
        if (_bulkGst != null) _flatItems[i]['gst'] = _bulkGst;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Bulk Update Applied!"),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color cardDark = theme.cardColor;
    final Color accentViolet = isDark
        ? const Color(0xFFB388FF)
        : const Color(0xFF6200EA);
    final Color textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color textSecondary =
        theme.textTheme.labelLarge?.color ?? Colors.grey;
    final Color inputBg = isDark
        ? const Color(0xFF1A221A)
        : const Color(0xFFF4F5F7);
    final Color tableHeaderBg = isDark
        ? const Color(0xFF1A221A)
        : const Color(0xFFEDE7F6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 🚀 TOP BAR: Title & Bulk Tool
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "IDT Deposits",
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "(Scanner Sync)",
                    style: TextStyle(
                      color: accentViolet,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              // 🚀 FIX: Spacer hata diya kyunki Wrap me nahi chalta

              // BULK TOOLBAR
              Text(
                "BULK TOOL:  ",
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(
                width: 90,
                height: 36,
                child: TextField(
                  controller: _bulkHsnCtrl,
                  style: TextStyle(color: textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "HSN",
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
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
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                height: 36,
                child: TextField(
                  controller: _bulkExpiryCtrl,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                    _ExpiryDateFormatter(),
                  ],
                  style: TextStyle(color: textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "MM/YYYY",
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
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
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                height: 36,
                child: DropdownButtonFormField<String>(
                  value: _bulkGst,
                  dropdownColor: cardDark,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: "GST",
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _applyBulkUpdate,
                child: const Text(
                  "APPLY",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.refresh, color: textSecondary),
                onPressed: () =>
                    ref.read(idtDepositProvider.notifier).fetchInitial(),
              ),
            ],
          ),
        ),

        // 🚀 MAIN TABLE (Sequence.io Premium Box)
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                // 🚀 FIX: Vertical wala upar aayega
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                child: Scrollbar(
                  // 🚀 FIX: Scrollbar explicitly horizontal wale ke upar
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  thickness: 8,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: theme.dividerColor),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(tableHeaderBg),
                        dataRowMinHeight: 50,
                        dataRowMaxHeight: 60,
                        headingRowHeight: 50,
                        columnSpacing: 25,
                        horizontalMargin: 24,
                        dividerThickness: 0.5,
                        headingTextStyle: TextStyle(
                          color: isDark
                              ? textSecondary
                              : const Color(
                                  0xFF311B92,
                                ), // Deep Purple Header Text
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        columns: [
                          DataColumn(
                            label: Checkbox(
                              value:
                                  _selectedIndices.length ==
                                      _flatItems.length &&
                                  _flatItems.isNotEmpty,
                              activeColor: accentViolet,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true)
                                    _selectedIndices = Set.from(
                                      Iterable.generate(_flatItems.length),
                                    );
                                  else
                                    _selectedIndices.clear();
                                });
                              },
                            ),
                          ),
                          const DataColumn(label: Text("BARCODE")),
                          const DataColumn(label: Text("PRODUCT NAME")),
                          DataColumn(
                            label: Text(
                              "QTY",
                              style: TextStyle(
                                color: accentViolet,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const DataColumn(label: Text("PRICE (₹)")),
                          const DataColumn(label: Text("COST (₹)")),
                          const DataColumn(label: Text("STOCK")),
                          const DataColumn(label: Text("WT/VOL")),
                          const DataColumn(label: Text("HSN")),
                          const DataColumn(label: Text("GST (%)")),
                          const DataColumn(label: Text("EXPIRY")),
                        ],
                        rows: _flatItems.asMap().entries.map((entry) {
                          int index = entry.key;
                          var item = entry.value;
                          return DataRow(
                            color: WidgetStateProperty.all(
                              index % 2 == 0
                                  ? Colors.transparent
                                  : accentViolet.withOpacity(0.04),
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
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              DataCell(
                                _compactInput(
                                  context,
                                  item,
                                  'name',
                                  width: 220,
                                ),
                              ),
                              DataCell(
                                _compactInput(
                                  context,
                                  item,
                                  'quantity',
                                  width: 60,
                                  isNum: true,
                                ),
                              ),
                              DataCell(
                                _compactInput(
                                  context,
                                  item,
                                  'price',
                                  width: 75,
                                  isNum: true,
                                ),
                              ),
                              DataCell(
                                _compactInput(
                                  context,
                                  item,
                                  'unitCost',
                                  width: 75,
                                  isNum: true,
                                ),
                              ),
                              DataCell(
                                _compactInput(
                                  context,
                                  item,
                                  'physicalStock',
                                  width: 70,
                                  isNum: true,
                                ),
                              ),
                              DataCell(
                                _compactInput(
                                  context,
                                  item,
                                  'weight',
                                  width: 80,
                                ),
                              ),
                              DataCell(
                                _compactInput(context, item, 'hsn', width: 85),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 95,
                                  height: 36,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      '${item['_docId']}_${item['_originalIndex']}_gst_${item['gst']}',
                                    ),
                                    value:
                                        _gstSlabs.contains(
                                          item['gst']?.toString(),
                                        )
                                        ? item['gst'].toString()
                                        : null,
                                    dropdownColor: cardDark,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: inputBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: theme.dividerColor,
                                          width: 0.5,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: theme.dividerColor,
                                          width: 0.5,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                    onChanged: (v) => item['gst'] = v,
                                  ),
                                ),
                              ),
                              DataCell(
                                _compactInput(
                                  context,
                                  item,
                                  'expiryDate',
                                  width: 95,
                                  formatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                    _ExpiryDateFormatter(),
                                  ],
                                  hint: "MM/YYYY",
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 🚀 BOTTOM BAR: GO LIVE ALL
        if (_flatItems.isNotEmpty)
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
                elevation: isDark ? 0 : 4,
              ),
              onPressed: () async {
                try {
                  await ref
                      .read(idtDepositProvider.notifier)
                      .markMultipleAsProcessed(_flatItems);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("All Inventory Live! ✅"),
                        backgroundColor: accentViolet,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.rocket_launch, size: 18),
              label: const Text(
                "VERIFY & GO LIVE ALL",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
      ],
    );
  }

  // 🚀 COMPACT TEXT FIELD HELPER (Premium UI Update)
  Widget _compactInput(
    BuildContext context,
    Map<String, dynamic> item,
    String key, {
    double width = 80,
    bool isNum = false,
    List<TextInputFormatter>? formatters,
    String hint = '',
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark ? const Color(0xFF1A221A) : const Color(0xFFF4F5F7);
    final accentViolet = isDark
        ? const Color(0xFFB388FF)
        : const Color(0xFF6200EA);

    return SizedBox(
      width: width,
      height: 36, // Thoda bada kiya UI clarity ke liye
      child: TextFormField(
        key: ValueKey(
          '${item['_docId']}_${item['_originalIndex']}_${key}_${item[key]}',
        ),
        initialValue: item[key]?.toString() ?? '',
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        inputFormatters: formatters,
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.textTheme.labelLarge?.color?.withOpacity(0.5),
            fontSize: 11,
          ),
          filled: true,
          fillColor: inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: accentViolet, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
        ),
        onChanged: (v) => item[key] = v,
      ),
    );
  }
}

class OcrEngine {
  // 🚀 ADMIN WEB SAFE: No Mobile ML-Kit needed.
  // It extracts data directly from text strings provided by Keyboard Wedge Scanners!
  static Map<String, dynamic> parse(String text) {
    final Map<String, dynamic> data = {};

    // Extract MRP
    final mrpMatch = RegExp(
      r'MRP\s*[:\-]?\s*₹?\s*([0-9]+(\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (mrpMatch != null) data['price'] = mrpMatch.group(1);

    // Extract Expiry
    final expMatch = RegExp(
      r'EXP\s*[:\-]?\s*([0-9]{2}/[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (expMatch != null) data['expiryDate'] = expMatch.group(1);

    // Extract Weight
    final wtMatch = RegExp(
      r'WT\s*[:\-]?\s*([0-9]+(KG|G|ML|L))',
      caseSensitive: false,
    ).firstMatch(text);
    if (wtMatch != null) data['weight'] = wtMatch.group(1);

    return data;
  }
}

import 'package:flutter/material.dart';
import '../screens/super_admin_screen.dart'; // Tokens

class StoreRowCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final String tenantName;

  const StoreRowCard({
    super.key,
    required this.store,
    required this.tenantName,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = store['isActive'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: EnterpriseColors.surfaceGlass,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? EnterpriseColors.borderSubtle
              : const Color(0xFFE53E3E),
          width: isActive ? 1 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storefront,
            color: isActive ? const Color(0xFF00C853) : const Color(0xFFE53E3E),
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store['name'] ?? 'Unknown Store',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  store['branchCode'] ?? 'NO_CODE',
                  style: const TextStyle(
                    color: EnterpriseColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tenantName,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              store['city'] ?? store['address'] ?? 'N/A',
              style: const TextStyle(
                color: EnterpriseColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (isActive ? const Color(0xFF00C853) : const Color(0xFFE53E3E))
                      .withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF00C853)
                    : const Color(0xFFE53E3E),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

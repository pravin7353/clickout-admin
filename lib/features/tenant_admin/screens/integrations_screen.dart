// lib/features/tenant_admin/screens/integrations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';
import '../../auth/auth_provider.dart'; // adminRoleProvider yahi se aata hai

class IntegrationsScreen extends ConsumerStatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen> {
  bool _isGenerating = false;
  bool _showKey = false;

  Future<void> _generateKey(String tenantId) async {
    setState(() => _isGenerating = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateErpApiKey',
      );
      await callable.call();
      if (mounted) {
        setState(() => _showKey = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key generate ho gayi!')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminData = ref.watch(adminRoleProvider).value;
    final String? tenantId = adminData?['tenantId'];
    final textPrimary = context.colors.textPrimary;
    final textSecondary = context.colors.textSecondary;

    if (tenantId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Integrations",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Tally, Busy, ya kisi bhi ERP ko apna sales/audit data pull karne do.",
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tenants')
                    .doc(tenantId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final String? existingKey = data?['erpApiKey'];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.vpn_key,
                            color: context.colors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "ERP API Key",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (existingKey == null)
                        Text(
                          "Abhi tak koi key generate nahi hui.",
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.scaffoldBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _showKey ? existingKey : '•' * 24,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _showKey
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 18,
                                  color: textSecondary,
                                ),
                                onPressed: () =>
                                    setState(() => _showKey = !_showKey),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy,
                                  size: 18,
                                  color: textSecondary,
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: existingKey),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Key copy ho gayi!'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isGenerating
                            ? null
                            : () => _generateKey(tenantId),
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: Text(
                          existingKey == null
                              ? "Generate Key"
                              : "Regenerate Key",
                        ),
                      ),
                      if (existingKey != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "⚠️ Regenerate karne pe purani key kaam karna band kar degi.",
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Divider(color: context.colors.border),
                      const SizedBox(height: 12),
                      Text(
                        "API Endpoint",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        "GET https://us-central1-clickout-cfa95.cloudfunctions.net/getTenantAuditFeed"
                        "?apiKey=YOUR_KEY&startDate=2026-07-01&endDate=2026-07-31",
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _PartnerModeCard(tenantId: tenantId),
            const SizedBox(height: 20),
            _FailedWebhooksCard(tenantId: tenantId),
          ],
        ),
      ),
    );
  }
}

// ⚡ NEW: "ClickOut Verify — Headless API" partner-mode toggle + config
class _PartnerModeCard extends StatefulWidget {
  final String tenantId;
  const _PartnerModeCard({required this.tenantId});

  @override
  State<_PartnerModeCard> createState() => _PartnerModeCardState();
}

class _PartnerModeCardState extends State<_PartnerModeCard> {
  final _urlController = TextEditingController();
  bool _isSaving = false;
  bool _showSecret = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save(bool enabled) async {
    if (enabled && !_urlController.text.trim().startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid https:// webhook URL daaliye.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'configurePartnerMode',
      );
      await callable.call({
        'enabled': enabled,
        'webhookUrl': _urlController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Partner Mode ON ho gaya!'
                  : 'Partner Mode OFF ho gaya.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.colors.textPrimary;
    final textSecondary = context.colors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tenants')
            .doc(widget.tenantId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final partnerMode = data?['partnerMode'] as Map<String, dynamic>?;
          final bool enabled = partnerMode?['enabled'] == true;
          final String? webhookSecret = partnerMode?['webhookSecret'];

          if (_urlController.text.isEmpty &&
              partnerMode?['webhookUrl'] != null) {
            _urlController.text = partnerMode!['webhookUrl'];
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hub, color: context.colors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "ClickOut Verify — Headless API (Partner Mode)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: _isSaving ? null : (val) => _save(val),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Enterprise chains (jaise DMart) jo sirf Customer+Cashier+Guard use karte hain, "
                "apna backend real-time events yahaan receive kar sakta hai.",
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Webhook URL (https://...)',
                  labelStyle: TextStyle(color: textSecondary, fontSize: 12),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (webhookSecret != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showSecret
                            ? "Secret: $webhookSecret"
                            : "Secret: ${'•' * 20}",
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showSecret ? Icons.visibility_off : Icons.visibility,
                        size: 16,
                        color: textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _showSecret = !_showSecret),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, size: 16, color: textSecondary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: webhookSecret));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Secret copy ho gaya!')),
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  "Ye secret HMAC-SHA256 se X-ClickOut-Signature header sign karta hai — apne server pe verify karo.",
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: _isSaving ? null : () => _save(true),
                child: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save & Enable"),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ⚡ NEW: Failed webhook deliveries + manual resend
class _FailedWebhooksCard extends StatelessWidget {
  final String tenantId;
  const _FailedWebhooksCard({required this.tenantId});

  Future<void> _resend(BuildContext context, String deliveryId) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'resendWebhookDelivery',
      );
      await callable.call({'deliveryId': deliveryId});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Resend attempt hua — thodi der mein status check karo.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.colors.textPrimary;
    final textSecondary = context.colors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Failed Webhook Deliveries",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('webhook_deliveries')
                .where('tenantId', isEqualTo: tenantId)
                .where('status', isEqualTo: 'FAILED')
                .orderBy('failedAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Text(
                  "Koi failed delivery nahi hai 🎉",
                  style: TextStyle(fontSize: 13, color: textSecondary),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${d['eventType']}",
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "${d['error'] ?? 'HTTP ${d['httpStatus']}'}",
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _resend(context, doc.id),
                          child: const Text("Resend"),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

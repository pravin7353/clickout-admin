import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🚀 Added for State persistence
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 Added for Tenant Context

// ── SIMULATOR DATA MODEL ──
class SimulatorPhase {
  final String id;
  final String title;
  final String explanation;
  final String coachMessage;
  final IconData scenarioIcon;
  final List<String> features;
  final double completionImpact;
  final Color themeColor;

  SimulatorPhase({
    required this.id,
    required this.title,
    required this.explanation,
    required this.coachMessage,
    required this.scenarioIcon,
    required this.features,
    required this.completionImpact,
    required this.themeColor,
  });
}

class RetailSimulatorScreen extends ConsumerStatefulWidget {
  const RetailSimulatorScreen({super.key});

  @override
  ConsumerState<RetailSimulatorScreen> createState() =>
      _RetailSimulatorScreenState();
}

class _RetailSimulatorScreenState extends ConsumerState<RetailSimulatorScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  double _readinessScore = 0.0;
  bool _isCoachExpanded = true;

  // 🧠 THE RETAIL JOURNEY ARCHITECTURE
  final List<SimulatorPhase> _phases = [
    SimulatorPhase(
      id: 'tenant',
      title: 'Tenant Activation',
      explanation:
          'Your Tenant is your master retail identity. It commands all stores, global staff, and master analytics. Think of it as your HQ.',
      coachMessage:
          'Welcome to ClickOut. Let\'s establish your Retail HQ. This is where your global command begins.',
      scenarioIcon: Icons.domain,
      features: ['Hierarchy Setup', 'Org Structure', 'Role Isolation'],
      completionImpact: 10.0,
      themeColor: const Color(0xFF7F77DD), // Global Command Purple
    ),
    SimulatorPhase(
      id: 'store',
      title: 'Store Ecosystem',
      explanation:
          'Stores are your operational nodes. Each store acts as an independent nervous system reporting back to HQ.',
      coachMessage:
          'Let\'s drop your first pin on the map. Stores handle live inventory, cashiers, and guards.',
      scenarioIcon: Icons.storefront_outlined,
      features: ['Branch Setup', 'Location Intelligence', 'Store Hierarchy'],
      completionImpact: 15.0,
      themeColor: const Color(0xFF00C853), // Emerald
    ),
    SimulatorPhase(
      id: 'staff',
      title: 'Staff Intelligence',
      explanation:
          'Cashiers bill. Guards validate. Auditors track. Staff roles in ClickOut create an interconnected web of accountability.',
      coachMessage:
          'Retail is nothing without people. Let\'s assign roles and see how they interact in real-time.',
      scenarioIcon: Icons.badge_outlined,
      features: ['Manager Hub', 'Guard Validation', 'Auditor Surveillance'],
      completionImpact: 15.0,
      themeColor: const Color(0xFFEF9F27), // Staff Orange
    ),
    SimulatorPhase(
      id: 'idt',
      title: 'IDT Deposit Cinematic',
      explanation:
          'A truck arrives. Barcodes are scanned. OCR extracts expiry dates. Physical boxes instantly become live digital inventory.',
      coachMessage:
          'Watch closely. This is how we convert physical warehouse stock into digital assets in seconds.',
      scenarioIcon: Icons.inventory_2_outlined,
      features: ['Barcode Intake', 'OCR Extraction', 'GST Validation'],
      completionImpact: 20.0,
      themeColor: const Color(0xFF378ADD), // Operations Blue
    ),
    SimulatorPhase(
      id: 'radar',
      title: 'Growth Radar',
      explanation:
          'Live heatmaps of your store. See ghost visitors who walked out, and VIPs who buy daily. Deploy smart offers instantly.',
      coachMessage:
          'Data is money. Let\'s look at live customer movement and trigger a flash sale.',
      scenarioIcon: Icons.radar,
      features: ['Live Shoppers', 'VIP Tracking', 'Behavioral AI'],
      completionImpact: 20.0,
      themeColor: const Color(0xFFE24B4A), // Risk Red
    ),
    SimulatorPhase(
      id: 'auditor',
      title: 'Super Auditor',
      explanation:
          'FBI meets Chartered Accountant. Track every missing rupee, refund anomaly, and perform live Order Autopsies.',
      coachMessage:
          'Time to lock down your revenue. No leakage goes unnoticed under the Super Auditor.',
      scenarioIcon: Icons.policy_outlined,
      features: ['Order Autopsy', 'Leakage Detection', 'Cash Reconciliation'],
      completionImpact: 20.0,
      themeColor: const Color(0xFFE53E3E), // Audit Red
    ),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _updateScore(0));
  }

  void _updateScore(int index) {
    double score = 0;
    for (int i = 0; i <= index; i++) {
      score += _phases[i].completionImpact;
    }
    setState(() {
      _currentIndex = index;
      _readinessScore = score;
      _isCoachExpanded = true; // Auto-expand coach on new step
    });
  }

  void _nextPhase() async {
    if (_currentIndex < _phases.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      // 🚀 DATABASE UNLOCK: Current tenant ka onboarding status true mark karo
      final adminData = ref.read(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];

      if (tenantId != null && tenantId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('tenants')
              .doc(tenantId)
              .update({'isOnboardingComplete': true});
        } catch (e) {
          debugPrint("Failed to update onboarding state: $e");
        }
      }

      if (mounted) {
        // 🚀 CLEAR AUTH CACHE TO PREVENT ROUTE LOOP
        ref.invalidate(adminRoleProvider);

        final adminData = ref.read(adminRoleProvider).value;
        final tId = adminData?['tenantId'];

        if (tId != null && tId.isNotEmpty) {
          context.go('/tenant-dashboard/$tId');
        } else {
          context.go('/');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? const Color(0xFF080B08) : const Color(0xFFF8FAFC);
    final text1 = isDark ? Colors.white : const Color(0xFF111111);

    return Scaffold(
      backgroundColor: bgCol,
      body: Stack(
        children: [
          // ── BACKGROUND ANIMATIONS ──
          AnimatedPositioned(
            duration: const Duration(seconds: 1),
            top: -100,
            right: _currentIndex % 2 == 0 ? -100 : null,
            left: _currentIndex % 2 != 0 ? -100 : null,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _phases[_currentIndex].themeColor.withValues(alpha: 0.05),
                backgroundBlendMode: BlendMode.screen,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildReadinessHeader(text1, isDark),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // Locked, driven by buttons
                    onPageChanged: _updateScore,
                    itemCount: _phases.length,
                    itemBuilder: (context, index) {
                      return _buildCinematicPhase(
                        _phases[index],
                        isDark,
                        text1,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── FLOATING AI COACH ──
          _buildAICoach(),
        ],
      ),
    );
  }

  // ── HEADER: READINESS SCORE ──
  Widget _buildReadinessHeader(Color text1, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Row(
        children: [
          if (context.canPop()) // 🚀 UNIVERSAL BACK SUPPORT
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: text1),
                onPressed: () => context.pop(),
                tooltip: 'Back',
              ),
            ),
          Icon(
            Icons.rocket_launch_rounded,
            color: _phases[_currentIndex].themeColor,
          ),
          const SizedBox(width: 10),
          Text(
            "Retail OS Initialization",
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: text1,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Operational Readiness: ${_readinessScore.toInt()}%",
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: text1,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _readinessScore / 100,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _phases[_currentIndex].themeColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── MAIN CINEMATIC VIEW ──
  Widget _buildCinematicPhase(SimulatorPhase phase, bool isDark, Color text1) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: phase.themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "STEP ${_currentIndex + 1} OF ${_phases.length}",
                style: TextStyle(
                  color: phase.themeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              phase.title,
              style: GoogleFonts.syne(
                fontSize: isMobile ? 36 : 48,
                fontWeight: FontWeight.w800,
                color: text1,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              phase.explanation,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: phase.features
                  .map((f) => _buildFeatureChip(f, phase.themeColor, isDark))
                  .toList(),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: text1,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _nextPhase,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentIndex == _phases.length - 1
                        ? "LAUNCH ECOSYSTEM"
                        : "ACTIVATE MODULE",
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        );

        Widget visualization = AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: Container(
            key: ValueKey(phase.id),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  phase.themeColor.withValues(alpha: 0.2),
                  phase.themeColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: phase.themeColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Icon(
                phase.scenarioIcon,
                size: isMobile ? 120 : 180,
                color: phase.themeColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        );

        if (isMobile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: visualization,
                ),
                const SizedBox(height: 40),
                content,
                const SizedBox(height: 120), // Space for Coach
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: Row(
            children: [
              Expanded(flex: 5, child: content),
              const SizedBox(width: 60),
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: visualization,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureChip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111811) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── THE AI BUSINESS COACH ──
  Widget _buildAICoach() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      bottom: 30,
      right: _isCoachExpanded ? 30 : -250, // Slides in/out
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: GestureDetector(
            onTap: () => setState(() => _isCoachExpanded = !_isCoachExpanded),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _phases[_currentIndex].themeColor.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _phases[_currentIndex].themeColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: _phases[_currentIndex].themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ClickOut Coach",
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _phases[_currentIndex].themeColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _phases[_currentIndex].coachMessage,
                            key: ValueKey(_currentIndex),
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              height: 1.4,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

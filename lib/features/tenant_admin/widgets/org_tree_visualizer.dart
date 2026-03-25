import 'package:flutter/material.dart';
import '../providers/org_provider.dart';

class OrgTreeVisualizer extends StatefulWidget {
  final List<CustomRole> roles;
  const OrgTreeVisualizer({super.key, required this.roles});

  @override
  State<OrgTreeVisualizer> createState() => _OrgTreeVisualizerState();
}

class _OrgTreeVisualizerState extends State<OrgTreeVisualizer> {
  final Set<String> _expandedNodes = {};
  late Map<String?, List<CustomRole>> _childrenMap;
  List<CustomRole> _rootNodes = [];

  @override
  void initState() {
    super.initState();
    _buildTreeData();
  }

  @override
  void didUpdateWidget(covariant OrgTreeVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildTreeData();
  }

  void _buildTreeData() {
    _childrenMap = {};
    for (var role in widget.roles) {
      _childrenMap[role.reportsTo] = (_childrenMap[role.reportsTo] ?? [])
        ..add(role);
    }
    final allIds = widget.roles.map((e) => e.id).toSet();
    _rootNodes = widget.roles
        .where((r) => r.reportsTo == null || !allIds.contains(r.reportsTo))
        .toList();
    _rootNodes.sort((a, b) => a.level.compareTo(b.level));

    // Auto-expand only the top boss initially
    if (_rootNodes.isNotEmpty) {
      _expandedNodes.add(_rootNodes.first.id);
    }
  }

  // 🌟 THE MAGIC HIERARCHY COLOR GENERATOR (CTO's Premium Palette)
  Color _getLevelColor(int level, {bool forText = false}) {
    final List<Color> palette = [
      const Color(0xFF2B3674), // L1: Navy
      const Color(0xFF6366F1), // L2: Indigo
      const Color(0xFF10B981), // L3: Green (Success hue)
      const Color(0xFFF59E0B), // L4: Amber (Warning hue)
      const Color(0xFF14B8A6), // L5: Teal
      const Color(0xFF0EA5E9), // L6+: Sky Blue
    ];
    // Loop palette if level > palette length
    final Color baseColor = palette[(level - 1) % palette.length];

    // Use modulo for infinite looping without crashing
    return forText ? baseColor : baseColor.withValues(alpha: 0.1);
  }

  Widget _buildNode(CustomRole role, int depth) {
    final children = _childrenMap[role.id] ?? [];
    children.sort((a, b) => a.level.compareTo(b.level));
    final isExpanded = _expandedNodes.contains(role.id);
    final hasChildren = children.isNotEmpty;

    // 🎨 Get dynamic level colors
    final levelTextColor = _getLevelColor(role.level, forText: true);
    final levelBgColor = _getLevelColor(role.level, forText: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            left: depth * 40.0,
            top: 8,
            bottom: 8,
          ), // Perfect Indentation
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔀 Connecting Line indicator
              if (depth > 0)
                Container(
                  width: 24,
                  height: 35,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Colors.blueGrey.shade300,
                        width: 2,
                      ),
                      bottom: BorderSide(
                        color: Colors.blueGrey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                ),

              // 🚀 FIXED WIDTH CARD (Pre-vets Overflow Issues)
              SizedBox(
                width: 330, // Slightly wider to look premium
                child: InkWell(
                  onTap: hasChildren
                      ? () {
                          setState(() {
                            isExpanded
                                ? _expandedNodes.remove(role.id)
                                : _expandedNodes.add(role.id);
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hasChildren
                          ? Colors.white
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasChildren
                            ? (isExpanded
                                  ? levelTextColor
                                  : Colors
                                        .blueGrey
                                        .shade200) // Dynamic border on expand
                            : Colors.grey.shade200,
                        width: isExpanded ? 1.5 : 1.0,
                      ),
                      boxShadow: hasChildren
                          ? [
                              BoxShadow(
                                color: levelTextColor.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [], // Soft shadow in accent color
                    ),
                    child: Row(
                      children: [
                        // RANK BADGE (Dynamic Color Applied 🎨)
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: levelBgColor, // Dynamic Background
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: levelTextColor.withValues(alpha: 0.15),
                              width: 1,
                            ), // Soft border in hue
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "L${role.level}",
                            style: TextStyle(
                              color: levelTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ), // Dynamic Text
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role.roleName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFF2B3674),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Tag Prefix: ${role.tagPrefix}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey.shade400,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasChildren) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2B3674,
                              ).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${children.length}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B3674),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: levelTextColor,
                            size: 24,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 🔄 RENDER CHILDREN (With Left Border Line)
        if (isExpanded && hasChildren)
          Container(
            margin: EdgeInsets.only(left: (depth * 40.0) + 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: levelTextColor.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
            ), // Subtle dynamic connector
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children
                  .map((child) => _buildNode(child, depth + 1))
                  .toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_rootNodes.isEmpty) {
      return const Center(
        child: Text(
          "No hierarchy found.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // 🌐 INFINITE CANVAS ENGINE
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(300), // Gives more pan space
        minScale: 0.4,
        maxScale: 1.5,
        child: Padding(
          padding: const EdgeInsets.all(
            50.0,
          ), // Outer buffer for better scrolling
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _rootNodes.map((root) => _buildNode(root, 0)).toList(),
          ),
        ),
      ),
    );
  }
}

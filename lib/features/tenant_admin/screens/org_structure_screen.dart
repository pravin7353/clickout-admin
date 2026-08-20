import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/org_provider.dart';
import '../widgets/add_role_dialog.dart';
import '../widgets/edit_role_dialog.dart';
import '../widgets/org_tree_visualizer.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class OrgStructureScreen extends ConsumerStatefulWidget {
  const OrgStructureScreen({super.key});

  @override
  ConsumerState<OrgStructureScreen> createState() => _OrgStructureScreenState();
}

class _OrgStructureScreenState extends ConsumerState<OrgStructureScreen> {
  bool _isTreeView = false;

  @override
  Widget build(BuildContext context) {
    final rolesState = ref.watch(orgStructureProvider);
    final notifier = ref.read(orgStructureProvider.notifier);

    final theme = Theme.of(context);
    final textPrimary = context.colors.textPrimary;
    final textSecondary = context.colors.textSecondary;
    final cardColor = context.colors.cardBg;

    Color getLevelColor(int level) {
      if (level == 1) return const Color(0xFFEF9F27);
      if (level < 5) return const Color(0xFF378ADD);
      return const Color(0xFF7F77DD);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER (Responsive, No Emojis, No External Fonts)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 15,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Organization Builder",
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Define custom hierarchy roles and access limits.",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: "List View",
                            icon: Icon(
                              Icons.format_list_bulleted,
                              color: !_isTreeView
                                  ? theme.primaryColor
                                  : textSecondary,
                            ),
                            onPressed: () =>
                                setState(() => _isTreeView = false),
                          ),
                          IconButton(
                            tooltip: "Tree View",
                            icon: Icon(
                              Icons.account_tree_outlined,
                              color: _isTreeView
                                  ? theme.primaryColor
                                  : textSecondary,
                            ),
                            onPressed: () => setState(() => _isTreeView = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.add_moderator,
                        color: Colors.black,
                      ),
                      label: const Text(
                        "Add Custom Role",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const AddRoleDialog(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // CONTENT AREA
            Expanded(
              child: rolesState.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                ),
                error: (err, _) => Text(
                  "Error loading structure: $err",
                  style: const TextStyle(color: Colors.redAccent),
                ),
                data: (roles) {
                  if (roles.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          "Organization is clean. Add your first custom role to begin structure.",
                          style: TextStyle(color: textSecondary, fontSize: 16),
                        ),
                      ),
                    );
                  }

                  if (_isTreeView) {
                    return OrgTreeVisualizer(roles: roles);
                  }

                  final sortedRoles = [...roles];
                  sortedRoles.sort((a, b) => a.level.compareTo(b.level));

                  return SingleChildScrollView(
                    child: Column(
                      children: sortedRoles
                          .map(
                            (role) => _buildRoleCard(
                              role,
                              notifier,
                              getLevelColor(role.level),
                              textPrimary,
                              textSecondary,
                              cardColor,
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    CustomRole role,
    OrgStructureNotifier notifier,
    Color levelColor,
    Color? textPrimary,
    Color? textSecondary,
    Color cardColor,
  ) {
    bool canModify =
        !role.roleName.contains('Admin') && !role.roleName.contains('Manager');

    return MouseRegion(
      cursor: canModify
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: levelColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: levelColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 8,
                decoration: BoxDecoration(
                  color: levelColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 24),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.roleName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: levelColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: levelColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          "TAG: ${role.tagPrefix.toUpperCase()}",
                          style: TextStyle(
                            color: levelColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Tooltip(
                message: "Hierarchy Level ${role.level}. (L1 is entry)",
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "LEVEL",
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        "L${role.level}",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: levelColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (canModify)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.blueAccent,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => EditRoleDialog(role: role),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF111811),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text(
                                "Delete Role?",
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                "Are you sure you want to delete ${role.roleName}? This cannot be undone.",
                                style: TextStyle(color: Colors.grey),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await notifier.deleteCustomRole(role.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Role Deleted"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 24.0),
                  child: Tooltip(
                    message: 'SaaS Rule: Default roles are read-only.',
                    child: Icon(
                      Icons.lock_outline,
                      color: textSecondary,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

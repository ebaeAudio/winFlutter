import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/admin.dart';
import '../../app/errors.dart';
import '../../app/supabase.dart';
import '../../data/admin/admin_feedback_repository.dart';
import '../../data/admin/admin_user_repository.dart';
import '../../features/feedback/feedback_models.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';

final adminFeedbackRepositoryProvider = Provider<AdminFeedbackRepository?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final client = supabase.client;
  if (client == null) return null;
  return AdminFeedbackRepository(client);
});

final adminFeedbackListProvider = FutureProvider.autoDispose<List<UserFeedback>>((ref) async {
  final repository = ref.watch(adminFeedbackRepositoryProvider);
  if (repository == null) {
    throw StateError('Admin feedback repository not available');
  }

  try {
    return await repository.listAll();
  } catch (e) {
    // If user is not admin, RLS will block access
    if (e.toString().contains('permission denied') ||
        e.toString().contains('row-level security')) {
      throw StateError('Access denied. Admin privileges required.');
    }
    // If the table doesn't exist, provide helpful error
    if (e.toString().contains('does not exist') || 
        e.toString().contains('relation') && e.toString().contains('not found')) {
      throw StateError('The user_feedback table is missing. Make sure all migrations are applied.');
    }
    rethrow;
  }
});

final adminUserRepositoryProvider = Provider<AdminUserRepository?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final client = supabase.client;
  if (client == null) return null;
  return AdminUserRepository(client);
});

final adminUserListProvider = FutureProvider.autoDispose<List<AdminUser>>((ref) async {
  final repository = ref.watch(adminUserRepositoryProvider);
  if (repository == null) {
    throw StateError('Admin user repository not available');
  }

  try {
    return await repository.listUsers();
  } catch (e) {
    // If user is not admin, RLS will block access
    if (e.toString().contains('permission denied') ||
        e.toString().contains('row-level security') ||
        e.toString().contains('Access denied')) {
      throw StateError('Access denied. Admin privileges required.');
    }
    // If the function doesn't exist, provide helpful error
    if (e.toString().contains('function') && 
        (e.toString().contains('does not exist') || e.toString().contains('not found'))) {
      throw StateError('The admin_list_users() function is missing. Apply the migration in supabase/migrations/20260116_000001_admin_user_management.sql');
    }
    rethrow;
  }
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final feedbackAsync = ref.watch(adminFeedbackListProvider);
    final usersAsync = ref.watch(adminUserListProvider);

    return AppScaffold(
      title: 'Admin Dashboard',
      children: [
        // Check admin status
        isAdminAsync.when(
          data: (isAdmin) {
            if (isAdmin != true) {
              return _buildAccessDenied(context);
            }
            return const SizedBox.shrink();
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildError(context, error),
        ),

        // Show user management and feedback list if admin
        if (isAdminAsync.valueOrNull == true) ...[
          // User Management Section
          const SectionHeader(title: 'User Management'),
          Gap.h8,
          _UserManagementSection(usersAsync: usersAsync),
          Gap.h24,

          // Feedback Section
          const SectionHeader(title: 'Bug Complaints & Feedback'),
          Gap.h8,
          feedbackAsync.when(
            data: (feedbackList) {
              if (feedbackList.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s16),
                    child: Text(
                      'No feedback yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              }

              // Group by kind
              final bugs = feedbackList.where((f) => f.kind == FeedbackKind.bug).toList();
              final improvements =
                  feedbackList.where((f) => f.kind == FeedbackKind.improvement).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bugs.isNotEmpty) ...[
                    _buildFeedbackSection(context, 'Bug Reports', bugs),
                    Gap.h16,
                  ],
                  if (improvements.isNotEmpty) ...[
                    _buildFeedbackSection(context, 'Improvement Ideas', improvements),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildError(context, error),
          ),
        ],
      ],
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access Denied',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            Gap.h8,
            Text(
              'Admin privileges required to access this dashboard.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            Gap.h8,
            Text(
              friendlyError(error),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Gap.h12,
            TextButton.icon(
              onPressed: () => showErrorDialog(context, error: error),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('Show details'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection(
    BuildContext context,
    String title,
    List<UserFeedback> feedbackList,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          trailing: Chip(
            label: Text('${feedbackList.length}'),
            visualDensity: VisualDensity.compact,
          ),
        ),
        Gap.h8,
        ...feedbackList.map((feedback) {
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpace.s8),
            child: ExpansionTile(
              title: Text(
                feedback.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: AppSpace.s4),
                child: Text(
                  dateFormat.format(feedback.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s16,
                    0,
                    AppSpace.s16,
                    AppSpace.s16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (feedback.details != null && feedback.details!.isNotEmpty) ...[
                        const SectionHeader(title: 'Details'),
                        Text(
                          feedback.details!,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Gap.h12,
                      ],
                      if (feedback.entryPoint != null &&
                          feedback.entryPoint!.isNotEmpty) ...[
                        const SectionHeader(title: 'Entry Point'),
                        Text(
                          feedback.entryPoint!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Gap.h12,
                      ],
                      if (feedback.context != null && feedback.context!.isNotEmpty) ...[
                        const SectionHeader(title: 'Context'),
                        Container(
                          padding: const EdgeInsets.all(AppSpace.s8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatContext(feedback.context!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Gap.h12,
                      ],
                      const SectionHeader(title: 'Metadata'),
                      Text(
                        'User ID: ${feedback.userId.substring(0, 8)}...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Feedback ID: ${feedback.id.substring(0, 8)}...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatContext(Map<String, Object?> context) {
    final buffer = StringBuffer();
    context.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    return buffer.toString().trim();
  }
}

class _UserManagementSection extends ConsumerStatefulWidget {
  const _UserManagementSection({
    required this.usersAsync,
  });

  final AsyncValue<List<AdminUser>> usersAsync;

  @override
  ConsumerState<_UserManagementSection> createState() => _UserManagementSectionState();
}

class _UserManagementSectionState extends ConsumerState<_UserManagementSection> {
  String _searchQuery = '';
  bool _sortNewestFirst = true;

  @override
  Widget build(BuildContext context) {
    return widget.usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Text(
                'No users found.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        // Filter by search query
        final filtered = users.where((user) {
          if (_searchQuery.isEmpty) return true;
          return user.email.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        // Sort by signup date
        filtered.sort((a, b) {
          final comparison = a.createdAt.compareTo(b.createdAt);
          return _sortNewestFirst ? -comparison : comparison;
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and sort controls
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by email...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                Gap.w8,
                IconButton(
                  icon: Icon(_sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward),
                  tooltip: _sortNewestFirst ? 'Newest first' : 'Oldest first',
                  onPressed: () {
                    setState(() {
                      _sortNewestFirst = !_sortNewestFirst;
                    });
                  },
                ),
              ],
            ),
            Gap.h12,
            // User list
            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: Text(
                    'No users found matching "$_searchQuery".',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...filtered.map((user) => _UserListItem(user: user)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildError(context, error),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            Gap.h8,
            Text(
              friendlyError(error),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Gap.h12,
            TextButton.icon(
              onPressed: () => showErrorDialog(context, error: error),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('Show details'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserListItem extends ConsumerStatefulWidget {
  const _UserListItem({required this.user});

  final AdminUser user;

  @override
  ConsumerState<_UserListItem> createState() => _UserListItemState();
}

class _UserListItemState extends ConsumerState<_UserListItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');
    final repository = ref.watch(adminUserRepositoryProvider);
    final currentUserId = repository?.getCurrentUserId();
    final isCurrentUser = currentUserId == widget.user.userId;
    final canRevoke = widget.user.isAdmin && !isCurrentUser;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.s8),
      child: ExpansionTile(
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.user.email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.user.isAdmin)
              Chip(
                label: const Text('Admin'),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: Text(
            'Signed up ${dateFormat.format(widget.user.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: widget.user.isAdmin
            ? (canRevoke
                ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Revoke admin access',
                    onPressed: () => _showRevokeDialog(context, ref),
                  )
            : const IconButton(
                icon: Icon(Icons.info_outline),
                tooltip: 'You cannot revoke your own admin access',
                onPressed: null,
              ))
            : IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Grant admin access',
                onPressed: () => _showGrantDialog(context, ref),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              0,
              AppSpace.s16,
              AppSpace.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Account Details'),
                Text(
                  'Email: ${widget.user.email}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'User ID: ${widget.user.userId.substring(0, 8)}...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Signup date: ${dateFormat.format(widget.user.createdAt)} at ${timeFormat.format(widget.user.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.user.isAdmin) ...[
                  Gap.h12,
                  const SectionHeader(title: 'Admin Access'),
                  if (widget.user.adminGrantedAt != null)
                    Text(
                      'Granted: ${dateFormat.format(widget.user.adminGrantedAt!)} at ${timeFormat.format(widget.user.adminGrantedAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Text(
                      'Granted: Unknown',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (widget.user.adminGrantedBy != null)
                    Text(
                      'Granted by: ${widget.user.adminGrantedBy!.substring(0, 8)}...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGrantDialog(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(adminUserRepositoryProvider);
    if (repository == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant Admin Access'),
        content: Text('Grant admin access to ${widget.user.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await repository.grantAdminAccess(widget.user.userId);
      if (!context.mounted) return;

      // Refresh the user list
      ref.invalidate(adminUserListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin access granted to ${widget.user.email}'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showErrorDialog(
        context,
        title: 'Failed to grant admin access',
        error: e,
      );
    }
  }

  Future<void> _showRevokeDialog(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(adminUserRepositoryProvider);
    if (repository == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Admin Access'),
        content: Text(
          'Revoke admin access from ${widget.user.email}? They will lose access to the admin dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await repository.revokeAdminAccess(widget.user.userId);
      if (!context.mounted) return;

      // Refresh the user list
      ref.invalidate(adminUserListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin access revoked from ${widget.user.email}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showErrorDialog(
        context,
        title: 'Failed to revoke admin access',
        error: e,
      );
    }
  }
}

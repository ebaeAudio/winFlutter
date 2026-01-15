import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/admin.dart';
import '../../app/errors.dart';
import '../../app/supabase.dart';
import '../../data/admin/admin_feedback_repository.dart';
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
    rethrow;
  }
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final feedbackAsync = ref.watch(adminFeedbackListProvider);

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

        // Show feedback list if admin
        if (isAdminAsync.valueOrNull == true) ...[
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

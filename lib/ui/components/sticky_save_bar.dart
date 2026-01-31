import 'package:flutter/material.dart';

import '../spacing.dart';

/// A sticky bottom bar that appears when there are unsaved changes.
///
/// Provides save and discard actions with appropriate visual weight.
class StickySaveBar extends StatelessWidget {
  const StickySaveBar({
    super.key,
    required this.hasChanges,
    required this.onSave,
    this.onDiscard,
    this.saving = false,
    this.saveLabel = 'Save',
    this.discardLabel = 'Discard',
  });

  final bool hasChanges;
  final VoidCallback onSave;
  final VoidCallback? onDiscard;
  final bool saving;
  final String saveLabel;
  final String discardLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: hasChanges ? 64 : 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: hasChanges ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s12,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_note,
                size: 20,
                color: scheme.primary,
              ),
              Gap.w8,
              Expanded(
                child: Text(
                  'Unsaved changes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (onDiscard != null) ...[
                TextButton(
                  onPressed: saving ? null : onDiscard,
                  child: Text(discardLabel),
                ),
                Gap.w8,
              ],
              FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(saveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

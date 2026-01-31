import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/notes/notes_providers.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/spacing.dart';

class DailyScratchpadScreen extends ConsumerStatefulWidget {
  const DailyScratchpadScreen({
    super.key,
    this.ymd,
  });

  /// Optional date (YYYY-MM-DD). If not provided, uses today.
  final String? ymd;

  @override
  ConsumerState<DailyScratchpadScreen> createState() =>
      _DailyScratchpadScreenState();
}

class _DailyScratchpadScreenState
    extends ConsumerState<DailyScratchpadScreen> {
  final _contentController = TextEditingController();
  Timer? _saveDebounce;

  var _editMode = true;
  var _dirty = false;
  var _saving = false;
  String? _noteId;

  String get _ymd {
    if (widget.ymd != null) return widget.ymd!;
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  DateTime get _date {
    return DateTime.parse(_ymd);
  }

  String get _friendlyDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDate = DateTime(_date.year, _date.month, _date.day);

    if (noteDate == today) {
      return 'Today';
    } else if (noteDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (_date.year == now.year) {
      return DateFormat('EEEE, MMMM d').format(_date);
    } else {
      return DateFormat('EEEE, MMMM d, yyyy').format(_date);
    }
  }

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _contentController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (_noteId == null) return;
    setState(() => _dirty = true);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 550), _saveNow);
  }

  Future<void> _saveNow() async {
    if (_noteId == null) return;
    if (!_dirty) return;

    final repo = ref.read(notesRepositoryProvider);
    if (repo == null) return;

    setState(() => _saving = true);

    try {
      final note = await repo.getById(_noteId!);
      if (note == null) return;

      final updated = note.copyWith(
        content: _contentController.text,
        updatedAt: DateTime.now(),
      );

      await repo.update(updated);
      if (!mounted) return;

      setState(() {
        _dirty = false;
        _saving = false;
      });

      // Invalidate the daily note provider
      ref.invalidate(dailyNoteProvider(_ymd));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  void _toggleMode() {
    setState(() => _editMode = !_editMode);
  }

  void _wrapSelection(String left, String right) {
    final sel = _contentController.selection;
    final text = _contentController.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final a = start < end ? start : end;
    final b = start < end ? end : start;
    final selected = text.substring(a, b);
    final next = text.replaceRange(a, b, '$left$selected$right');
    _contentController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: selected.isEmpty
            ? (a + left.length)
            : (b + left.length + right.length),
      ),
    );
  }

  void _insertAtLineStart(String prefix) {
    final sel = _contentController.selection;
    final text = _contentController.text;
    final caret = sel.start < 0 ? text.length : sel.start;
    final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
    final next = text.replaceRange(lineStart, lineStart, prefix);
    _contentController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncNote = ref.watch(dailyNoteProvider(_ymd));

    return asyncNote.when(
      data: (note) {
        // Initialize controller if note changed
        if (_noteId != note.id) {
          _noteId = note.id;
          _contentController.text = note.content;
          _dirty = false;
        }

        return AppScaffold(
          title: _friendlyDate,
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_dirty)
              Text(
                'Unsaved…',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Text(
                'Saved',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            IconButton(
              tooltip: _editMode ? 'Preview' : 'Edit',
              onPressed: _toggleMode,
              icon: Icon(_editMode ? Icons.visibility : Icons.edit),
            ),
            IconButton(
              tooltip: 'Open in Today',
              onPressed: () => context.go('/today?ymd=$_ymd'),
              icon: const Icon(Icons.calendar_today),
            ),
          ],
          children: [
            // Date info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s16),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    Gap.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _friendlyDate,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Gap.h4,
                          Text(
                            'Daily scratchpad',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/today?ymd=$_ymd'),
                      child: const Text('View in Today'),
                    ),
                  ],
                ),
              ),
            ),
            Gap.h16,
            if (_editMode) ...[
              _EditorToolbar(
                onBold: () => _wrapSelection('**', '**'),
                onItalic: () => _wrapSelection('_', '_'),
                onCode: () => _wrapSelection('`', '`'),
                onCodeBlock: () => _wrapSelection('\n```\n', '\n```\n'),
                onH1: () => _insertAtLineStart('# '),
                onH2: () => _insertAtLineStart('## '),
                onCheckbox: () => _insertAtLineStart('- [ ] '),
                onWikiLink: () => _wrapSelection('[[', ']]'),
                onLink: () => _wrapSelection('[', '](https://)'),
              ),
              Gap.h12,
            ],
            Expanded(
              child: _editMode
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.s16),
                        child: TextField(
                          controller: _contentController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Capture your thoughts, ideas, and notes for today...',
                          ),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                        ),
                      ),
                    )
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.s16),
                        child: MarkdownBody(
                          data: _contentController.text,
                          selectable: true,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const AppScaffold(
        title: 'Loading...',
        children: [
          Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (error, stack) => AppScaffold(
        title: 'Error',
        children: [
          Center(
            child: Text('Failed to load daily note: $error'),
          ),
        ],
      ),
    );
  }
}

// Reuse the editor toolbar from note_editor_screen
class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.onBold,
    required this.onItalic,
    required this.onCode,
    required this.onCodeBlock,
    required this.onH1,
    required this.onH2,
    required this.onCheckbox,
    required this.onWikiLink,
    required this.onLink,
  });

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onCode;
  final VoidCallback onCodeBlock;
  final VoidCallback onH1;
  final VoidCallback onH2;
  final VoidCallback onCheckbox;
  final VoidCallback onWikiLink;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            _ToolButton(
              tooltip: 'Bold',
              icon: Icons.format_bold,
              onPressed: onBold,
            ),
            _ToolButton(
              tooltip: 'Italic',
              icon: Icons.format_italic,
              onPressed: onItalic,
            ),
            _ToolButton(
              tooltip: 'Inline code',
              icon: Icons.code,
              onPressed: onCode,
            ),
            _ToolButton(
              tooltip: 'Code block',
              icon: Icons.data_object,
              onPressed: onCodeBlock,
            ),
            _ToolButton(
              tooltip: 'Heading 1',
              icon: Icons.title,
              onPressed: onH1,
            ),
            _ToolButton(
              tooltip: 'Heading 2',
              icon: Icons.text_fields,
              onPressed: onH2,
            ),
            _ToolButton(
              tooltip: 'Checkbox',
              icon: Icons.check_box_outlined,
              onPressed: onCheckbox,
            ),
            _ToolButton(
              tooltip: 'Wiki link [[Note]]',
              icon: Icons.link,
              onPressed: onWikiLink,
            ),
            _ToolButton(
              tooltip: 'Markdown link',
              icon: Icons.add_link,
              onPressed: onLink,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}

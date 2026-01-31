import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/notes/note.dart';
import '../../data/notes/notes_providers.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/spacing.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.noteId,
  });

  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  Timer? _saveDebounce;

  var _editMode = true;
  var _dirty = false;
  var _saving = false;
  Note? _currentNote;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (_currentNote == null) return;
    setState(() => _dirty = true);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 550), _saveNow);
  }

  void _onContentChanged() {
    if (_currentNote == null) return;
    setState(() => _dirty = true);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 550), _saveNow);
  }

  Future<void> _saveNow() async {
    if (_currentNote == null) return;
    if (!_dirty) return;

    final repo = ref.read(notesRepositoryProvider);
    if (repo == null) return;

    setState(() => _saving = true);

    try {
      final updated = _currentNote!.copyWith(
        title: _titleController.text.trim(),
        content: _contentController.text,
        updatedAt: DateTime.now(),
      );

      await repo.update(updated);
      if (!mounted) return;

      setState(() {
        _dirty = false;
        _saving = false;
        _currentNote = updated;
      });

      // Invalidate the note provider to refresh
      ref.invalidate(noteProvider(widget.noteId));
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

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = ref.read(notesRepositoryProvider);
    if (repo == null) return;

    try {
      await repo.delete(widget.noteId);
      if (!mounted) return;
      context.go('/settings/notes');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<void> _handlePin() async {
    final repo = ref.read(notesRepositoryProvider);
    if (repo == null) return;

    try {
      await repo.togglePinned(widget.noteId);
      if (!mounted) return;
      ref.invalidate(noteProvider(widget.noteId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_currentNote?.pinned == true ? 'Unpinned' : 'Pinned'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  Future<void> _handleArchive() async {
    final repo = ref.read(notesRepositoryProvider);
    if (repo == null) return;

    try {
      await repo.archive(widget.noteId);
      if (!mounted) return;
      ref.invalidate(noteProvider(widget.noteId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archived')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to archive: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncNote = ref.watch(noteProvider(widget.noteId));

    return asyncNote.when(
      data: (note) {
        if (note == null) {
          return const AppScaffold(
            title: 'Note not found',
            children: [
              Center(child: Text('This note does not exist.')),
            ],
          );
        }

        // Initialize controllers if note changed
        if (_currentNote?.id != note.id) {
          _currentNote = note;
          _titleController.text = note.title;
          _contentController.text = note.content;
          _dirty = false;
        }

        return AppScaffold(
          title: note.title.isEmpty ? 'Untitled' : note.title,
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
              tooltip: note.pinned ? 'Unpin' : 'Pin',
              onPressed: _handlePin,
              icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
            ),
            IconButton(
              tooltip: 'Archive',
              onPressed: _handleArchive,
              icon: const Icon(Icons.archive_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: _handleDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          body: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title field
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Note title',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
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
                                hintText: 'Start writing...',
                              ),
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                            ),
                          ),
                        )
                      : Card(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpace.s16),
                            child: MarkdownBody(
                              data: _contentController.text,
                              selectable: true,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          children: const [],
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
            child: Text('Failed to load note: $error'),
          ),
        ],
      ),
    );
  }
}

// Reuse the editor toolbar from secret_notes_screen
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

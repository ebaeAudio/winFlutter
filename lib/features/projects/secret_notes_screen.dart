import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown/markdown.dart' as md;

import '../../app/theme.dart' show sharedPreferencesProvider;
import '../../ui/app_scaffold.dart';
import '../../ui/spacing.dart';

class SecretNotesScreen extends ConsumerStatefulWidget {
  const SecretNotesScreen({super.key, required this.noteId});

  /// Used for Obsidian-ish wiki-link navigation: `/projects/secret-notes?note=<id>`
  final String? noteId;

  @override
  ConsumerState<SecretNotesScreen> createState() => _SecretNotesScreenState();
}

class _SecretNotesScreenState extends ConsumerState<SecretNotesScreen> {
  static const _seedAssetPath = 'assets/secret_notes.md';
  static const _prefsKeyPrefix = 'secret_notes.md::';

  final _controller = TextEditingController();
  Timer? _saveDebounce;

  var _loading = true;
  var _editMode = true;
  var _dirty = false;
  String? _loadError;

  String get _noteId {
    final id = (widget.noteId ?? 'main').trim();
    return id.isEmpty ? 'main' : id;
  }

  String get _prefsKey => '$_prefsKeyPrefix$_noteId';

  @override
  void initState() {
    super.initState();
    _initLoad();
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant SecretNotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.noteId ?? 'main') != (widget.noteId ?? 'main')) {
      _saveDebounce?.cancel();
      setState(() {
        _loading = true;
        _loadError = null;
        _dirty = false;
      });
      _initLoad();
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_loading) return;
    setState(() => _dirty = true);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 550), _saveNow);
  }

  Future<void> _initLoad() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final existing = prefs.getString(_prefsKey);
      if (existing != null) {
        _controller.text = existing;
      } else {
        // Seed notes:
        // - main: seed from repo asset (nice onboarding)
        // - others: start with a simple title stub
        final seeded = _noteId == 'main'
            ? await rootBundle.loadString(_seedAssetPath)
            : '# $_noteId\n\n';
        _controller.value = TextEditingValue(
          text: seeded,
          selection: TextSelection.collapsed(offset: seeded.length),
        );
        await prefs.setString(_prefsKey, seeded);
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = null;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _saveNow() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_prefsKey, _controller.text);
      if (!mounted) return;
      setState(() => _dirty = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  void _toggleMode() {
    setState(() => _editMode = !_editMode);
  }

  void _wrapSelection(String left, String right) {
    final sel = _controller.selection;
    final text = _controller.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final a = start < end ? start : end;
    final b = start < end ? end : start;
    final selected = text.substring(a, b);
    final next = text.replaceRange(a, b, '$left$selected$right');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: selected.isEmpty
            ? (a + left.length)
            : (b + left.length + right.length),
      ),
    );
  }

  void _insertAtLineStart(String prefix) {
    final sel = _controller.selection;
    final text = _controller.text;
    final caret = sel.start < 0 ? text.length : sel.start;
    final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
    final next = text.replaceRange(lineStart, lineStart, prefix);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret + prefix.length),
    );
  }

  String _withWikiLinks(String raw) {
    // Obsidian-ish: [[Note]] or [[note|Label]] -> Markdown link
    final re = RegExp(r'\[\[([^\]]+)\]\]');
    return raw.replaceAllMapped(re, (m) {
      final inner = (m.group(1) ?? '').trim();
      if (inner.isEmpty) return m.group(0) ?? '';
      final parts = inner.split('|');
      final target = parts.first.trim();
      final label = (parts.length > 1 ? parts.sublist(1).join('|') : target).trim();
      final encoded = Uri.encodeComponent(target);
      return '[$label](app://secret-notes/$encoded)';
    });
  }

  void _onTapLink(String? text, String? href, String title) {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;

    if (uri.scheme == 'app' && uri.host == 'secret-notes') {
      final target = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final decoded = Uri.decodeComponent(target);
      final nextNote = decoded.trim();
      if (nextNote.isEmpty) return;
      context.go('/projects/secret-notes?note=${Uri.encodeComponent(nextNote)}');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final title = _noteId == 'main' ? 'Secret notes' : 'Secret notes: $_noteId';

    return AppScaffold(
      title: title,
      actions: [
        if (!_loading)
          IconButton(
            tooltip: 'New note',
            onPressed: () async {
              final controller = TextEditingController();
              final created = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('New note'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Ex: Ideas, Project X, Weekly review',
                    ),
                    onSubmitted: (_) => Navigator.of(context).pop(
                      controller.text.trim(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        controller.text.trim(),
                      ),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              );
              final noteName = (created ?? '').trim();
              if (noteName.isEmpty) return;
              final prefs = ref.read(sharedPreferencesProvider);
              final key = '$_prefsKeyPrefix$noteName';
              if (!prefs.containsKey(key)) {
                await prefs.setString(key, '# $noteName\n\n');
              }
              if (!context.mounted) return;
              context.go(
                '/projects/secret-notes?note=${Uri.encodeComponent(noteName)}',
              );
            },
            icon: const Icon(Icons.note_add_outlined),
          ),
        if (!_loading) Gap.w8,
        if (!_loading)
          IconButton(
            tooltip: _editMode ? 'Preview' : 'Edit',
            onPressed: _toggleMode,
            icon: Icon(_editMode ? Icons.visibility : Icons.edit),
          ),
      ],
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if ((_loadError ?? '').trim().isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Text(
                'Failed to load notes: $_loadError',
                style: TextStyle(color: scheme.error),
              ),
            ),
          )
        else ...[
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note, color: scheme.primary),
                        Gap.w12,
                        Expanded(
                          child: Text(
                            _dirty ? 'Unsaved…' : 'Saved',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _dirty
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurfaceVariant,
                              fontWeight:
                                  _dirty ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (_dirty)
                          TextButton(
                            onPressed: _saveNow,
                            child: const Text('Save now'),
                          ),
                      ],
                    ),
                    Gap.h12,
                    TextField(
                      controller: _controller,
                      maxLines: null,
                      minLines: 14,
                      decoration: const InputDecoration(
                        labelText: 'Markdown',
                        hintText: 'Write in Markdown…',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Gap.h12,
            Text(
              'Tip: use [[Note]] links (Obsidian-style). Tap them in Preview to navigate.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s16),
                child: SelectionArea(
                  child: MarkdownBody(
                    data: _withWikiLinks(_controller.text),
                    selectable: true,
                    onTapLink: _onTapLink,
                    extensionSet: md.ExtensionSet.gitHubFlavored,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
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
            Container(
              width: 1,
              height: 44,
              color: scheme.outlineVariant,
            ),
            _ToolButton(
              tooltip: 'Preview (top right)',
              icon: Icons.visibility,
              onPressed: null,
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
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: enabled
              ? scheme.surfaceContainerHighest.withOpacity(0.55)
              : scheme.surfaceContainerHighest.withOpacity(0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


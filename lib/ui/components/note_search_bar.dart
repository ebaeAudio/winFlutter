import 'dart:async';

import 'package:flutter/material.dart';

class NoteSearchBar extends StatefulWidget {
  const NoteSearchBar({
    super.key,
    required this.onSearchChanged,
    this.hintText = 'Search notes...',
    this.debounceMs = 300,
  });

  final ValueChanged<String> onSearchChanged;
  final String hintText;
  final int debounceMs;

  @override
  State<NoteSearchBar> createState() => _NoteSearchBarState();
}

class _NoteSearchBarState extends State<NoteSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      Duration(milliseconds: widget.debounceMs),
      () => widget.onSearchChanged(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: 'Search',
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onSearchChanged('');
                },
              )
            : null,
      ),
      onChanged: _onTextChanged,
    );
  }
}

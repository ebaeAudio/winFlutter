import 'package:flutter/material.dart';

import 'spacing.dart';

/// Standard page wrapper:
/// - consistent padding
/// - safe area
/// - centered content with max width on larger screens
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.maxWidth = 720,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.s16),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

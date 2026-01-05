import 'package:flutter/material.dart';

import '../../ui/app_scaffold.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';

class RollupsScreen extends StatefulWidget {
  const RollupsScreen({super.key});

  @override
  State<RollupsScreen> createState() => _RollupsScreenState();
}

class _RollupsScreenState extends State<RollupsScreen> {
  var _range = _RollupRange.week;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Rollups',
      children: [
        const SectionHeader(title: 'Range'),
        SegmentedButton<_RollupRange>(
          segments: const [
            ButtonSegment(value: _RollupRange.week, label: Text('Week')),
            ButtonSegment(value: _RollupRange.month, label: Text('Month')),
            ButtonSegment(value: _RollupRange.year, label: Text('Year')),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() => _range = s.first),
        ),
        Gap.h16,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Text(
              'Scaffold placeholder for ${_range.label}:\n'
              '- Avg % for range + vs previous\n'
              '- Bar chart\n'
              '- Daily breakdown list',
            ),
          ),
        ),
      ],
    );
  }
}

enum _RollupRange { week, month, year }

extension on _RollupRange {
  String get label => switch (this) {
        _RollupRange.week => 'week',
        _RollupRange.month => 'month',
        _RollupRange.year => 'year',
      };
}

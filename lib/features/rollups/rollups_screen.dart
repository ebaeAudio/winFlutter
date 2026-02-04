import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ui/app_scaffold.dart';
import '../../ui/components/empty_state_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';
import 'rollups_controller.dart';

class RollupsScreen extends ConsumerStatefulWidget {
  const RollupsScreen({super.key});

  @override
  ConsumerState<RollupsScreen> createState() => _RollupsScreenState();
}

class _RollupsScreenState extends ConsumerState<RollupsScreen> {
  var _range = RollupRange.week;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rollupsProvider(_range));

    return AppScaffold(
      title: 'Rollups',
      children: [
        const SectionHeader(title: 'Range'),
        SegmentedButton<RollupRange>(
          segments: const [
            ButtonSegment(value: RollupRange.week, label: Text('Week')),
            ButtonSegment(value: RollupRange.month, label: Text('Month')),
            ButtonSegment(value: RollupRange.year, label: Text('Year')),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() => _range = s.first),
        ),
        Gap.h16,
        async.when(
          data: (data) => _RollupsBody(data: data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Couldn’t load rollups',
                      style: Theme.of(context).textTheme.titleMedium,),
                  Gap.h8,
                  Text('$e', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RollupsBody extends StatelessWidget {
  const _RollupsBody({required this.data});

  final RollupsData data;

  @override
  Widget build(BuildContext context) {
    final hasAnyActivity = data.breakdown.any((d) =>
        d.mustWinTotal > 0 || d.niceToDoTotal > 0 || d.habitsTotal > 0,);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RollupSummaryCard(data: data),
        Gap.h16,
        const SectionHeader(title: 'Chart'),
        _RollupBarChart(
          values: data.chartValues,
          labels: data.chartLabels,
        ),
        Gap.h16,
        const SectionHeader(title: 'Daily breakdown'),
        if (!hasAnyActivity)
          const EmptyStateCard(
            icon: Icons.insights,
            title: 'No activity in this range',
            description:
                'Add a few Must‑Wins, Nice‑to‑Dos, or Habits and your rollups will appear here.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Column(
                children: [
                  for (final d in data.breakdown) _RollupDayTile(day: d),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RollupSummaryCard extends StatelessWidget {
  const _RollupSummaryCard({required this.data});
  final RollupsData data;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(data.window.startYmd);
    final end = DateTime.tryParse(data.window.endYmd);
    final rangeLabel = (start != null && end != null)
        ? '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}'
        : '${data.window.startYmd} – ${data.window.endYmd}';

    final delta = data.deltaPercent;
    final deltaText = delta == 0 ? '±0' : (delta > 0 ? '+$delta' : '$delta');
    final scheme = Theme.of(context).colorScheme;

    final deltaColor = delta > 0
        ? scheme.primary
        : delta < 0
            ? scheme.error
            : scheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data.range.label} average',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Gap.h4,
            Text(rangeLabel, style: Theme.of(context).textTheme.bodySmall),
            Gap.h12,
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${data.averagePercent}%',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Gap.w12,
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'vs prev: $deltaText',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: deltaColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RollupBarChart extends StatelessWidget {
  const _RollupBarChart({required this.values, required this.labels});

  final List<int> values; // 0..100
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const height = 110.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                    child: _Bar(
                      value: values[i],
                      label: (i < labels.length) ? labels[i] : '',
                      fill: scheme.primary,
                      track: scheme.surfaceContainerHighest.withOpacity(0.5),
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

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.label,
    required this.fill,
    required this.track,
  });

  final int value;
  final String label;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100);
    final barHeight = 78.0 * (v / 100.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 78,
                color: track,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: barHeight,
                    color: fill.withOpacity(v == 0 ? 0.25 : 1),
                  ),
                ),
              ),
            ),
          ),
        ),
        Gap.h8,
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _RollupDayTile extends StatelessWidget {
  const _RollupDayTile({required this.day});
  final RollupDayBreakdown day;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(day.ymd);
    final title = dt == null ? day.ymd : DateFormat('EEE, MMM d').format(dt);

    final parts = <String>[];
    if (day.mustWinTotal > 0) {
      parts.add('Must‑Wins ${day.mustWinDone}/${day.mustWinTotal}');
    }
    if (day.niceToDoTotal > 0) {
      parts.add('Nice‑to‑Dos ${day.niceToDoDone}/${day.niceToDoTotal}');
    }
    if (day.habitsTotal > 0) {
      parts.add('Habits ${day.habitsDone}/${day.habitsTotal}');
    }

    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: parts.isEmpty ? const Text('No items') : Text(parts.join(' · ')),
      trailing: Text(
        '${day.percent}%',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

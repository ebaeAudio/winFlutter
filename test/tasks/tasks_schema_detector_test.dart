import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:win_flutter/data/tasks/tasks_schema.dart';
import 'package:win_flutter/data/tasks/tasks_schema_detector.dart';

class _FakeProbe implements TasksSchemaProbe {
  _FakeProbe(this._columns);

  final Map<String, bool> _columns;

  @override
  Future<bool> hasColumn(String columnName) async {
    return _columns[columnName] ?? false;
  }
}

void main() {
  group('TasksSchemaDetector', () {
    test('detect() returns schema based on probe results', () async {
      final client = SupabaseClient('http://localhost', 'anon');
      final schema = await TasksSchemaDetector.detect(
        client,
        probe: _FakeProbe({
          'details': true,
          'goal_date': false,
          'in_progress': true,
          'starter_step': true,
          'estimated_minutes': true,
        }),
      );

      expect(schema.hasDetails, true);
      expect(schema.hasGoalDate, false);
      expect(schema.hasInProgress, true);
      expect(schema.hasStarterStep, true);
      expect(schema.hasEstimatedMinutes, true);
    });
  });

  group('TasksSchema', () {
    test('taskSelectColumns only includes supported columns', () {
      const schema = TasksSchema(
        hasDetails: true,
        hasGoalDate: false,
        hasInProgress: true,
        hasStarterStep: false,
        hasEstimatedMinutes: false,
      );

      expect(schema.taskSelectColumns, contains('details'));
      expect(schema.taskSelectColumns, isNot(contains('goal_date')));
      expect(schema.taskSelectColumns, contains('in_progress'));
      expect(schema.taskSelectColumns, isNot(contains('starter_step')));
      expect(schema.taskSelectColumns, isNot(contains('estimated_minutes')));
    });

    test('allTasksSelectColumns excludes details and focus fields', () {
      const schema = TasksSchema(
        hasDetails: true,
        hasGoalDate: true,
        hasInProgress: true,
        hasStarterStep: true,
        hasEstimatedMinutes: true,
      );

      expect(schema.allTasksSelectColumns, contains('goal_date'));
      expect(schema.allTasksSelectColumns, contains('in_progress'));
      expect(schema.allTasksSelectColumns, isNot(contains('details')));
      expect(schema.allTasksSelectColumns, isNot(contains('starter_step')));
      expect(schema.allTasksSelectColumns, isNot(contains('estimated_minutes')));
    });

    test('filterUpdatePatch removes unsupported optional columns', () {
      const schema = TasksSchema(
        hasDetails: false,
        hasGoalDate: true,
        hasInProgress: true,
        hasStarterStep: false,
        hasEstimatedMinutes: false,
      );

      final filtered = schema.filterUpdatePatch(
        {
          'title': 't',
          'details': 'd',
          'starter_step': 's',
          'estimated_minutes': 5,
          'goal_date': '2026-01-01',
          'in_progress': true,
        },
        attemptedGoalDate: true,
        attemptedInProgress: true,
      );

      expect(filtered.keys, contains('title'));
      expect(filtered.keys, contains('goal_date'));
      expect(filtered.keys, contains('in_progress'));
      expect(filtered.keys, isNot(contains('details')));
      expect(filtered.keys, isNot(contains('starter_step')));
      expect(filtered.keys, isNot(contains('estimated_minutes')));
    });

    test('filterUpdatePatch throws if goal_date is attempted but missing', () {
      const schema = TasksSchema(
        hasDetails: true,
        hasGoalDate: false,
        hasInProgress: true,
        hasStarterStep: true,
        hasEstimatedMinutes: true,
      );

      expect(
        () => schema.filterUpdatePatch(
          {'goal_date': '2026-01-01'},
          attemptedGoalDate: true,
          attemptedInProgress: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('filterUpdatePatch throws if in_progress is attempted but missing', () {
      const schema = TasksSchema(
        hasDetails: true,
        hasGoalDate: true,
        hasInProgress: false,
        hasStarterStep: true,
        hasEstimatedMinutes: true,
      );

      expect(
        () => schema.filterUpdatePatch(
          {'in_progress': true},
          attemptedGoalDate: false,
          attemptedInProgress: true,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}


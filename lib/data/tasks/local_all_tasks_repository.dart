import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/today/today_models.dart';
import 'all_tasks_models.dart';
import 'all_tasks_repository.dart';
import '../paginated_result.dart';
import 'task.dart' as data;

class LocalAllTasksRepository implements AllTasksRepository {
  LocalAllTasksRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _dayPrefix = 'today_day_';

  @override
  Future<PaginatedResult<AllTask>> listAll({
    int limit = 50,
    String? cursor,
  }) async {
    final keys = _prefs.getKeys();
    final tasks = <AllTask>[];

    for (final key in keys) {
      if (!key.startsWith(_dayPrefix)) continue;
      final ymd = key.substring(_dayPrefix.length).trim();
      if (!_looksLikeYmd(ymd)) continue;

      final raw = _prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) continue;

      final day = TodayDayData.fromJsonString(raw, fallbackYmd: ymd);
      for (final t in day.tasks) {
        tasks.add(
          AllTask(
            id: t.id,
            title: t.title,
            type: t.type == TodayTaskType.mustWin
                ? data.TaskType.mustWin
                : data.TaskType.niceToDo,
            ymd: day.ymd.trim().isEmpty ? ymd : day.ymd,
            goalYmd: t.goalYmd,
            completed: t.completed,
            inProgress: t.inProgress,
            createdAtMs: t.createdAtMs,
          ),
        );
      }
    }

    tasks.sort((a, b) {
      final dateCmp = a.ymd.compareTo(b.ymd);
      if (dateCmp != 0) return dateCmp;
      return a.createdAtMs.compareTo(b.createdAtMs);
    });

    final offset = _decodeCursor(cursor);
    final safeLimit = limit < 1 ? 1 : limit;

    if (offset >= tasks.length) {
      return const PaginatedResult(items: [], hasMore: false, nextCursor: null);
    }

    final endExclusive = (offset + safeLimit) > tasks.length
        ? tasks.length
        : (offset + safeLimit);
    final page = tasks.sublist(offset, endExclusive);
    final hasMore = endExclusive < tasks.length;
    final nextCursor = hasMore ? _encodeCursor(endExclusive) : null;
    return PaginatedResult(items: page, hasMore: hasMore, nextCursor: nextCursor);
  }

  static int _decodeCursor(String? cursor) {
    final raw = (cursor ?? '').trim();
    if (raw.isEmpty) return 0;
    try {
      final decoded = utf8.decode(base64Url.decode(raw));
      return int.tryParse(decoded) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static String _encodeCursor(int offset) {
    return base64Url.encode(utf8.encode(offset.toString()));
  }

  @override
  Future<void> setCompleted({
    required String ymd,
    required String taskId,
    required bool completed,
  }) async {
    final key = '$_dayPrefix$ymd';
    final raw = _prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return;

    final day = TodayDayData.fromJsonString(raw, fallbackYmd: ymd);
    final nextTasks = [
      for (final t in day.tasks)
        if (t.id == taskId)
          t.copyWith(completed: completed, inProgress: completed ? false : null)
        else
          t,
    ];
    final nextDay = day.copyWith(
      tasks: nextTasks,
      focusTaskId: day.focusTaskId == taskId ? null : day.focusTaskId,
    );
    await _prefs.setString(key, nextDay.toJsonString());
  }

  @override
  Future<void> setInProgress({
    required String ymd,
    required String taskId,
    required bool inProgress,
  }) async {
    final key = '$_dayPrefix$ymd';
    final raw = _prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return;

    final day = TodayDayData.fromJsonString(raw, fallbackYmd: ymd);
    final nextTasks = [
      for (final t in day.tasks)
        if (t.id == taskId)
          t.copyWith(
            inProgress: inProgress,
            completed: inProgress ? false : null,
          )
        else
          t,
    ];
    final nextDay = day.copyWith(
      tasks: nextTasks,
      focusTaskId: day.focusTaskId == taskId ? null : day.focusTaskId,
    );
    await _prefs.setString(key, nextDay.toJsonString());
  }

  @override
  Future<void> moveToDate({
    required String fromYmd,
    required String toYmd,
    required String taskId,
    required bool resetCompleted,
  }) async {
    if (fromYmd == toYmd) {
      if (resetCompleted) {
        await setCompleted(ymd: fromYmd, taskId: taskId, completed: false);
      }
      return;
    }

    final fromKey = '$_dayPrefix$fromYmd';
    final toKey = '$_dayPrefix$toYmd';

    final fromRaw = _prefs.getString(fromKey);
    final toRaw = _prefs.getString(toKey);

    final fromDay = (fromRaw == null || fromRaw.trim().isEmpty)
        ? TodayDayData.empty(fromYmd)
        : TodayDayData.fromJsonString(fromRaw, fallbackYmd: fromYmd);
    final toDay = (toRaw == null || toRaw.trim().isEmpty)
        ? TodayDayData.empty(toYmd)
        : TodayDayData.fromJsonString(toRaw, fallbackYmd: toYmd);

    TodayTask? moving;
    final nextFromTasks = <TodayTask>[];
    for (final t in fromDay.tasks) {
      if (t.id == taskId) {
        moving = resetCompleted
            ? t.copyWith(completed: false, inProgress: false)
            : t;
      } else {
        nextFromTasks.add(t);
      }
    }
    if (moving == null) return;

    final nextToTasks = [
      ...toDay.tasks.where((t) => t.id != taskId),
      moving,
    ]..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));

    final nextFromDay = fromDay.copyWith(
      tasks: nextFromTasks,
      focusTaskId: fromDay.focusTaskId == taskId ? null : fromDay.focusTaskId,
    );
    final nextToDay = toDay.copyWith(tasks: nextToTasks);

    await _prefs.setString(fromKey, nextFromDay.toJsonString());
    await _prefs.setString(toKey, nextToDay.toJsonString());
  }

  static bool _looksLikeYmd(String raw) {
    // Fast + forgiving: yyyy-mm-dd
    if (raw.length != 10) return false;
    if (raw[4] != '-' || raw[7] != '-') return false;
    final y = int.tryParse(raw.substring(0, 4));
    final m = int.tryParse(raw.substring(5, 7));
    final d = int.tryParse(raw.substring(8, 10));
    if (y == null || m == null || d == null) return false;
    if (m < 1 || m > 12) return false;
    if (d < 1 || d > 31) return false;
    return true;
  }
}

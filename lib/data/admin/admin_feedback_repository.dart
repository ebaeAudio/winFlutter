import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/feedback/feedback_models.dart';

/// Repository for admin to fetch user feedback.
class AdminFeedbackRepository {
  AdminFeedbackRepository(this._client);

  final SupabaseClient _client;

  String _requireUserId() {
    final session = _client.auth.currentSession;
    final uid = session?.user.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthException('Not signed in');
    }
    return uid;
  }

  /// Fetches all user feedback, ordered by most recent first.
  /// Only accessible to admins (enforced by RLS).
  Future<List<UserFeedback>> listAll({
    FeedbackKind? kindFilter,
    int? limit,
  }) async {
    _requireUserId();

    var query = _client
        .from('user_feedback')
        .select('id,user_id,kind,description,details,entry_point,context,created_at');

    if (kindFilter != null) {
      query = query.eq('kind', kindFilter.dbValue);
    }

    final orderedQuery = query.order('created_at', ascending: false);

    final List<Map<String, dynamic>> rows;
    if (limit != null) {
      rows = await orderedQuery.limit(limit);
    } else {
      rows = await orderedQuery;
    }
    final list = rows;

    return [
      for (final row in list)
        UserFeedback.fromDbJson(Map<String, Object?>.from(row as Map)),
    ];
  }

  /// Gets a single feedback item by ID.
  Future<UserFeedback?> getById(String id) async {
    _requireUserId();

    final row = await _client
        .from('user_feedback')
        .select('id,user_id,kind,description,details,entry_point,context,created_at')
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return UserFeedback.fromDbJson(Map<String, Object?>.from(row));
  }
}

/// User feedback model for admin viewing.
class UserFeedback {
  UserFeedback({
    required this.id,
    required this.userId,
    required this.kind,
    required this.description,
    this.details,
    this.entryPoint,
    this.context,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final FeedbackKind kind;
  final String description;
  final String? details;
  final String? entryPoint;
  final Map<String, Object?>? context;
  final DateTime createdAt;

  factory UserFeedback.fromDbJson(Map<String, Object?> json) {
    final kindStr = (json['kind'] as String?) ?? '';
    final kind = FeedbackKind.values.firstWhere(
      (k) => k.dbValue == kindStr,
      orElse: () => FeedbackKind.bug,
    );

    final createdAtStr = (json['created_at'] as String?) ?? '';
    final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

    final contextRaw = json['context'];
    final context = contextRaw is Map<String, Object?> ? contextRaw : null;

    return UserFeedback(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      kind: kind,
      description: (json['description'] as String?) ?? '',
      details: json['details'] as String?,
      entryPoint: json['entry_point'] as String?,
      context: context,
      createdAt: createdAt,
    );
  }
}

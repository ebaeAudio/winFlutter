import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for admin to manage users and their admin privileges.
class AdminUserRepository {
  AdminUserRepository(this._client);

  final SupabaseClient _client;

  String _requireUserId() {
    final session = _client.auth.currentSession;
    final uid = session?.user.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthException('Not signed in');
    }
    return uid;
  }

  /// Lists all users with their admin status.
  /// Only accessible to admins (enforced by RLS and function security).
  Future<List<AdminUser>> listUsers() async {
    _requireUserId();

    try {
      // Use the admin_list_users() function which efficiently joins auth.users with admin_users
      final rows = await _client.rpc<List<dynamic>>('admin_list_users');
      final list = rows;

      return [
        for (final row in list)
          AdminUser.fromDbJson(Map<String, Object?>.from(row as Map)),
      ];
    } catch (e) {
      // If the function doesn't exist, fall back to manual query
      if (e.toString().contains('function') &&
          (e.toString().contains('does not exist') ||
              e.toString().contains('not found'))) {
        // Fallback: query auth.users directly (requires RLS policy on auth.users)
        // This is less efficient but works if the function isn't available
        throw StateError(
          'The admin_list_users() database function is missing. Apply the migration in supabase/migrations/20260116_000001_admin_user_management.sql',
        );
      }
      rethrow;
    }
  }

  /// Grants admin access to a user.
  /// Inserts a row into admin_users with created_by set to current user.
  /// Only accessible to admins (enforced by RLS).
  Future<void> grantAdminAccess(String userId) async {
    final currentUserId = _requireUserId();

    // Check if user is already an admin
    final existing = await _client
        .from('admin_users')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      throw StateError('User already has admin access');
    }

    // Insert with created_by set to current admin
    await _client.from('admin_users').insert({
      'user_id': userId,
      'created_by': currentUserId,
    });
  }

  /// Revokes admin access from a user.
  /// Deletes the row from admin_users.
  /// Only accessible to admins (enforced by RLS).
  /// Prevents self-revocation (caller should check this before calling).
  Future<void> revokeAdminAccess(String userId) async {
    final currentUserId = _requireUserId();

    // Prevent self-revocation
    if (userId == currentUserId) {
      throw StateError('You cannot revoke your own admin access');
    }

    // Check if user is actually an admin
    final existing = await _client
        .from('admin_users')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      throw StateError('User does not have admin access');
    }

    // Delete the admin_users row
    await _client.from('admin_users').delete().eq('user_id', userId);
  }

  /// Gets the current user's ID.
  /// Helper method for UI components.
  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    return session?.user.id;
  }
}

/// User model for admin viewing.
class AdminUser {
  AdminUser({
    required this.userId,
    required this.email,
    required this.createdAt,
    required this.isAdmin,
    this.adminGrantedAt,
    this.adminGrantedBy,
  });

  final String userId;
  final String email;
  final DateTime createdAt;
  final bool isAdmin;
  final DateTime? adminGrantedAt;
  final String? adminGrantedBy;

  factory AdminUser.fromDbJson(Map<String, Object?> json) {
    final createdAtStr = (json['created_at'] as String?) ?? '';
    final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

    final adminGrantedAtStr = json['admin_granted_at'] as String?;
    final adminGrantedAt = adminGrantedAtStr != null
        ? DateTime.tryParse(adminGrantedAtStr)
        : null;

    return AdminUser(
      userId: (json['user_id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      createdAt: createdAt,
      isAdmin: (json['is_admin'] as bool?) ?? false,
      adminGrantedAt: adminGrantedAt,
      adminGrantedBy: json['admin_granted_by'] as String?,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/restriction_engine/restriction_engine.dart';
import 'focus_providers.dart';

final restrictionPermissionsProvider =
    FutureProvider<RestrictionPermissions>((ref) async {
  final engine = ref.read(restrictionEngineProvider);
  return engine.getPermissions();
});



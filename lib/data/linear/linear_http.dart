import 'linear_http_stub.dart'
    if (dart.library.io) 'linear_http_io.dart'
    if (dart.library.html) 'linear_http_web.dart';

/// Minimal cross-platform HTTP helper for Linear GraphQL.
///
/// We keep this local to avoid adding a new dependency.
abstract class LinearHttp {
  Future<LinearHttpResponse> postJson({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  });
}

class LinearHttpResponse {
  const LinearHttpResponse({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
}

LinearHttp createLinearHttp() => createLinearHttpImpl();


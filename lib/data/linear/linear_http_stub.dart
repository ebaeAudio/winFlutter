import 'linear_http.dart';

LinearHttp createLinearHttpImpl() => _UnsupportedLinearHttp();

class _UnsupportedLinearHttp implements LinearHttp {
  @override
  Future<LinearHttpResponse> postJson({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  }) async {
    throw UnsupportedError('Linear HTTP is not supported on this platform.');
  }
}


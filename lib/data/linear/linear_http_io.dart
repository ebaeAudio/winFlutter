import 'dart:convert';
import 'dart:io';

import 'linear_http.dart';

LinearHttp createLinearHttpImpl() => _LinearHttpIo();

class _LinearHttpIo implements LinearHttp {
  @override
  Future<LinearHttpResponse> postJson({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(url);
      headers.forEach((k, v) => req.headers.set(k, v));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(body));
      final resp = await req.close();
      final respBody = await utf8.decoder.bind(resp).join();
      return LinearHttpResponse(statusCode: resp.statusCode, body: respBody);
    } finally {
      client.close(force: true);
    }
  }
}


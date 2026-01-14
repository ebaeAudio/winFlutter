import 'dart:async';
import 'dart:html' as html;

import 'linear_http.dart';

LinearHttp createLinearHttpImpl() => _LinearHttpWeb();

class _LinearHttpWeb implements LinearHttp {
  @override
  Future<LinearHttpResponse> postJson({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  }) async {
    final req = await html.HttpRequest.request(
      url.toString(),
      method: 'POST',
      sendData: body,
      requestHeaders: {
        ...headers,
        'Content-Type': 'application/json',
      },
    );
    final status = req.status ?? 0;
    final respBody = req.responseText ?? '';
    return LinearHttpResponse(statusCode: status, body: respBody);
  }
}


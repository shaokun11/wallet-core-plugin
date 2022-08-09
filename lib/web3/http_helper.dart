import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class HttpHelper {
  static Future<RPCResponse> sendRpc(
      String url, String method, String params) async {
    Random random = Random.secure();
    int randomString = random.nextInt(100000);
    var headers = {'Content-Type': 'application/json'};
    var request = http.Request('POST', Uri.parse(url));
    request.body = json.encode({
      "jsonrpc": "2.0",
      "id": randomString,
      "method": method,
      "params": [params]
    });
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    if (response.statusCode == 200) {
      var res = await response.stream.bytesToString();
      var parse = json.decode(res);
      if (parse["result"] != null) {
        return RPCResponse(1, parse["result"]);
      } else {
        return RPCResponse(-1, parse["error"]["message"]);
      }
    } else {
      return RPCResponse(-2, response.reasonPhrase);
    }
  }
}

class RPCResponse {
  const RPCResponse(this.code, this.result);

  final int code;
  final dynamic result;
}

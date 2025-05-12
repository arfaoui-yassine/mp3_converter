import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ProxyHttpClient extends YoutubeHttpClient {
  final String proxyUrl;
  final http.Client _client = http.Client();

  ProxyHttpClient(this.proxyUrl);

  @override
  Future<String> getString(
    dynamic url, {
    Map<String, String>? headers,
    bool validate = true,
    bool raw = false,
  }) async {
    try {
      final proxiedUrl = Uri.parse('$proxyUrl${url.toString()}');
      final response = await _client.get(proxiedUrl, headers: headers);

      if (validate && response.statusCode != 200) {
        throw Exception('Proxy request failed: ${response.statusCode}');
      }

      return response.body;
    } catch (e) {
      throw Exception('Proxy request error: $e');
    }
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

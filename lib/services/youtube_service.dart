import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:yt_music_player/services/youtube_http_client.dart';

class YouTubeService {
  late YoutubeExplode _yt;
  final List<String> _proxyUrls = [
    'https://cors-anywhere.herokuapp.com/',
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?',
  ];
  int _currentProxyIndex = 0;

  YouTubeService() {
    _initClient();
  }

  void _initClient() {
    _yt = YoutubeExplode(ProxyHttpClient(_proxyUrls[_currentProxyIndex]));
  }

  Future<List<Video>> searchVideos(String query) async {
    try {
      final results = await _yt.search.search(query);
      return results.where((v) => v.duration != null).toList();
    } catch (e) {
      // Rotate proxy on failure
      _currentProxyIndex = (_currentProxyIndex + 1) % _proxyUrls.length;
      _yt.close();
      _initClient();
      throw Exception('Search failed. Trying different proxy... ($e)');
    }
  }

  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      throw Exception('Could not get audio stream: $e');
    }
  }

  void dispose() {
    _yt.close();
  }
}

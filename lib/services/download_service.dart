import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:yt_music_player/models/song_model.dart';
import 'package:hive/hive.dart';

class DownloadService {
  final Dio _dio = Dio();
  final YoutubeExplode _yt = YoutubeExplode();

  Future<Song?> downloadAudio({
    required String videoId,
    required String title,
    required String author,
    required String? thumbnailUrl,
    required void Function(double) onProgress,
  }) async {
    try {
      // Clean filename from invalid characters
      final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]'), '');
      
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$cleanTitle.mp3';

      // Get audio stream URL
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      final audioUrl = audioStream.url.toString();

      // Download file
      await _dio.download(
        audioUrl,
        savePath,
        onReceiveProgress: (received, total) {
          onProgress(received / total);
        },
        options: Options(headers: {
          'Accept': 'audio/*',
        }),
      );

      // Create song model
      final song = Song(
        id: videoId,
        title: cleanTitle,
        artist: author,
        filePath: savePath,
        thumbnailUrl: thumbnailUrl,
      );

      // Save to Hive
      await Hive.box<Song>('music_library').put(videoId, song);
      return song;
    } catch (e) {
      print('Download error: $e');
      return null;
    } finally {
      _yt.close();
    }
  }
}
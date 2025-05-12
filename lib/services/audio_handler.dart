import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:yt_music_player/models/song_model.dart';
import 'package:hive/hive.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  final _musicBox = Hive.box<Song>('music_library');

  AudioPlayerHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    mediaItem.add(null);
    
    _player.currentIndexStream.listen((index) {
      if (index != null && _musicBox.isNotEmpty) {
        final song = _musicBox.getAt(index);
        mediaItem.add(MediaItem(
          id: song?.id ?? '',
          title: song?.title ?? 'Unknown',
          artist: song?.artist ?? 'Unknown',
          artUri: song?.thumbnailUrl != null ? Uri.parse(song!.thumbnailUrl!) : null,
        ));
      }
    });
  }

  Future<void> loadLibrary() async {
    await _playlist.clear();
    await _playlist.addAll(
      _musicBox.values.map((song) => AudioSource.uri(Uri.file(song.filePath))).toList()
    );
  }

  @override
  Future<void> play() => _player.play();
  
  @override
  Future<void> pause() => _player.pause();
  
  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
  final index = _musicBox.values.toList().indexWhere((song) => song.id == mediaId);
  if (index >= 0) {
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }
}

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
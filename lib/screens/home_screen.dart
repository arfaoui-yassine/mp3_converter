import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:yt_music_player/models/song_model.dart';
import 'package:yt_music_player/services/download_service.dart';
import 'package:yt_music_player/services/youtube_service.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const LibraryTab(),
    const SearchTab(),
    const Center(child: Text('Downloads Tab')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YT Music Player')),
      body: Column(
        children: [
          Expanded(child: _screens[_currentIndex]),
          StreamBuilder<MediaItem?>(
            stream: AudioService.currentMediaItemStream,
            builder: (context, snapshot) {
              final mediaItem = snapshot.data;
              if (mediaItem == null) return const SizedBox();
              return Material(
                elevation: 4,
                child: ListTile(
                  leading: mediaItem.artUri != null
                      ? Image.network(mediaItem.artUri.toString(), width: 50, height: 50)
                      : const Icon(Icons.music_note),
                  title: Text(mediaItem.title, overflow: TextOverflow.ellipsis),
                  subtitle: Text(mediaItem.artist ?? 'Unknown', overflow: TextOverflow.ellipsis),
                  trailing: StreamBuilder<PlaybackState>(
                    stream: AudioService.playbackStateStream,
                    builder: (context, snapshot) {
                      final playbackState = snapshot.data;
                      return IconButton(
                        icon: Icon(playbackState?.playing == true ? Icons.pause : Icons.play_arrow),
                        onPressed: playbackState?.playing == true 
                            ? () => AudioService.pause() 
                            : () => AudioService.play(),
                      );
                    },
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const NowPlayingScreen(),
                  )),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.download), label: 'Downloads'),
        ],
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class LibraryTab extends StatefulWidget {
  const LibraryTab({Key? key}) : super(key: key);

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  late final Box<Song> _musicBox;

  @override
  void initState() {
    super.initState();
    _musicBox = Hive.box<Song>('music_library');
    AudioService.customAction('loadLibrary', {});
  }

  @override
  Widget build(BuildContext context) {
    return WatchBoxBuilder(
      box: _musicBox,
      builder: (context, box) {
        if (box.isEmpty) {
          return const Center(child: Text('Your library is empty'));
        }
        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final song = box.getAt(index)!;
            return ListTile(
              leading: song.thumbnailUrl != null
                  ? Image.network(song.thumbnailUrl!, width: 50, height: 50)
                  : const Icon(Icons.music_note),
              title: Text(song.title),
              subtitle: Text(song.artist),
              onTap: () => AudioService.playFromMediaId(song.id),
            );
          },
        );
      },
    );
  }
}

class SearchTab extends StatefulWidget {
  const SearchTab({Key? key}) : super(key: key);

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final YouTubeService _youTubeService = YouTubeService();
  final TextEditingController _searchController = TextEditingController();
  List<Video> _searchResults = [];
  bool _isSearching = false;
  String? _lastError;

  Future<void> _performSearch() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
      _lastError = null;
    });

    try {
      final results = await _youTubeService.searchVideos(_searchController.text);
      setState(() => _searchResults = results);
    } catch (e) {
      setState(() => _lastError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _downloadVideo(Video video) async {
    final downloadService = DownloadService();
    final progressStream = StreamController<double>();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StreamBuilder<double>(
        stream: progressStream.stream,
        builder: (ctx, snapshot) => AlertDialog(
          title: Text('Downloading ${video.title}'),
          content: LinearProgressIndicator(value: snapshot.data ?? 0),
        ),
      ),
    );

    try {
      await downloadService.downloadAudio(
        videoId: video.id.value,
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.mediumResUrl,
        onProgress: (p) => progressStream.add(p),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded ${video.title}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString()}')),
      );
    } finally {
      Navigator.of(context).pop();
      progressStream.close();
    }
  }

  @override
  void dispose() {
    _youTubeService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search YouTube',
              suffixIcon: _isSearching
                  ? const CircularProgressIndicator()
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _performSearch,
                    ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: 16),
          if (_lastError != null)
            Text(
              _lastError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? const Center(child: Text('No results found'))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final video = _searchResults[index];
                          return ListTile(
                            leading: Image.network(
                              video.thumbnails.mediumResUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                            ),
                            title: Text(video.title),
                            subtitle: Text(
                              '${video.author} • ${video.duration?.toString().substring(2, 7) ?? ''}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () => _downloadVideo(video),
                            ),
                            onTap: () => AudioService.playFromMediaId(video.id.value),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<MediaItem?>(
        stream: AudioService.currentMediaItemStream,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;
          if (mediaItem == null) {
            return const Center(child: Text('No media playing'));
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              mediaItem.artUri != null
                  ? Image.network(
                      mediaItem.artUri.toString(),
                      width: 300,
                      height: 300,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 200),
                    )
                  : const Icon(Icons.music_note, size: 200),
              const SizedBox(height: 20),
              Text(
                mediaItem.title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Text(
                mediaItem.artist ?? 'Unknown Artist',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              StreamBuilder<PlaybackState>(
                stream: AudioService.playbackStateStream,
                builder: (context, snapshot) {
                  final playbackState = snapshot.data;
                  final position = playbackState?.position ?? Duration.zero;
                  final duration = mediaItem.duration ?? Duration.zero;
                  
                  return Column(
                    children: [
                      Slider(
                        value: position.inSeconds.toDouble(),
                        max: duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          AudioService.seekTo(Duration(seconds: value.toInt()));
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position)),
                            Text(_formatDuration(duration)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            iconSize: 40,
                            onPressed: AudioService.skipToPrevious,
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: Icon(
                              playbackState?.playing == true 
                                  ? Icons.pause 
                                  : Icons.play_arrow,
                            ),
                            iconSize: 60,
                            onPressed: playbackState?.playing == true
                                ? AudioService.pause
                                : AudioService.play,
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            iconSize: 40,
                            onPressed: AudioService.skipToNext,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
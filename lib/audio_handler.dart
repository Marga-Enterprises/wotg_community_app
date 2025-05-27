import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  MyAudioHandler() {
    _init(); // Setup audio session and listeners
  }

  Future<void> _init() async {
    // Configure audio session for background/lockscreen playback
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());

    // Listen to player state and update playback state for notification/lock screen
    _player.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      final processingState = state.processingState;

      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.rewind,
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
          ],
          androidCompactActionIndices: const [0, 1, 2],
          playing: isPlaying,
          processingState: _mapProcessingState(processingState),
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
        ),
      );
    });
  }

  /// Set the currently playing media item and start playback
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item); // Show info on lockscreen / notification
    await _player.setUrl(item.id); // item.id = audio URL
    await _player.play();
  }

  /// Map JustAudio's ProcessingState to AudioService's AudioProcessingState
  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }

  // Basic control overrides
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  // Optional: for future playlist support
  @override
  Future<void> skipToNext() async {
    // add logic here when using playlists
  }

  @override
  Future<void> skipToPrevious() async {
    // add logic here when using playlists
  }
}

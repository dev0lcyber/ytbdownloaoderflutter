import 'dart:io';
import 'package:youtube_explode_dart_alpha/youtube_explode_dart_alpha.dart';

/// Sanitizes filename by removing invalid characters
String sanitizeFilename(String input) {
  return input.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
}

/// Class to hold video info
class VideoInfoData {
  final String title;
  final String author;
  final String? duration;
  final String thumbnail;

  VideoInfoData({
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnail,
  });
}

/// Downloads the highest-quality audio from a YouTube URL to [outputPath]
/// Calls onProgress with a value between 0.0 and 1.0.
Future<void> downloadYoutubeAudio(
  String videoUrl,
  String outputPath, {
  required void Function(double percent) onProgress,
}) async {
  final yt = YoutubeExplode();

  try {
    final video = await yt.videos.get(videoUrl);
    print('Downloading: ${video.title}');

    final manifest = await yt.videos.streams.getManifest(
      videoUrl,
      ytClients: [
        YoutubeApiClient.ios,
        YoutubeApiClient.androidVr,
      ],
    );

    final audio = manifest.audioOnly.withHighestBitrate();
    if (audio == null) {
      throw Exception('No audio stream found for this video.');
    }

    // Ensure folder exists and open file for writing bytes
    final file = File(outputPath);
    await file.create(recursive: true);
    final fileStream = file.openWrite();

    // Get the stream of bytes
    final stream = yt.videos.streams.get(audio);

    // Total size may be unknown; guard against null
    final totalBytes = audio.size.totalBytes ?? 0;
    int downloaded = 0;

    // If total size is 0 (unknown), we still write but report progress as best-effort
    await for (final chunk in stream) {
      fileStream.add(chunk);
      downloaded += chunk.length;
      if (totalBytes > 0) {
        final progress = downloaded / totalBytes;
        onProgress(progress.clamp(0.0, 1.0));
      } else {
        // Emit a heuristic progress value that slowly increases but never reaches 1.0
        // This avoids infinite 0% while giving UI feedback for unknown sizes.
        final heuristic = (downloaded % 1000000) / 1000000;
        onProgress(heuristic.clamp(0.0, 0.95));
      }
    }

    await fileStream.flush();
    await fileStream.close();

    // Final callback to ensure UI hits 100%
    onProgress(1.0);

    print('✅ Download complete: $outputPath');
  } catch (e) {
    print('❌ Error: $e');
    rethrow;
  } finally {
    yt.close();
  }
}

/// Fetch video info and return as VideoInfoData
Future<VideoInfoData> fetchVideoInfo(String videoUrl) async {
  final yt = YoutubeExplode();
  try {
    final video = await yt.videos.get(videoUrl);
    return VideoInfoData(
      title: video.title,
      author: video.author,
      duration: video.duration?.toString(),
      thumbnail: video.thumbnails.standardResUrl,
    );
  } finally {
    yt.close();
  }
}

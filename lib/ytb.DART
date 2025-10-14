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
Future<void> downloadYoutubeAudio(String videoUrl, String outputPath) async {
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
    final file = File(outputPath);
    await file.create(recursive: true);
    final fileStream = file.openWrite();

    final stream = yt.videos.streams.get(audio);
    await stream.pipe(fileStream);
    await fileStream.flush();
    await fileStream.close();

    print('✅ Download complete: $outputPath');
  } catch (e) {
    print('❌ Error: $e');
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

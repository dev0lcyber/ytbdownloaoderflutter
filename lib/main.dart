import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bot_toast/bot_toast.dart';
import 'ytb.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CupertinoApp(
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver()],
      debugShowCheckedModeBanner: false,
      home: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _permissionGranted = false;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionOnStart();
  }

  Future<void> _requestPermissionOnStart() async {
    PermissionStatus status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    setState(() => _permissionGranted = status.isGranted);
  }

  void _toggleDarkMode(bool value) {
    setState(() => _darkMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'MP3 Downloader for YouTube',
      theme: CupertinoThemeData(
        brightness: _darkMode ? Brightness.dark : Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
      ),
      home:
          _permissionGranted
              ? YtbDownloader(
                darkMode: _darkMode,
                toggleDarkMode: _toggleDarkMode,
              )
              : CupertinoPageScaffold(
                child: Center(
                  child: Text(
                    'Storage permission required to save files in Downloads.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
    );
  }
}

class YtbDownloader extends StatefulWidget {
  final bool darkMode;
  final Function(bool) toggleDarkMode;
  const YtbDownloader({
    super.key,
    required this.darkMode,
    required this.toggleDarkMode,
  });

  @override
  State<YtbDownloader> createState() => _YtbDownloaderState();
}

class _YtbDownloaderState extends State<YtbDownloader> {
  final TextEditingController _urlController = TextEditingController();
  final List<DownloadCard> _downloads = [];
  bool _fetching = false;

  Future<void> _fetchInfo() async {
    if (_urlController.text.trim().isEmpty) return;
    setState(() => _fetching = true);
    try {
      final info = await fetchVideoInfo(_urlController.text.trim());
      final card = DownloadCard(
        url: _urlController.text.trim(),
        title: info.title,
        author: info.author,
        duration: info.duration ?? "Unknown",
        thumbnail: info.thumbnail,
        darkMode: widget.darkMode,
      );
      setState(() => _downloads.insert(0, card));

      BotToast.showSimpleNotification(
        title: "Download ready",
        subTitle: info.title,
        backgroundColor: CupertinoColors.activeGreen,
        duration: const Duration(seconds: 3),
      );

      _urlController.clear();
    } catch (e) {
      BotToast.showSimpleNotification(
        title: "Error fetching info",
        subTitle: e.toString(),
        backgroundColor: CupertinoColors.destructiveRed,
        duration: const Duration(seconds: 3),
      );
    } finally {
      setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          "YouTube MP3 Downloader",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        trailing: CupertinoSwitch(
          value: widget.darkMode,
          onChanged: widget.toggleDarkMode,
          activeColor: CupertinoColors.activeBlue,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _urlController,
                      placeholder: "Enter YouTube URL",
                      padding: const EdgeInsets.all(16),
                      clearButtonMode: OverlayVisibilityMode.editing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  CupertinoButton.filled(
                    onPressed: _fetching ? null : _fetchInfo,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child:
                        _fetching
                            ? const CupertinoActivityIndicator()
                            : const Icon(CupertinoIcons.down_arrow),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _downloads.isEmpty
                      ? const Center(
                        child: Text("No downloads yet. Add a URL above."),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _downloads.length,
                        itemBuilder: (_, i) => _downloads[i],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class DownloadCard extends StatefulWidget {
  final String url;
  final String title;
  final String author;
  final String duration;
  final String thumbnail;
  final bool darkMode;

  const DownloadCard({
    super.key,
    required this.url,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnail,
    required this.darkMode,
  });

  @override
  State<DownloadCard> createState() => _DownloadCardState();
}

class _DownloadCardState extends State<DownloadCard> {
  bool _downloading = false;
  double _progress = 0.0;

  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|$]'), '_');
  }

  Future<void> _download() async {
    if (_downloading) return;

    setState(() {
      _downloading = true;
      _progress = 0;
    });

    BotToast.showSimpleNotification(
      title: "Download started",
      subTitle: widget.title,
      backgroundColor: CupertinoColors.activeBlue,
      duration: const Duration(seconds: 3),
    );

    try {
      final downloadsPath = '/storage/emulated/0/Download';
      final safeTitle = _sanitizeFilename("${widget.title}.mp3");
      final fullPath = '$downloadsPath/$safeTitle';

      await downloadYoutubeAudio(
        widget.url,
        fullPath,
        onProgress: (percent) {
          setState(() => _progress = percent);
        },
      );

      setState(() {
        _progress = 1.0;
        _downloading = false;
      });

      BotToast.showSimpleNotification(
        title: "Download completed",
        subTitle: safeTitle,
        backgroundColor: CupertinoColors.activeGreen,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      setState(() => _downloading = false);
      BotToast.showSimpleNotification(
        title: "Download failed",
        subTitle: e.toString(),
        backgroundColor: CupertinoColors.destructiveRed,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              widget.darkMode
                  ? [CupertinoColors.darkBackgroundGray, CupertinoColors.black]
                  : [CupertinoColors.systemGrey6, CupertinoColors.white],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                widget.darkMode
                    ? Colors.black.withOpacity(0.6)
                    : Colors.grey.withOpacity(0.3),
            blurRadius: widget.darkMode ? 20 : 10,
            spreadRadius: widget.darkMode ? 2 : 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.thumbnail,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CupertinoActivityIndicator(radius: 15),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Title: ${widget.title}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("Author: ${widget.author}"),
            Text("Duration: ${widget.duration}"),
            const SizedBox(height: 10),
            CupertinoButton.filled(
              onPressed: _downloading ? null : _download,
              child:
                  _downloading
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CupertinoActivityIndicator(radius: 15),
                          const SizedBox(width: 12),
                          Text("${(_progress * 100).toStringAsFixed(0)}%"),
                        ],
                      )
                      : const Text("Download MP3"),
            ),
          ],
        ),
      ),
    );
  }
}

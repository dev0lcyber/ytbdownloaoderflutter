import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:overlay_support/overlay_support.dart';
import 'ytb.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyAppRoot());
}

class MyAppRoot extends StatelessWidget {
  const MyAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    // OverlaySupport must wrap CupertinoApp directly, not the other way around
    return OverlaySupport.global(
      child: const CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: MyApp(),
      ),
    );
  }
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

  void _showIOSBanner(String title, String subtitle, {bool isError = false}) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(subtitle, textAlign: TextAlign.center),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

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
        showBanner: _showIOSBanner,
      );
      setState(() => _downloads.insert(0, card));

      _showIOSBanner("Download ready", info.title);
      _urlController.clear();
    } catch (e) {
      _showIOSBanner("Error fetching info", e.toString(), isError: true);
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
                            : const Icon(CupertinoIcons.arrow_down_circle),
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
  final void Function(String, String, {bool isError}) showBanner;

  const DownloadCard({
    super.key,
    required this.url,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnail,
    required this.darkMode,
    required this.showBanner,
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

    widget.showBanner("Download started", widget.title);

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

      widget.showBanner("Download completed", safeTitle);
    } catch (e) {
      setState(() => _downloading = false);
      widget.showBanner("Download failed", e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color:
            widget.darkMode
                ? CupertinoColors.systemGrey6.darkColor
                : CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                widget.darkMode
                    ? Colors.black.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
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

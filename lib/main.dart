import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ytb.dart';

String formatDuration(dynamic raw) {
  try {
    Duration d;
    if (raw is Duration) {
      d = raw;
    } else if (raw is String) {
      final parts = raw.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = double.parse(parts[2]).floor();
        d = Duration(hours: hours, minutes: minutes, seconds: seconds);
      } else {
        return raw; // fallback if it's something weird
      }
    } else {
      return raw.toString();
    }

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  } catch (_) {
    return raw.toString();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyAppRoot());
}

class MyAppRoot extends StatelessWidget {
  const MyAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
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
                    style: TextStyle(
                      fontSize: 16 * MediaQuery.of(context).textScaleFactor,
                    ),
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
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
        return CupertinoAlertDialog(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
              fontSize: 18 * MediaQuery.of(context).textScaleFactor,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    isDark
                        ? CupertinoColors.systemGrey3
                        : CupertinoColors.systemGrey,
                fontSize: 14 * MediaQuery.of(context).textScaleFactor,
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "OK",
                style: TextStyle(
                  color:
                      isError
                          ? CupertinoColors.systemRed
                          : CupertinoColors.activeBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 16 * MediaQuery.of(context).textScaleFactor,
                ),
              ),
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
        duration: formatDuration(info.duration),
        thumbnail: info.thumbnail,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.04; // 4% of screen width

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "YouTube to ",
                style: TextStyle(
                  fontSize: 20 * MediaQuery.of(context).textScaleFactor,
                  fontWeight: FontWeight.bold,
                  color:
                      CupertinoTheme.of(context).brightness == Brightness.dark
                          ? CupertinoColors.white
                          : CupertinoColors.black,
                ),
              ),
              TextSpan(
                text: "MP3",
                style: TextStyle(
                  fontSize: 20 * MediaQuery.of(context).textScaleFactor,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                showCupertinoDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return CupertinoAlertDialog(
                      title: Text(
                        "Developer Info",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18 * MediaQuery.of(context).textScaleFactor,
                        ),
                      ),
                      content: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            Text(
                              "Developed by Abdallah Driouich",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize:
                                    14 * MediaQuery.of(context).textScaleFactor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final url = Uri.parse(
                                  "https://abdallah.driouich.site/",
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              child: Text(
                                "https://abdallah.driouich.site",
                                style: TextStyle(
                                  color: CupertinoColors.activeBlue,
                                  fontSize:
                                      14 *
                                      MediaQuery.of(context).textScaleFactor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        CupertinoDialogAction(
                          isDefaultAction: true,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            "Close",
                            style: TextStyle(
                              fontSize:
                                  16 * MediaQuery.of(context).textScaleFactor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Icon(
                CupertinoIcons.info_circle,
                size: 26 * MediaQuery.of(context).textScaleFactor,
                color: CupertinoColors.activeBlue,
              ),
            ),
            SizedBox(width: padding),
            CupertinoSwitch(
              value: widget.darkMode,
              onChanged: widget.toggleDarkMode,
              activeColor: CupertinoColors.activeBlue,
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(padding),
              child: Row(
                children: [
                  Flexible(
                    child: CupertinoTextField(
                      controller: _urlController,
                      placeholder: "Enter YouTube URL",
                      padding: EdgeInsets.all(padding),
                      clearButtonMode: OverlayVisibilityMode.editing,
                      style: TextStyle(
                        fontSize: 16 * MediaQuery.of(context).textScaleFactor,
                      ),
                    ),
                  ),
                  SizedBox(width: padding),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: screenWidth * 0.15,
                      maxWidth: screenWidth * 0.25,
                    ),
                    child: CupertinoButton.filled(
                      onPressed: _fetching ? null : _fetchInfo,
                      padding: EdgeInsets.symmetric(
                        horizontal: padding * 1.5,
                        vertical: padding,
                      ),
                      child:
                          _fetching
                              ? const CupertinoActivityIndicator()
                              : Icon(
                                CupertinoIcons.arrow_down_circle,
                                size:
                                    24 * MediaQuery.of(context).textScaleFactor,
                              ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _downloads.isEmpty
                      ? Center(
                        child: Text(
                          "No downloads yet. Add a URL above.",
                          style: TextStyle(
                            fontSize:
                                16 * MediaQuery.of(context).textScaleFactor,
                          ),
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.all(padding),
                        itemCount: _downloads.length,
                        itemBuilder: (_, i) => _downloads[i],
                        shrinkWrap: true,
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
  final duration;
  final String thumbnail;
  final void Function(String, String, {bool isError}) showBanner;

  const DownloadCard({
    super.key,
    required this.url,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnail,
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
      final safeTitle = _sanitizeFilename("${widget.title}.mp3");
      PermissionStatus status =
          await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        throw "Storage permission denied!";
      }

      final dir = Directory('/storage/emulated/0/Download/MP3tube');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fullPath = '${dir.path}/$safeTitle';

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

      if (Platform.isAndroid) {
        await Process.run('am', [
          'broadcast',
          '-a',
          'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d',
          'file://$fullPath',
        ]);
      }
    } catch (e) {
      setState(() => _downloading = false);
      widget.showBanner("Download failed", e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.03;

    return Container(
      margin: EdgeInsets.symmetric(vertical: padding),
      decoration: BoxDecoration(
        color:
            isDark
                ? CupertinoColors.systemGrey6.darkColor
                : CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(padding * 1.5),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? CupertinoColors.black.withOpacity(0.5)
                    : CupertinoColors.systemGrey.withOpacity(0.2),
            blurRadius: padding * 1.5,
            offset: Offset(0, padding),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9, // Standard thumbnail aspect ratio
              child: ClipRRect(
                borderRadius: BorderRadius.circular(padding),
                child: Image.network(
                  widget.thumbnail,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CupertinoActivityIndicator(radius: padding * 1.5),
                    );
                  },
                  errorBuilder:
                      (context, error, stackTrace) => Center(
                        child: Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 30 * MediaQuery.of(context).textScaleFactor,
                        ),
                      ),
                ),
              ),
            ),
            SizedBox(height: padding),
            Text(
              "Title: ${widget.title}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                fontSize: 16 * MediaQuery.of(context).textScaleFactor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "Author: ${widget.author}",
              style: TextStyle(
                color:
                    isDark
                        ? const Color.fromARGB(255, 58, 58, 104)
                        : CupertinoColors.systemGrey,
                fontSize: 14 * MediaQuery.of(context).textScaleFactor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "Duration: ${formatDuration(widget.duration)}",
              style: TextStyle(
                color:
                    isDark
                        ? CupertinoColors.systemGrey2
                        : CupertinoColors.systemGrey,
                fontSize: 14 * MediaQuery.of(context).textScaleFactor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: padding),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _downloading ? null : _download,
                padding: EdgeInsets.symmetric(vertical: padding),
                child:
                    _downloading
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CupertinoActivityIndicator(radius: padding * 1.5),
                            SizedBox(width: padding),
                            Text(
                              "${(_progress * 100).toStringAsFixed(0)}%",
                              style: TextStyle(
                                fontSize:
                                    16 * MediaQuery.of(context).textScaleFactor,
                              ),
                            ),
                          ],
                        )
                        : Text(
                          "Download MP3",
                          style: TextStyle(
                            fontSize:
                                16 * MediaQuery.of(context).textScaleFactor,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

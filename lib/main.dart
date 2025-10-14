import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ytb.dart';

void main() {
  runApp(const MyApp());
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
      debugShowCheckedModeBanner: false, // removed debug banner
      title: 'mp3 Downloader for YouTube',
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

class _YtbDownloaderState extends State<YtbDownloader>
    with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  String? _savedUrl;
  String? _title;
  String? _author;
  String? _duration;
  String? _thumbnail;
  bool _loading = false;
  double _progress = 0.0; // simple rolling percentage

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(
      begin: 0.95,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  Future<void> _fetchInfo() async {
    setState(() => _loading = true);
    try {
      final info = await fetchVideoInfo(_urlController.text.trim());
      setState(() {
        _title = info.title;
        _author = info.author;
        _duration = info.duration;
        _thumbnail = info.thumbnail;
        _savedUrl = _urlController.text.trim();
      });
      _animController.forward(from: 0);
    } catch (e) {
      _showAlert("Error fetching info", e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|$]'), '_');
  }

  Future<void> _download() async {
    if (_savedUrl == null) return;

    setState(() {
      _loading = true;
      _progress = 0.0;
    });

    try {
      final downloadsPath = '/storage/emulated/0/Download';
      final safeTitle = _sanitizeFilename("${_title ?? "audio"}.mp3");
      final fullPath = '$downloadsPath/$safeTitle';

      // Simple rolling animation while downloading
      const duration = Duration(milliseconds: 100);
      Future.doWhile(() async {
        await Future.delayed(duration);
        setState(() {
          _progress += 0.02;
          if (_progress > 0.95) _progress = 0.95; // cap before done
        });
        return _loading; // continue while downloading
      });

      await downloadYoutubeAudio(_savedUrl!, fullPath); // your backend function

      setState(() => _progress = 1.0); // finished
      _showAlert("Download complete", "Saved to: $fullPath");
    } catch (e) {
      _showAlert("Download failed", e.toString());
    } finally {
      setState(() {
        _loading = false;
        _progress = 0.0;
      });
    }
  }

  void _showAlert(String title, String msg) {
    showCupertinoDialog(
      context: context,
      builder:
          (_) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              CupertinoDialogAction(
                child: const Text("OK"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          "YouTube download (MP3)",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        trailing: CupertinoSwitch(
          value: widget.darkMode,
          onChanged: widget.toggleDarkMode,
          activeColor: CupertinoColors.activeBlue,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _urlController,
                placeholder: "Enter YouTube URL",
                padding: const EdgeInsets.all(16),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _loading ? null : _fetchInfo,
                child:
                    _loading
                        ? const CupertinoActivityIndicator()
                        : const Text("Fetch Video Info"),
              ),
              const SizedBox(height: 24),
              if (_title != null)
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors:
                              widget.darkMode
                                  ? [
                                    CupertinoColors.darkBackgroundGray,
                                    CupertinoColors.black,
                                  ]
                                  : [
                                    CupertinoColors.systemGrey6,
                                    CupertinoColors.white,
                                  ],
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
                        border: Border.all(
                          color:
                              widget.darkMode
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.05),
                          width: 1,
                        ),
                      ),

                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_thumbnail != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: double.infinity,
                                height: 200,
                                child: Image.network(
                                  _thumbnail!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 15,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            "Title: $_title",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text("Author: $_author"),
                          Text("Duration: $_duration"),
                          const SizedBox(height: 16),
                          CupertinoButton.filled(
                            onPressed: _loading ? null : _download,
                            child:
                                _loading
                                    ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const CupertinoActivityIndicator(
                                          radius: 15,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "${(_progress * 100).toStringAsFixed(0)}%",
                                        ),
                                      ],
                                    )
                                    : const Text("Download MP3"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                "Only MP3 downloads supported.\nDeveloped by Abdallah Driouich\nhttps://abdallah.driouich.site/",
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/friend.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';

class SettingsPage extends StatelessWidget {
  final FriendStorage storage;
  final bool isDark;
  final Function(bool) onThemeChanged;

  const SettingsPage({
    super.key,
    required this.storage,
    required this.isDark,
    required this.onThemeChanged,
  });

  void _checkForUpdates(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
        content: Row(
          children: [
            const CircularProgressIndicator(color: Color(0xFFD71921)),
            const SizedBox(width: 20),
            Text(
              "Checking for updates...",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
      ),
    );

    try {
      final updateInfo = await UpdateService().checkForUpdate();
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (!updateInfo.hasUpdate) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 10),
                Text(
                  "UP TO DATE",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
                ),
              ],
            ),
            content: Text(
              "You are on the latest version (v${updateInfo.currentVersion}).",
              style: TextStyle(color: isDark ? Colors.grey : Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("OK", style: TextStyle(color: Color(0xFFD71921))),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.system_update_alt, color: Color(0xFFD71921)),
                const SizedBox(width: 10),
                Text(
                  "UPDATE AVAILABLE",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Version ${updateInfo.latestVersion} is available (Current: ${updateInfo.currentVersion}).",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Release Notes:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  updateInfo.releaseNotes,
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("LATER", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD71921)),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _startOtaUpdate(context, updateInfo);
                },
                child: const Text("UPDATE NOW", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to check for updates: $e"),
          backgroundColor: const Color(0xFFD71921),
        ),
      );
    }
  }

  void _startOtaUpdate(BuildContext context, UpdateInfo updateInfo) {
    if (updateInfo.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No download URL found for this update."),
          backgroundColor: Color(0xFFD71921),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _OtaDownloadDialog(
          downloadUrl: updateInfo.downloadUrl,
          version: updateInfo.latestVersion,
          isDark: isDark,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SETTINGS")),
      body: ListView(
        children: [
          // --- THEME SECTION ---
          const ListTile(
            title: Text(
              "APPEARANCE",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text("Nothing Dark Mode"),
            subtitle: const Text("Monochrome with Red Accents"),
            secondary: Icon(Icons.dark_mode, color: isDark ? Colors.white : Colors.black),
            activeThumbColor: const Color(0xFFD71921),
            value: isDark,
            onChanged: (bool value) {
              onThemeChanged(value);
            },
          ),

          const Divider(),

          const ListTile(
            title: Text(
              "CREDITS",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFFD71921)),
            title: const Text("Made by"),
            subtitle: Text("koumori@bat", style: TextStyle(color: isDark ? Colors.grey : Colors.black87)),
          ),

          const Divider(),

          const ListTile(
            title: Text(
              "DATA",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.ios_share, color: isDark ? Colors.white : Colors.black),
            title: const Text("Export Data"),
            subtitle: Text("Open copyable text", style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ExportDataPage(storage: storage, isDark: isDark)),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.download_for_offline, color: isDark ? Colors.white : Colors.black),
            title: const Text("Import Data"),
            subtitle: Text("Paste backup text to restore data", style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
            onTap: () async {
              final bool? imported = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ImportDataPage(storage: storage, isDark: isDark)),
              );
              if (imported == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Color(0xFFD71921)),
            title: const Text("Wipe Data", style: TextStyle(color: Color(0xFFD71921), fontWeight: FontWeight.bold)),
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
                  title: Text("ARE YOU SURE?", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  content: Text("This will wipe all data.", style: TextStyle(color: isDark ? Colors.grey : Colors.black)),
                  actions: [
                    TextButton(
                      child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD71921)),
                      child: const Text("WIPE", style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        storage.writeToFile([]);
                        Navigator.pop(dialogCtx);
                        Navigator.pop(context, true);
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          const ListTile(
            title: Text(
              "APP",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '-';
              final build = snapshot.data?.buildNumber ?? '-';
              return ListTile(
                leading: Icon(Icons.verified, color: isDark ? Colors.white : Colors.black),
                title: const Text("Version"),
                subtitle: Text('$version ($build)', style: TextStyle(color: isDark ? Colors.grey : Colors.black87)),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.system_update_alt, color: isDark ? Colors.white : Colors.black),
            title: const Text("Check for Updates"),
            subtitle: Text("Fetch latest release from GitHub", style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
            onTap: () => _checkForUpdates(context),
          ),
        ],
      ),
    );
  }
}

class ExportDataPage extends StatelessWidget {
  final FriendStorage storage;
  final bool isDark;

  const ExportDataPage({
    super.key,
    required this.storage,
    required this.isDark,
  });

  Future<String> _buildExportJson() async {
    final friends = await storage.readFile();
    final data = friends.map((f) => f.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("EXPORT DATA")),
      body: FutureBuilder<String>(
        future: _buildExportJson(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD71921)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to prepare export data.',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final text = snapshot.data ?? '[]';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Copy this JSON text and save it anywhere you want.",
                        style: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD71921)),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard.')),
                        );
                      },
                      icon: const Icon(Icons.copy, color: Colors.white),
                      label: const Text("COPY", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111111) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ImportDataPage extends StatefulWidget {
  final FriendStorage storage;
  final bool isDark;

  const ImportDataPage({
    super.key,
    required this.storage,
    required this.isDark,
  });

  @override
  State<ImportDataPage> createState() => _ImportDataPageState();
}

class _ImportDataPageState extends State<ImportDataPage> {
  final TextEditingController _jsonController = TextEditingController();
  bool _mergeMode = false;
  List<Friend>? _parsedFriends;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _jsonController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _jsonController.removeListener(_validateInput);
    _jsonController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedFriends = null;
        _errorMessage = null;
      });
      return;
    }

    try {
      final friends = FriendStorage.parseBackupJson(text);
      setState(() {
        _parsedFriends = friends;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _parsedFriends = null;
        _errorMessage = e is FormatException ? e.message : 'Invalid backup JSON format.';
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      _jsonController.text = data.text!;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pasted text from clipboard.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty.')),
      );
    }
  }

  void _performImport() {
    if (_parsedFriends == null || _parsedFriends!.isEmpty) return;

    final friendCount = _parsedFriends!.length;
    final totalTx = _parsedFriends!.fold<int>(0, (sum, f) => sum + f.transactions.length);
    final modeText = _mergeMode ? 'Merge with existing data' : 'Replace all existing data';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text(
          "CONFIRM IMPORT",
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Import $friendCount friend(s) ($totalTx transactions)?\n\nMode: $modeText",
          style: TextStyle(color: widget.isDark ? Colors.grey : Colors.black87),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD71921)),
            child: const Text("IMPORT", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await widget.storage.importBackupJson(_jsonController.text, merge: _mergeMode);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully imported $friendCount friend(s)!')),
                );
                Navigator.pop(context, true);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalTxCount = _parsedFriends?.fold<int>(0, (sum, f) => sum + f.transactions.length) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text("IMPORT DATA")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Paste your JSON backup text below to restore friends and transactions from an old device.",
              style: TextStyle(color: widget.isDark ? Colors.grey : Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD71921)),
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste, color: Colors.white),
                  label: const Text("PASTE FROM CLIPBOARD", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                if (_jsonController.text.isNotEmpty)
                  OutlinedButton(
                    onPressed: () {
                      _jsonController.clear();
                    },
                    child: const Text("CLEAR", style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _jsonController,
              maxLines: 8,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                color: widget.isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: '[\n  {\n    "name": "John",\n    "amountOwed": 100.0,\n    ...\n  }\n]',
                hintStyle: TextStyle(color: widget.isDark ? Colors.white30 : Colors.black26),
              ),
            ),
            const SizedBox(height: 16),

            // Preview or Error card
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else if (_parsedFriends != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          "Valid Backup Format",
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "• Friends found: ${_parsedFriends!.length}\n"
                      "• Total transactions: $totalTxCount",
                      style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.black87),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            // Mode switch
            SwitchListTile(
              title: const Text("Merge with Existing Data"),
              subtitle: Text(
                _mergeMode
                    ? "Combines imported entries with current data"
                    : "Replaces all current data with imported backup",
                style: TextStyle(color: widget.isDark ? Colors.grey : Colors.black54),
              ),
              activeThumbColor: const Color(0xFFD71921),
              value: _mergeMode,
              onChanged: (val) {
                setState(() {
                  _mergeMode = val;
                });
              },
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _parsedFriends != null && _parsedFriends!.isNotEmpty
                      ? const Color(0xFFD71921)
                      : Colors.grey,
                ),
                onPressed: _parsedFriends != null && _parsedFriends!.isNotEmpty ? _performImport : null,
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text(
                  "RESTORE / IMPORT DATA",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtaDownloadDialog extends StatefulWidget {
  final String downloadUrl;
  final String version;
  final bool isDark;

  const _OtaDownloadDialog({
    required this.downloadUrl,
    required this.version,
    required this.isDark,
  });

  @override
  State<_OtaDownloadDialog> createState() => _OtaDownloadDialogState();
}

class _OtaDownloadDialogState extends State<_OtaDownloadDialog> {
  StreamSubscription<OtaEvent>? _subscription;
  String _statusText = "Starting download...";
  double _progress = 0.0;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startDownload() {
    try {
      _subscription = UpdateService()
          .startDownloadAndInstall(widget.downloadUrl)
          .listen(
        (event) {
          if (!mounted) return;
          setState(() {
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                final parsed = double.tryParse(event.value ?? '0') ?? 0;
                _progress = parsed / 100.0;
                _statusText = "Downloading update: ${parsed.toInt()}%";
                break;
              case OtaStatus.INSTALLING:
                _progress = 1.0;
                _statusText = "Launching package installer...";
                break;
              case OtaStatus.INSTALLATION_DONE:
                _statusText = "Installation complete!";
                break;
              case OtaStatus.ALREADY_RUNNING_ERROR:
                _hasError = true;
                _errorMessage = "Update is already running in the background.";
                break;
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _hasError = true;
                _errorMessage = "Permission to install unknown apps was denied.";
                break;
              case OtaStatus.DOWNLOAD_ERROR:
                _hasError = true;
                _errorMessage = "Failed to download update file. Check connection.";
                break;
              case OtaStatus.CHECKSUM_ERROR:
                _hasError = true;
                _errorMessage = "Downloaded file checksum verification failed.";
                break;
              case OtaStatus.INTERNAL_ERROR:
                _hasError = true;
                _errorMessage = event.value ?? "An internal error occurred.";
                break;
              default:
                break;
            }
          });
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _hasError = true;
            _errorMessage = err.toString();
          });
        },
      );
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF111111) : Colors.white,
      title: Text(
        _hasError ? "UPDATE ERROR" : "DOWNLOADING UPDATE",
        style: TextStyle(
          color: _hasError ? const Color(0xFFD71921) : (widget.isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasError) ...[
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              color: const Color(0xFFD71921),
              backgroundColor: widget.isDark ? Colors.white12 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              _statusText,
              style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.black87),
            ),
          ] else ...[
            const Icon(Icons.error_outline, color: Color(0xFFD71921), size: 40),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        if (_hasError)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: Color(0xFFD71921))),
          ),
      ],
    );
  }
}


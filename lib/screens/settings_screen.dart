import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/friend.dart';
import '../services/storage_service.dart';

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

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/friend.dart';

/*NOTES:
- The OS assigns a random protected allowed folder for each app.
- async/await: on mobile, finding a path requires IPC (inter process communication)
  call to the OS. Await pauses this function until the OS replies,
  while keeping the rest of the app running.
- Future<T>: placeholder for a single value of type T that will be available in the future.
  Used for handling asynchronous operations such as fetching data.
*/

class FriendStorage {
  Future<void> _appendErrorLog(String source, Object error) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/app_errors.log');
      final line = '[${DateTime.now().toIso8601String()}] $source: $error\n';
      await logFile.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/friends_data.json');
  }

  Future<List<Friend>> readFile() async {
    try {
      final file = await _localFile;

      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);

      return jsonList.map((json) => Friend.fromJson(json)).toList();
    } catch (e) {
      await _appendErrorLog('FriendStorage.readFile', e);
      return [];
    }
  }

  Future<File> writeToFile(List<Friend> friends) async {
    try {
      final file = await _localFile;
      String jsonString = jsonEncode(friends.map((f) => f.toJson()).toList());
      return file.writeAsString(jsonString);
    } catch (e) {
      await _appendErrorLog('FriendStorage.writeToFile', e);
      rethrow;
    }
  }

  Future<String> exportBackup(List<Friend> friends) async {
    try {
      final path = await _localPath;
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('$path/ledger_backup_$stamp.json');
      final jsonString = jsonEncode(friends.map((f) => f.toJson()).toList());
      await file.writeAsString(jsonString, flush: true);
      return file.path;
    } catch (e) {
      await _appendErrorLog('FriendStorage.exportBackup', e);
      rethrow;
    }
  }

  /// Validates a raw JSON string and returns parsed `List<Friend>` if valid.
  /// Throws FormatException if invalid.
  static List<Friend> parseBackupJson(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      throw FormatException('JSON text is empty.');
    }

    final dynamic decoded = jsonDecode(trimmed);
    final List<dynamic> list;

    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded.containsKey('friends') && decoded['friends'] is List) {
      list = decoded['friends'] as List;
    } else {
      throw FormatException('JSON content must be a list of friends.');
    }

    List<Friend> parsedFriends = [];
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) {
        throw FormatException('Item #${i + 1} is not a valid object.');
      }
      final mapItem = Map<String, dynamic>.from(item);
      if (!mapItem.containsKey('name')) {
        throw FormatException('Item #${i + 1} is missing a "name" field.');
      }
      parsedFriends.add(Friend.fromJson(mapItem));
    }

    return parsedFriends;
  }

  /// Imports backup list into app storage.
  /// If [merge] is true, existing friends with matching names are merged.
  /// If [merge] is false, current data is replaced.
  Future<File> importBackupJson(String rawJson, {bool merge = false}) async {
    try {
      final newFriends = parseBackupJson(rawJson);
      if (!merge) {
        return writeToFile(newFriends);
      }

      final existingFriends = await readFile();
      final Map<String, Friend> friendMap = {
        for (var f in existingFriends) f.name.toLowerCase(): f
      };

      for (var imported in newFriends) {
        final key = imported.name.toLowerCase();
        if (friendMap.containsKey(key)) {
          final existing = friendMap[key]!;
          for (var tx in imported.transactions) {
            bool exists = existing.transactions.any((eTx) =>
                eTx.amount == tx.amount &&
                eTx.reason == tx.reason &&
                eTx.date.isAtSameMomentAs(tx.date));
            if (!exists) {
              existing.addTransaction(tx);
            }
          }
        } else {
          friendMap[key] = imported;
        }
      }

      return writeToFile(friendMap.values.toList());
    } catch (e) {
      await _appendErrorLog('FriendStorage.importBackupJson', e);
      rethrow;
    }
  }
}

class SettingsStorage {
  Future<void> _appendErrorLog(String source, Object error) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/app_errors.log');
      final line = '[${DateTime.now().toIso8601String()}] $source: $error\n';
      await logFile.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/settings.json');
  }

  // LOAD: Returns true if Dark Mode was on, false otherwise
  Future<bool> readDarkMode() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return false;

      final contents = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(contents);

      return json['isDark'] ?? false;
    } catch (e) {
      await _appendErrorLog('SettingsStorage.readDarkMode', e);
      return false;
    }
  }

  // SAVE: Writes the boolean to disk
  Future<void> writeDarkMode(bool isDark) async {
    try {
      final file = await _localFile;
      String jsonString = jsonEncode({'isDark': isDark});
      await file.writeAsString(jsonString);
    } catch (e) {
      await _appendErrorLog('SettingsStorage.writeDarkMode', e);
    }
  }
}

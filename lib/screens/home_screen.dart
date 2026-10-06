import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../services/storage_service.dart';
import '../widgets/add_friend_dialog.dart';
import 'friend_details_screen.dart';
import 'settings_screen.dart';

class LedgerHome extends StatefulWidget {
  final bool isDark;
  final Function(bool) onThemeChanged;

  const LedgerHome({super.key, required this.isDark, required this.onThemeChanged});

  @override
  State<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends State<LedgerHome> {
  List<Friend> _friends = [];
  List<Friend> _filteredFriends = [];
  final FriendStorage _storage = FriendStorage();
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterMode = 'All'; // 'All', 'They Owe Me', 'I Owe'
  String _sortMode = 'Name'; // 'Name', 'Amount', 'Date'

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFromDisk();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadFromDisk() async {
    final loadedFriends = await _storage.readFile();
    if (!mounted) return;

    final filtered = _applyFiltersAndSort(loadedFriends);

    setState(() {
      _friends = loadedFriends;
      _filteredFriends = filtered;
      _isLoading = false;
    });
  }

  void _saveToDisk() {
    _storage.writeToFile(_friends);
    setState(() {
      _filteredFriends = _applyFiltersAndSort(_friends);
    });
  }

  List<Friend> _applyFiltersAndSort(List<Friend> source) {
    List<Friend> filtered = source.where((friend) {
      if (_searchQuery.isNotEmpty && !friend.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_filterMode == 'They Owe Me' && friend.amountOwed <= 0) return false;
      if (_filterMode == 'I Owe' && friend.amountOwed >= 0) return false;
      return true;
    }).toList();

    if (_sortMode == 'Name') {
      filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortMode == 'Amount') {
      filtered.sort((a, b) => b.amountOwed.compareTo(a.amountOwed));
    } else if (_sortMode == 'Date') {
      DateTime lastDate(Friend friend) {
        if (friend.transactions.isEmpty) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
        return friend.transactions.last.date;
      }

      filtered.sort((a, b) => lastDate(b).compareTo(lastDate(a)));
    }

    return filtered;
  }

  void _handleAddNewFriend(String name, String amountStr, String reason, bool isNegative) {
    if (name.isEmpty || amountStr.isEmpty) return;

    if (_friends.any((f) => f.name.toLowerCase() == name.toLowerCase())) {
      _showError("Error: $name already exists!");
      return;
    }

    double amount = double.tryParse(amountStr) ?? 0.0;
    if (isNegative) {
      amount = -amount;
    }

    final newFriend = Friend(
      id: DateTime.now().toString(),
      name: name,
      emoji: name.isNotEmpty ? name[0].toUpperCase() : '👤',
      initialTransaction: amount,
      initialReason: reason.isEmpty ? "Initial" : reason,
    );

    setState(() {
      _friends.add(newFriend);
    });
    _saveToDisk();
    Navigator.of(context).pop();
  }

  void _handleSettingsClick() async {
    final bool? shouldReload = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SettingsPage(storage: _storage, isDark: widget.isDark, onThemeChanged: widget.onThemeChanged),
      ),
    );

    if (shouldReload == true) {
      setState(() {
        _isLoading = true;
      });
      _loadFromDisk();
    }
  }

  void _handleFriendClick(Friend friend) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendDetailsPage(
          friend: friend,
          isDark: widget.isDark,
          onSave: () {
            _saveToDisk();
            setState(() {});
          },
          onDelete: () {
            setState(() {
              _friends.remove(friend);
            });
            _saveToDisk();
          },
        ),
      ),
    );
    setState(() {});
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AddFriendDialog(
        isDark: widget.isDark,
        onAdd: _handleAddNewFriend,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Widget _renderFriendRow(Friend friend) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: widget.isDark ? Colors.white : Colors.blue,
        foregroundColor: widget.isDark ? Colors.black : Colors.white,
        child: Text(friend.emoji, style: const TextStyle(fontSize: 24)),
      ),
      title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      trailing: Text(
        "${friend.amountOwed.toStringAsFixed(2)} MAD",
        style: TextStyle(
          color: friend.amountOwed >= 0 ? Colors.green : (widget.isDark ? const Color(0xFFD71921) : Colors.red),
          fontWeight: FontWeight.bold,
          fontSize: 18,
          fontFamily: 'Courier',
        ),
      ),
      onTap: () => _handleFriendClick(friend),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD71921))),
      );
    }

    final double totalOwedToMe = _friends.where((f) => f.amountOwed > 0).fold(0.0, (sum, f) => sum + f.amountOwed);
    final double totalIOwe = _friends.where((f) => f.amountOwed < 0).fold(0.0, (sum, f) => sum + f.amountOwed.abs());
    final double netBalance = totalOwedToMe - totalIOwe;

    return Scaffold(
      appBar: AppBar(
        title: const Text("LEDGER"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortMode = value;
                _filteredFriends = _applyFiltersAndSort(_friends);
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Name', child: Text('Sort by Name')),
              PopupMenuItem(value: 'Amount', child: Text('Sort by Amount')),
              PopupMenuItem(value: 'Date', child: Text('Sort by Date')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterMode = value;
                _filteredFriends = _applyFiltersAndSort(_friends);
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'All', child: Text('All Friends')),
              PopupMenuItem(value: 'They Owe Me', child: Text('They Owe Me')),
              PopupMenuItem(value: 'I Owe', child: Text('I Owe')),
            ],
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: _handleSettingsClick),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: widget.isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryCard('They Owe', totalOwedToMe, Colors.green),
                    _buildSummaryCard('I Owe', totalIOwe, widget.isDark ? const Color(0xFFD71921) : Colors.red),
                    _buildSummaryCard(
                      'Net',
                      netBalance,
                      netBalance >= 0 ? Colors.green : (widget.isDark ? const Color(0xFFD71921) : Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search friends...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _filteredFriends = _applyFiltersAndSort(_friends);
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: widget.isDark ? Colors.black : Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filteredFriends = _applyFiltersAndSort(_friends);
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredFriends.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty || _filterMode != 'All'
                          ? 'No friends match your filters'
                          : 'No friends yet',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) {
                      return _renderFriendRow(_filteredFriends[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)} MAD',
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
        ),
      ],
    );
  }
}

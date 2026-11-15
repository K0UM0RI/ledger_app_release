import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../services/storage_service.dart';
import '../widgets/add_friend_dialog.dart';
import 'friend_details_screen.dart';
import 'settings_screen.dart';

class LedgerHome extends StatefulWidget {
  final bool isDark;
  final Function(bool) onThemeChanged;
  final List<Friend>? initialFriends;
  final bool initialAutoArchive;

  const LedgerHome({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
    this.initialFriends,
    this.initialAutoArchive = true,
  });

  @override
  State<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends State<LedgerHome> {
  List<Friend> _friends = [];
  List<Friend> _filteredFriends = [];
  final FriendStorage _storage = FriendStorage();
  final SettingsStorage _settingsStorage = SettingsStorage();
  bool _isLoading = true;
  bool _autoArchiveZeroBalance = true;
  String _searchQuery = '';
  String _filterMode = 'All'; // 'All', 'They Owe Me', 'I Owe'
  String _sortMode = 'Name'; // 'Name', 'Amount', 'Date'
  final Set<String> _selectedFriendIds = {};

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
    if (widget.initialFriends != null) {
      final loadedFriends = List<Friend>.from(widget.initialFriends!);
      _autoArchiveZeroBalance = widget.initialAutoArchive;
      _applyAutoArchiveToAll(loadedFriends);
      final filtered = _applyFiltersAndSort(loadedFriends);
      setState(() {
        _friends = loadedFriends;
        _filteredFriends = filtered;
        _isLoading = false;
      });
      return;
    }

    final loadedFriends = await _storage.readFile();
    final autoArchive = await _settingsStorage.readAutoArchiveZeroBalance();
    if (!mounted) return;

    _autoArchiveZeroBalance = autoArchive;
    final bool changed = _applyAutoArchiveToAll(loadedFriends);
    if (changed) {
      _storage.writeToFile(loadedFriends);
    }

    final filtered = _applyFiltersAndSort(loadedFriends);

    setState(() {
      _friends = loadedFriends;
      _filteredFriends = filtered;
      _isLoading = false;
    });
  }

  bool _applyAutoArchiveToAll(List<Friend> friendsList) {
    if (!_autoArchiveZeroBalance) return false;
    bool changed = false;
    for (final friend in friendsList) {
      if (friend.hasZeroBalance &&
          !friend.isArchived &&
          !friend.isManuallyUnarchived) {
        friend.isArchived = true;
        changed = true;
      }
    }
    return changed;
  }

  void _syncAutoArchiveForFriend(Friend friend) {
    if (friend.hasZeroBalance) {
      if (_autoArchiveZeroBalance && !friend.isManuallyUnarchived) {
        friend.isArchived = true;
      }
    } else {
      friend.isManuallyUnarchived = false;
      if (friend.isArchived) {
        friend.isArchived = false;
      }
    }
  }

  void _saveToDisk() {
    _storage.writeToFile(_friends);
    setState(() {
      _filteredFriends = _applyFiltersAndSort(_friends);
    });
  }

  List<Friend> _applyFiltersAndSort(List<Friend> source) {
    final bool isSearching = _searchQuery.trim().isNotEmpty;
    List<Friend> filtered = source.where((friend) {
      if (!isSearching && friend.isArchived) {
        return false;
      }
      if (isSearching &&
          !friend.name
              .toLowerCase()
              .contains(_searchQuery.trim().toLowerCase())) {
        return false;
      }
      if (_filterMode == 'They Owe Me' && friend.amountOwed <= 0) return false;
      if (_filterMode == 'I Owe' && friend.amountOwed >= 0) return false;
      return true;
    }).toList();

    if (_sortMode == 'Name') {
      filtered.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
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

  void _handleAddNewFriend(
    String name,
    String amountStr,
    String reason,
    bool isNegative,
  ) {
    if (name.isEmpty) return;

    if (_friends.any((f) => f.name.toLowerCase() == name.toLowerCase())) {
      return;
    }

    final bool hasInitialTx = amountStr.isNotEmpty || reason.isNotEmpty;
    double amount = 0.0;
    if (hasInitialTx) {
      amount = double.tryParse(amountStr) ?? 0.0;
      if (isNegative) {
        amount = -amount;
      }
    }

    final newFriend = Friend(
      id: DateTime.now().toString(),
      name: name,
      emoji: name.isNotEmpty ? name[0].toUpperCase() : '👤',
      initialTransaction: amount,
      initialReason: hasInitialTx ? (reason.isEmpty ? "Initial" : reason) : '',
      isArchived: _autoArchiveZeroBalance && (amount.abs() < 0.005),
    );

    setState(() {
      _friends.add(newFriend);
    });
    _saveToDisk();
    Navigator.of(context).pop();
    _handleFriendClick(newFriend);
  }

  void _handleAutoArchiveToggle(bool value) {
    setState(() {
      _autoArchiveZeroBalance = value;
      if (value) {
        for (final f in _friends) {
          if (f.hasZeroBalance) {
            f.isManuallyUnarchived = false;
            f.isArchived = true;
          }
        }
      }
    });
    _settingsStorage.writeAutoArchiveZeroBalance(value);
    _saveToDisk();
  }

  void _handleSettingsClick() async {
    _clearSelection();
    final bool? shouldReload = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          storage: _storage,
          isDark: widget.isDark,
          onThemeChanged: widget.onThemeChanged,
          autoArchiveZeroBalance: _autoArchiveZeroBalance,
          onAutoArchiveChanged: _handleAutoArchiveToggle,
        ),
      ),
    );

    if (shouldReload == true) {
      setState(() {
        _isLoading = true;
      });
      _loadFromDisk();
    }
  }

  void _handleArchiveClick() async {
    _clearSelection();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedFriendsPage(
          friends: _friends,
          isDark: widget.isDark,
          autoArchiveZeroBalance: _autoArchiveZeroBalance,
          onOpenFriend: (friend) => _openFriendDetails(friend),
          onChanged: () {
            _saveToDisk();
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _filteredFriends = _applyFiltersAndSort(_friends);
    });
  }

  Future<void> _openFriendDetails(Friend friend) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendDetailsPage(
          friend: friend,
          isDark: widget.isDark,
          onSave: () {
            _syncAutoArchiveForFriend(friend);
            _saveToDisk();
          },
          onDelete: () {
            setState(() {
              _friends.remove(friend);
              _selectedFriendIds.remove(friend.id);
            });
            _saveToDisk();
          },
        ),
      ),
    );
    if (!mounted) return;
    _syncAutoArchiveForFriend(friend);
    _saveToDisk();
  }

  void _handleFriendClick(Friend friend) {
    if (_selectedFriendIds.isNotEmpty) {
      _toggleSelection(friend);
      return;
    }
    _openFriendDetails(friend);
  }

  void _toggleSelection(Friend friend) {
    setState(() {
      if (_selectedFriendIds.contains(friend.id)) {
        _selectedFriendIds.remove(friend.id);
      } else {
        _selectedFriendIds.add(friend.id);
      }
    });
  }

  void _clearSelection() {
    if (_selectedFriendIds.isEmpty) return;
    setState(() {
      _selectedFriendIds.clear();
    });
  }

  void _archiveOrUnarchiveSelected() {
    if (_selectedFriendIds.isEmpty) return;

    final selectedFriends = _friends
        .where((f) => _selectedFriendIds.contains(f.id))
        .toList();
    if (selectedFriends.isEmpty) return;

    final bool allAlreadyArchived =
        selectedFriends.every((f) => f.isArchived);
    final bool targetArchiveState = !allAlreadyArchived;

    final Map<String, bool> previousArchiveState = {
      for (final f in selectedFriends) f.id: f.isArchived,
    };
    final Map<String, bool> previousManualState = {
      for (final f in selectedFriends) f.id: f.isManuallyUnarchived,
    };

    setState(() {
      for (final f in selectedFriends) {
        f.isArchived = targetArchiveState;
        if (!targetArchiveState && f.hasZeroBalance) {
          f.isManuallyUnarchived = true;
        } else if (targetArchiveState) {
          f.isManuallyUnarchived = false;
        }
      }
      _selectedFriendIds.clear();
    });
    _saveToDisk();

    final count = selectedFriends.length;
    final label = targetArchiveState
        ? (count == 1 ? 'Friend archived' : '$count friends archived')
        : (count == 1 ? 'Friend unarchived' : '$count friends unarchived');

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFFD71921),
          onPressed: () {
            setState(() {
              for (final f in selectedFriends) {
                f.isArchived = previousArchiveState[f.id] ?? false;
                f.isManuallyUnarchived = previousManualState[f.id] ?? false;
              }
            });
            _saveToDisk();
          },
        ),
      ),
    );
  }

  void _showAddFriendDialog() {
    _clearSelection();
    showDialog(
      context: context,
      builder: (context) => AddFriendDialog(
        isDark: widget.isDark,
        existingNames: _friends.map((f) => f.name).toList(),
        onAdd: _handleAddNewFriend,
      ),
    );
  }

  Widget _renderFriendRow(Friend friend) {
    final bool isSelected = _selectedFriendIds.contains(friend.id);
    final Color? selectedTileColor = isSelected
        ? (widget.isDark
              ? const Color(0xFF1B3B2B)
              : Colors.green.withValues(alpha: 0.15))
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      selected: isSelected,
      selectedTileColor: selectedTileColor,
      tileColor: selectedTileColor,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: widget.isDark ? Colors.white : Colors.blue,
            foregroundColor: widget.isDark ? Colors.black : Colors.white,
            child: Text(friend.emoji, style: const TextStyle(fontSize: 24)),
          ),
          if (isSelected)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isDark ? Colors.black : Colors.white,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        friend.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: widget.isDark ? Colors.white : Colors.black,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${friend.amountOwed.toStringAsFixed(2)} MAD",
            style: TextStyle(
              color: friend.amountOwed >= 0
                  ? Colors.green
                  : (widget.isDark ? const Color(0xFFD71921) : Colors.red),
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFamily: 'Courier',
            ),
          ),
          if (friend.isArchived) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.archive_outlined,
              size: 20,
              color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ],
      ),
      onTap: () => _handleFriendClick(friend),
      onLongPress: () => _toggleSelection(friend),
    );
  }

  PreferredSizeWidget _buildAppBar(int archivedCount) {
    if (_selectedFriendIds.isNotEmpty) {
      final selectedFriends = _friends
          .where((f) => _selectedFriendIds.contains(f.id))
          .toList();
      final bool allSelectedArchived =
          selectedFriends.isNotEmpty &&
          selectedFriends.every((f) => f.isArchived);

      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Clear selection',
          onPressed: _clearSelection,
        ),
        title: Text('${_selectedFriendIds.length}'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              allSelectedArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
            tooltip: allSelectedArchived ? 'Unarchive' : 'Archive',
            onPressed: _archiveOrUnarchiveSelected,
          ),
        ],
      );
    }

    return AppBar(
      title: const Text("LEDGER"),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
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
          tooltip: 'Filter',
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
        IconButton(
          icon: Badge(
            isLabelVisible: archivedCount > 0,
            backgroundColor: const Color(0xFFD71921),
            label: Text(
              '$archivedCount',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            child: const Icon(Icons.archive_outlined),
          ),
          tooltip: 'Archived',
          onPressed: _handleArchiveClick,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: _handleSettingsClick,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD71921)),
        ),
      );
    }

    final double totalOwedToMe = _friends
        .where((f) => !f.isArchived && f.amountOwed > 0)
        .fold(0.0, (sum, f) => sum + f.amountOwed);
    final double totalIOwe = _friends
        .where((f) => !f.isArchived && f.amountOwed < 0)
        .fold(0.0, (sum, f) => sum + f.amountOwed.abs());
    final double netBalance = totalOwedToMe - totalIOwe;
    final int archivedCount = _friends.where((f) => f.isArchived).length;

    return PopScope(
      canPop: _selectedFriendIds.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedFriendIds.isNotEmpty) {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(archivedCount),
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
                      _buildSummaryCard(
                        'I Owe',
                        totalIOwe,
                        widget.isDark ? const Color(0xFFD71921) : Colors.red,
                      ),
                      _buildSummaryCard(
                        'Net',
                        netBalance,
                        netBalance >= 0
                            ? Colors.green
                            : (widget.isDark
                                  ? const Color(0xFFD71921)
                                  : Colors.red),
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
                                  _filteredFriends = _applyFiltersAndSort(
                                    _friends,
                                  );
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
                            : (archivedCount > 0
                                  ? 'All friends are archived'
                                  : 'No friends yet'),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
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
      ),
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)} MAD',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }
}

class ArchivedFriendsPage extends StatefulWidget {
  final List<Friend> friends;
  final bool isDark;
  final bool autoArchiveZeroBalance;
  final Future<void> Function(Friend) onOpenFriend;
  final VoidCallback onChanged;

  const ArchivedFriendsPage({
    super.key,
    required this.friends,
    required this.isDark,
    required this.autoArchiveZeroBalance,
    required this.onOpenFriend,
    required this.onChanged,
  });

  @override
  State<ArchivedFriendsPage> createState() => _ArchivedFriendsPageState();
}

class _ArchivedFriendsPageState extends State<ArchivedFriendsPage> {
  final Set<String> _selectedIds = {};

  List<Friend> get _archivedFriends {
    final list = widget.friends.where((f) => f.isArchived).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  void _toggleSelection(Friend friend) {
    setState(() {
      if (_selectedIds.contains(friend.id)) {
        _selectedIds.remove(friend.id);
      } else {
        _selectedIds.add(friend.id);
      }
    });
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _selectedIds.clear();
    });
  }

  void _unarchiveSelected() {
    if (_selectedIds.isEmpty) return;
    final selected = widget.friends
        .where((f) => _selectedIds.contains(f.id))
        .toList();
    if (selected.isEmpty) return;

    setState(() {
      for (final f in selected) {
        f.isArchived = false;
        if (f.hasZeroBalance) {
          f.isManuallyUnarchived = true;
        }
      }
      _selectedIds.clear();
    });
    widget.onChanged();

    final count = selected.length;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1 ? 'Friend unarchived' : '$count friends unarchived',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFFD71921),
          onPressed: () {
            setState(() {
              for (final f in selected) {
                f.isArchived = true;
                f.isManuallyUnarchived = false;
              }
            });
            widget.onChanged();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final archived = _archivedFriends;

    return PopScope(
      canPop: _selectedIds.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIds.isNotEmpty) {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: _selectedIds.isNotEmpty
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Clear selection',
                  onPressed: _clearSelection,
                ),
                title: Text('${_selectedIds.length}'),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.unarchive_outlined),
                    tooltip: 'Unarchive',
                    onPressed: _unarchiveSelected,
                  ),
                ],
              )
            : AppBar(title: const Text("ARCHIVED")),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: widget.isDark ? const Color(0xFF141414) : Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 16,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.autoArchiveZeroBalance
                          ? "Friends with 0.00 MAD balance are archived automatically"
                          : "Hold on a friend to unarchive",
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? Colors.grey[400]
                            : Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: archived.isEmpty
                  ? const Center(
                      child: Text(
                        "No archived friends",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: archived.length,
                      itemBuilder: (context, index) {
                        final friend = archived[index];
                        final isSelected = _selectedIds.contains(friend.id);
                        final selectedTileColor = isSelected
                            ? (widget.isDark
                                  ? const Color(0xFF1B3B2B)
                                  : Colors.green.withValues(alpha: 0.15))
                            : null;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          selected: isSelected,
                          selectedTileColor: selectedTileColor,
                          tileColor: selectedTileColor,
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                backgroundColor: widget.isDark
                                    ? Colors.white
                                    : Colors.blue,
                                foregroundColor: widget.isDark
                                    ? Colors.black
                                    : Colors.white,
                                child: Text(
                                  friend.emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: widget.isDark
                                            ? Colors.black
                                            : Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            friend.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${friend.amountOwed.toStringAsFixed(2)} MAD",
                                style: TextStyle(
                                  color: friend.amountOwed >= 0
                                      ? Colors.green
                                      : (widget.isDark
                                            ? const Color(0xFFD71921)
                                            : Colors.red),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.archive_outlined,
                                size: 20,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ],
                          ),
                          onTap: () async {
                            if (_selectedIds.isNotEmpty) {
                              _toggleSelection(friend);
                              return;
                            }
                            await widget.onOpenFriend(friend);
                            if (mounted) {
                              setState(() {});
                            }
                          },
                          onLongPress: () => _toggleSelection(friend),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

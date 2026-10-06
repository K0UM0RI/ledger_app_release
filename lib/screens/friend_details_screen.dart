import 'package:flutter/material.dart';
import '../models/borrowed_item.dart';
import '../models/friend.dart';
import '../models/transaction.dart';

class FriendDetailsPage extends StatefulWidget {
  final Friend friend;
  final VoidCallback onSave;
  final VoidCallback? onDelete; // Callback when friend is deleted
  final bool isDark;

  const FriendDetailsPage({
    super.key,
    required this.friend,
    required this.onSave,
    this.onDelete,
    this.isDark = false,
  });

  @override
  State<FriendDetailsPage> createState() => _FriendDetailsPageState();
}

class _FriendDetailsPageState extends State<FriendDetailsPage>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemNotesController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _itemNameController.dispose();
    _itemNotesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _addTransaction() {
    bool isGiving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor:
                widget.isDark ? const Color(0xFF111111) : Colors.white,
            title: Text(
              "ADD TRANSACTION",
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: "AMOUNT"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: "REASON"),
                ),
                const SizedBox(height: 20),

                // --- TOGGLE SWITCH ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Switch(
                      activeThumbColor: Colors.red,
                      inactiveThumbColor: Colors.green,
                      activeTrackColor: Colors.red.withValues(alpha: 0.5),
                      inactiveTrackColor: Colors.green.withValues(alpha: 0.5),
                      value: isGiving,
                      onChanged: (val) {
                        setDialogState(() {
                          isGiving = val;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isGiving ? Colors.red : Colors.green,
                ),
                child: const Text("SAVE", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  final amountStr = _amountController.text;
                  final reason = _reasonController.text;

                  if (amountStr.isEmpty) return;

                  double amount = double.tryParse(amountStr) ?? 0.0;

                  // Apply Toggle Logic
                  if (isGiving) {
                    amount = -amount.abs();
                  } else {
                    amount = amount.abs();
                  }

                  setState(() {
                    widget.friend.addTransaction(
                      Transaction(
                        amount: amount,
                        date: DateTime.now(),
                        reason: reason.isEmpty ? "Payment" : reason,
                      ),
                    );
                  });

                  widget.onSave();

                  _amountController.clear();
                  _reasonController.clear();
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _addBorrowedItem() {
    bool isLentByMe = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor:
                widget.isDark ? const Color(0xFF111111) : Colors.white,
            title: Text(
              "BORROW / LEND OBJECT",
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _itemNameController,
                    decoration: const InputDecoration(
                      labelText: "OBJECT / ITEM NAME",
                      hintText: "e.g. Charger, Book, Tool",
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _itemNotesController,
                    decoration: const InputDecoration(
                      labelText: "NOTES (OPTIONAL)",
                      hintText: "e.g. 65W fast charger",
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isLentByMe
                        ? "I lent this to ${widget.friend.name}"
                        : "I borrowed this from ${widget.friend.name}",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isLentByMe
                          ? const Color(0xFFD71921)
                          : Colors.green,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text("Borrowed", style: TextStyle(color: Colors.grey)),
                      Switch(
                        activeThumbColor: const Color(0xFFD71921),
                        inactiveThumbColor: Colors.green,
                        activeTrackColor:
                            const Color(0xFFD71921).withValues(alpha: 0.4),
                        inactiveTrackColor: Colors.green.withValues(alpha: 0.4),
                        value: isLentByMe,
                        onChanged: (val) {
                          setDialogState(() {
                            isLentByMe = val;
                          });
                        },
                      ),
                      const Text("Lent out", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                onPressed: () {
                  _itemNameController.clear();
                  _itemNotesController.clear();
                  Navigator.pop(context);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD71921),
                ),
                child: const Text("SAVE", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  final name = _itemNameController.text.trim();
                  if (name.isEmpty) return;

                  final newItem = BorrowedItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    date: DateTime.now(),
                    isLentByMe: isLentByMe,
                    notes: _itemNotesController.text.trim(),
                  );

                  setState(() {
                    widget.friend.addBorrowedItem(newItem);
                  });

                  widget.onSave();

                  _itemNameController.clear();
                  _itemNotesController.clear();
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteFriend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text(
          "DELETE FRIEND?",
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Are you sure you want to delete ${widget.friend.name}? This will remove all transactions and borrowed objects.",
          style: TextStyle(
            color: widget.isDark ? Colors.grey : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD71921),
            ),
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (widget.onDelete != null) {
                widget.onDelete!(); // Trigger deletion
              }
              Navigator.pop(context); // Close friend details page
            },
          ),
        ],
      ),
    );
  }

  void _settleUp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text(
          "SETTLE UP?",
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "This will add a final transaction to settle the balance with ${widget.friend.name}. Current balance: ${widget.friend.amountOwed.toStringAsFixed(2)} MAD",
          style: TextStyle(
            color: widget.isDark ? Colors.grey : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("SETTLE", style: TextStyle(color: Colors.white)),
            onPressed: () {
              setState(() {
                widget.friend.addTransaction(
                  Transaction(
                    amount: -widget.friend.amountOwed,
                    date: DateTime.now(),
                    reason: "Settled up",
                  ),
                );
              });
              widget.onSave();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerColor =
        widget.isDark ? const Color(0xFF1A1A1A) : Colors.grey[200];
    final headerTextColor = widget.isDark ? Colors.white54 : Colors.grey[600];
    final moneyColor = widget.isDark ? const Color(0xFFD71921) : Colors.red;

    final unreturnedCount =
        widget.friend.borrowedItems.where((i) => !i.isReturned).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.friend.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          if (widget.friend.amountOwed.abs() > 0.01)
            IconButton(
              icon: const Icon(Icons.handshake),
              color: Colors.green,
              tooltip: "Settle Up",
              onPressed: _settleUp,
            ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            color: const Color(0xFFD71921),
            tooltip: "Delete Friend",
            onPressed: _deleteFriend,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                "${widget.friend.amountOwed.toStringAsFixed(2)} MAD",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                  color: widget.friend.amountOwed >= 0
                      ? Colors.green
                      : moneyColor,
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD71921),
          labelColor: const Color(0xFFD71921),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: const Icon(Icons.receipt_long, size: 20),
              text: "MONEY (${widget.friend.transactions.length})",
            ),
            Tab(
              icon: const Icon(Icons.inventory_2_outlined, size: 20),
              text: "OBJECTS ($unreturnedCount)",
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- TAB 1: TRANSACTIONS / MONEY ---
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: headerColor,
                width: double.infinity,
                child: Text(
                  "TRANSACTION HISTORY",
                  style: TextStyle(
                    color: headerTextColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final sortedTransactions = [
                      ...widget.friend.transactions,
                    ]..sort((a, b) => b.date.compareTo(a.date));

                    if (sortedTransactions.isEmpty) {
                      return const Center(
                        child: Text(
                          "No transactions recorded yet.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: sortedTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = sortedTransactions[index];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: Icon(
                            tx.amount >= 0
                                ? Icons.arrow_back
                                : Icons.arrow_forward,
                            color:
                                tx.amount >= 0 ? Colors.green : moneyColor,
                          ),
                          title: Text(
                            tx.reason,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            tx.date.toString().substring(0, 16),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: Text(
                            "${tx.amount.toStringAsFixed(2)} MAD",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: 'Courier',
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // --- TAB 2: BORROWED OBJECTS ---
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: headerColor,
                width: double.infinity,
                child: Text(
                  "BORROWED & LENT OBJECTS",
                  style: TextStyle(
                    color: headerTextColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: widget.friend.borrowedItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: widget.isDark
                                  ? Colors.white24
                                  : Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "No borrowed objects tracked yet.",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Tap '+' below to record a charger, book, or tool.",
                              style: TextStyle(
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black45,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.friend.borrowedItems.length,
                        itemBuilder: (context, index) {
                          // Sort: Unreturned first, then newest
                          final sortedItems = [
                            ...widget.friend.borrowedItems,
                          ]..sort((a, b) {
                              if (a.isReturned != b.isReturned) {
                                return a.isReturned ? 1 : -1;
                              }
                              return b.date.compareTo(a.date);
                            });

                          final item = sortedItems[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            color: widget.isDark
                                ? (item.isReturned
                                    ? const Color(0xFF111111)
                                    : const Color(0xFF1E1E1E))
                                : (item.isReturned
                                    ? Colors.grey[100]
                                    : Colors.white),
                            elevation: item.isReturned ? 0 : 2,
                            child: ListTile(
                              leading: IconButton(
                                icon: Icon(
                                  item.isReturned
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: item.isReturned
                                      ? Colors.green
                                      : const Color(0xFFD71921),
                                  size: 28,
                                ),
                                tooltip: item.isReturned
                                    ? "Mark as unreturned"
                                    : "Mark as returned",
                                onPressed: () {
                                  setState(() {
                                    widget.friend.toggleBorrowedItem(item.id);
                                  });
                                  widget.onSave();
                                },
                              ),
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: item.isReturned
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: item.isReturned
                                      ? Colors.grey
                                      : (widget.isDark
                                          ? Colors.white
                                          : Colors.black),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.isLentByMe
                                              ? const Color(0xFFD71921)
                                                  .withValues(alpha: 0.15)
                                              : Colors.green
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.isLentByMe
                                              ? "LENT OUT"
                                              : "BORROWED",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: item.isLentByMe
                                                ? const Color(0xFFD71921)
                                                : Colors.green,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.isReturned
                                            ? "Returned"
                                            : "Active",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: item.isReturned
                                              ? Colors.green
                                              : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.notes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.notes,
                                      style: TextStyle(
                                        color: widget.isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    item.date.toString().substring(0, 10),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                tooltip: "Remove item",
                                onPressed: () {
                                  setState(() {
                                    widget.friend.removeBorrowedItem(item.id);
                                  });
                                  widget.onSave();
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _tabController.index == 0
            ? _addTransaction
            : _addBorrowedItem,
        backgroundColor: const Color(0xFFD71921),
        tooltip: _tabController.index == 0
            ? "Add Transaction"
            : "Add Borrowed Object",
        child: Icon(
          _tabController.index == 0 ? Icons.add_card : Icons.add_box_outlined,
        ),
      ),
    );
  }
}

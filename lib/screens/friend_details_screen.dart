import 'package:flutter/material.dart';
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

class _FriendDetailsPageState extends State<FriendDetailsPage> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _addTransaction() {
    bool isGiving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: widget.isDark ? const Color(0xFF111111) : Colors.white,
            title: Text(
              "ADD TRANSACTION",
              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: "AMOUNT"),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                style: ElevatedButton.styleFrom(backgroundColor: isGiving ? Colors.red : Colors.green),
                child: const Text("SAVE", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  final amountStr = _amountController.text;
                  final reason = _reasonController.text;

                  if (amountStr.isEmpty) return;

                  double amount = double.tryParse(amountStr) ?? 0.0;

                  // Apply Toggle Logic
                  if (isGiving) {
                    amount = -amount;
                  }

                  setState(() {
                    widget.friend.addTransaction(
                      Transaction(
                        amount: amount,
                        date: DateTime.now(),
                        reason: reason.isEmpty ? "Manual Entry" : reason,
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

  void _deleteFriend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text(
          "DELETE FRIEND?",
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete ${widget.friend.name}? This will remove all transaction history.",
          style: TextStyle(color: widget.isDark ? Colors.grey : Colors.black87),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD71921)),
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
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "This will add a final transaction to settle the balance with ${widget.friend.name}. Current balance: ${widget.friend.amountOwed.toStringAsFixed(2)} MAD",
          style: TextStyle(color: widget.isDark ? Colors.grey : Colors.black87),
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
                  Transaction(amount: -widget.friend.amountOwed, date: DateTime.now(), reason: "Settled up"),
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
    final headerColor = widget.isDark ? const Color(0xFF1A1A1A) : Colors.grey[200];
    final headerTextColor = widget.isDark ? Colors.white54 : Colors.grey[600];
    final moneyColor = widget.isDark ? const Color(0xFFD71921) : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.friend.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          if (widget.friend.amountOwed.abs() > 0.01)
            IconButton(icon: const Icon(Icons.handshake), color: Colors.green, tooltip: "Settle Up", onPressed: _settleUp),
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
                  color: widget.friend.amountOwed >= 0 ? Colors.green : moneyColor,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: headerColor,
            width: double.infinity,
            child: Text(
              "HISTORY",
              style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final sortedTransactions = [...widget.friend.transactions]
                  ..sort((a, b) => b.date.compareTo(a.date));

                return ListView.builder(
                  itemCount: sortedTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = sortedTransactions[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Icon(
                        tx.amount >= 0 ? Icons.arrow_back : Icons.arrow_forward,
                        color: tx.amount >= 0 ? Colors.green : moneyColor,
                      ),
                      title: Text(
                        tx.reason,
                        style: TextStyle(fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black),
                      ),
                      subtitle: Text(tx.date.toString().substring(0, 16), style: const TextStyle(color: Colors.grey)),
                      trailing: Text(
                        "${tx.amount.toStringAsFixed(2)} MAD",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Courier',
                          color: widget.isDark ? Colors.white : Colors.black87,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        backgroundColor: const Color(0xFFD71921),
        child: const Icon(Icons.add_card),
      ),
    );
  }
}

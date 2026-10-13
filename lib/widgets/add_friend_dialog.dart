import 'package:flutter/material.dart';

class AddFriendDialog extends StatefulWidget {
  final bool isDark;
  final Function(String name, String amount, String reason, bool isGiving) onAdd;

  const AddFriendDialog({
    super.key,
    required this.isDark,
    required this.onAdd,
  });

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isGiving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final statusColor = _isGiving ? const Color(0xFFD71921) : Colors.green;

    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF111111) : Colors.white,
      title: Text(
        "NEW ENTRY",
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
              controller: _nameController,
              decoration: const InputDecoration(labelText: "NAME"),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: "AMOUNT (MAD)"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: "REASON (OPTIONAL)"),
            ),
            const SizedBox(height: 16),
            Text(
              _isGiving
                  ? "I owe them (Borrowed money)"
                  : "They owe me (Lent money)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text("Lent (+)", style: TextStyle(color: Colors.grey, fontSize: 13)),
                Switch(
                  activeThumbColor: const Color(0xFFD71921),
                  inactiveThumbColor: Colors.green,
                  activeTrackColor: const Color(0xFFD71921).withValues(alpha: 0.4),
                  inactiveTrackColor: Colors.green.withValues(alpha: 0.4),
                  value: _isGiving,
                  onChanged: (val) {
                    setState(() {
                      _isGiving = val;
                    });
                  },
                ),
                const Text("Borrowed (-)", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFD71921),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: statusColor,
          ),
          child: const Text("SAVE", style: TextStyle(color: Colors.white)),
          onPressed: () {
            final name = _nameController.text.trim();
            final amtStr = _amountController.text.trim();
            final amt = double.tryParse(amtStr);

            if (name.isEmpty) {
              setState(() => _errorMessage = "Please enter a name.");
              return;
            }
            if (amt == null || amt <= 0) {
              setState(() => _errorMessage = "Please enter a valid amount greater than 0.");
              return;
            }

            widget.onAdd(
              name,
              amtStr,
              _reasonController.text.trim(),
              _isGiving,
            );
          },
        ),
      ],
    );
  }
}


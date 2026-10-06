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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF111111) : Colors.white,
      title: Text(
        "NEW ENTRY",
        style: TextStyle(
          color: widget.isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "NAME"),
            autofocus: true,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: "AMOUNT"),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: "REASON"),
          ),
          const SizedBox(height: 20),

          // --- THE TOGGLE SWITCH ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Switch(
                activeThumbColor: Colors.red,
                inactiveThumbColor: Colors.green,
                activeTrackColor: Colors.red.withValues(alpha: 0.5),
                inactiveTrackColor: Colors.green.withValues(alpha: 0.5),
                value: _isGiving,
                onChanged: (val) {
                  setState(() {
                    _isGiving = val;
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isGiving ? Colors.red : Colors.green,
          ),
          child: const Text("SAVE", style: TextStyle(color: Colors.white)),
          onPressed: () {
            widget.onAdd(
              _nameController.text.trim(),
              _amountController.text.trim(),
              _reasonController.text.trim(),
              _isGiving,
            );
          },
        ),
      ],
    );
  }
}

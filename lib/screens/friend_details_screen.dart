import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import '../services/pdf_service.dart';

class FriendDetailsPage extends StatefulWidget {
  final Friend friend;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
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

  late TabController _tabController;

  // Calculator state
  String _calcExpression = '';

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
    _tabController.dispose();
    super.dispose();
  }

  // --- CALCULATOR LOGIC ---
  double? _evaluateExpression(String expr) {
    String sanitized = expr
        .replaceAll(' ', '')
        .replaceAll('×', '*')
        .replaceAll('÷', '/');

    while (sanitized.isNotEmpty &&
        '+-*/.'.contains(sanitized[sanitized.length - 1])) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }

    if (sanitized.isEmpty) return null;

    final List<String> tokens = [];
    final buffer = StringBuffer();

    for (int i = 0; i < sanitized.length; i++) {
      final ch = sanitized[i];
      if ('+-*/'.contains(ch)) {
        if (i == 0 && (ch == '-' || ch == '+')) {
          buffer.write(ch);
        } else if (buffer.isEmpty && (ch == '-' || ch == '+')) {
          buffer.write(ch);
        } else {
          if (buffer.isNotEmpty) {
            tokens.add(buffer.toString());
            buffer.clear();
          }
          tokens.add(ch);
        }
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    if (tokens.isEmpty) return null;

    // First pass: * and /
    final List<String> pass1 = [];
    int i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      if ((token == '*' || token == '/') &&
          pass1.isNotEmpty &&
          i + 1 < tokens.length) {
        final left = double.tryParse(pass1.removeLast());
        final right = double.tryParse(tokens[i + 1]);
        if (left == null || right == null) return null;
        if (token == '/' && right == 0) return null;
        final res = token == '*' ? left * right : left / right;
        pass1.add(res.toString());
        i += 2;
      } else {
        pass1.add(token);
        i++;
      }
    }

    // Second pass: + and -
    double? total = double.tryParse(pass1.first);
    if (total == null) return null;

    int j = 1;
    while (j + 1 < pass1.length) {
      final op = pass1[j];
      final val = double.tryParse(pass1[j + 1]);
      if (val == null) return null;
      if (op == '+') {
        total = total! + val;
      } else if (op == '-') {
        total = total! - val;
      }
      j += 2;
    }

    return total;
  }

  String _formatCalcNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  void _onCalcKeyPress(String key) {
    setState(() {
      if (key == 'C') {
        _calcExpression = '';
        return;
      }
      if (key == '⌫') {
        if (_calcExpression.isNotEmpty) {
          _calcExpression =
              _calcExpression.substring(0, _calcExpression.length - 1);
        }
        return;
      }
      if (key == '=') {
        final result = _evaluateExpression(_calcExpression);
        if (result != null) {
          _calcExpression = _formatCalcNumber(result);
        }
        return;
      }

      const operators = ['+', '-', '×', '÷'];
      if (operators.contains(key)) {
        if (_calcExpression.isEmpty) {
          if (key == '-') {
            _calcExpression = '-';
          }
          return;
        }
        final lastChar = _calcExpression[_calcExpression.length - 1];
        if (operators.contains(lastChar)) {
          _calcExpression =
              _calcExpression.substring(0, _calcExpression.length - 1) + key;
          return;
        }
        if (lastChar == '.') {
          return;
        }
        _calcExpression += key;
        return;
      }

      if (key == '.') {
        // Prevent multiple decimals in the current number segment
        final parts = _calcExpression.split(RegExp(r'[+\-×÷]'));
        final currentSegment = parts.isNotEmpty ? parts.last : '';
        if (currentSegment.contains('.')) return;
        if (currentSegment.isEmpty) {
          _calcExpression += '0.';
        } else {
          _calcExpression += '.';
        }
        return;
      }

      _calcExpression += key;
    });
  }

  void _validateCalculatorAmount() {
    final result = _evaluateExpression(_calcExpression);
    if (result == null || result == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Calculate a non-zero amount first."),
          backgroundColor: Color(0xFFD71921),
        ),
      );
      return;
    }

    final formattedAmt = _formatCalcNumber(result.abs());
    final initialIsGiving = result < 0;

    _tabController.animateTo(0);
    _addTransaction(
      prefilledAmount: formattedAmt,
      initialIsGiving: initialIsGiving,
      clearCalculatorOnSave: true,
    );
  }

  void _addTransaction({
    String? prefilledAmount,
    bool initialIsGiving = false,
    bool clearCalculatorOnSave = false,
  }) {
    if (prefilledAmount != null) {
      _amountController.text = prefilledAmount;
    } else {
      _amountController.clear();
    }
    _reasonController.clear();

    bool isGiving = initialIsGiving;
    String? amountError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final statusColor =
              isGiving ? const Color(0xFFD71921) : Colors.green;

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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: "AMOUNT (MAD)",
                      errorText: amountError,
                      errorStyle: const TextStyle(
                        color: Color(0xFFD71921),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: prefilledAmount == null,
                    onChanged: (_) {
                      if (amountError != null) {
                        setDialogState(() => amountError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(labelText: "REASON"),
                    autofocus: prefilledAmount != null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isGiving
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
                      const Text(
                        "Lent (+)",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Switch(
                        activeThumbColor: const Color(0xFFD71921),
                        inactiveThumbColor: Colors.green,
                        activeTrackColor:
                            const Color(0xFFD71921).withValues(alpha: 0.4),
                        inactiveTrackColor:
                            Colors.green.withValues(alpha: 0.4),
                        value: isGiving,
                        onChanged: (val) {
                          setDialogState(() {
                            isGiving = val;
                          });
                        },
                      ),
                      const Text(
                        "Borrowed (-)",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child:
                    const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                ),
                child:
                    const Text("SAVE", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  final amountStr = _amountController.text.trim();
                  final reason = _reasonController.text.trim();

                  final parsedAmount = double.tryParse(amountStr);
                  if (parsedAmount == null || parsedAmount <= 0) {
                    setDialogState(
                      () => amountError =
                          "Please enter a valid amount greater than 0.",
                    );
                    return;
                  }

                  final double amount =
                      isGiving ? -parsedAmount.abs() : parsedAmount.abs();

                  setState(() {
                    widget.friend.addTransaction(
                      Transaction(
                        amount: amount,
                        date: DateTime.now(),
                        reason: reason.isEmpty ? "Payment" : reason,
                      ),
                    );
                    if (clearCalculatorOnSave) {
                      _calcExpression = '';
                    }
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
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Are you sure you want to delete ${widget.friend.name}? This will remove all transactions.",
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
              Navigator.pop(context);
              if (widget.onDelete != null) {
                widget.onDelete!();
              }
              Navigator.pop(context);
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

  Future<void> _sharePdfStatement() async {
    try {
      await PdfService.shareStatementPdf(widget.friend);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to share PDF: $e"),
          backgroundColor: const Color(0xFFD71921),
        ),
      );
    }
  }

  void _editTransactionDialog(Transaction tx) {
    final amtController =
        TextEditingController(text: tx.amount.abs().toStringAsFixed(2));
    final reasonController = TextEditingController(text: tx.reason);
    bool isGiving = tx.amount < 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final activeColor =
              isGiving ? const Color(0xFFD71921) : Colors.green;

          return AlertDialog(
            backgroundColor:
                widget.isDark ? const Color(0xFF111111) : Colors.white,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "EDIT ENTRY",
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (tx.isEdited)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon:
                        const Icon(Icons.history, size: 14, color: Colors.grey),
                    label: Text(
                      "HISTORY (${tx.editHistory.length})",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    onPressed: () {
                      _showCorrectionHistoryDialog(tx);
                    },
                  ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amtController,
                  decoration: const InputDecoration(labelText: "AMOUNT"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: "REASON"),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Lent",
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(width: 8),
                    Switch(
                      activeThumbColor: const Color(0xFFD71921),
                      inactiveThumbColor: Colors.green,
                      activeTrackColor:
                          const Color(0xFFD71921).withValues(alpha: 0.4),
                      inactiveTrackColor: Colors.green.withValues(alpha: 0.4),
                      value: isGiving,
                      onChanged: (val) {
                        setDialogState(() => isGiving = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text("Borrowed",
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                child:
                    const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                onPressed: () => Navigator.pop(ctx),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                ),
                child:
                    const Text("SAVE", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  final rawAmt = amtController.text.trim();
                  final parsed = double.tryParse(rawAmt);
                  if (parsed == null || parsed <= 0) return;

                  final newReason = reasonController.text.trim();
                  final newAmt = isGiving ? -parsed.abs() : parsed.abs();

                  setState(() {
                    widget.friend.correctTransaction(
                      tx,
                      newAmt,
                      newReason.isEmpty ? "Payment" : newReason,
                    );
                  });

                  widget.onSave();
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCorrectionHistoryDialog(Transaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text(
          "HISTORY",
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(tx.editHistory.length, (i) {
                  final edit = tx.editHistory[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "#${i + 1}: ${edit.previousAmount >= 0 ? '+' : ''}${edit.previousAmount.toStringAsFixed(2)} MAD (\"${edit.previousReason}\")\n${edit.editedAt.toString().substring(0, 16)}",
                      style:
                          const TextStyle(fontSize: 11, fontFamily: 'Courier'),
                    ),
                  );
                }),
                const Divider(),
                Text(
                  "Current: ${tx.amount >= 0 ? '+' : ''}${tx.amount.toStringAsFixed(2)} MAD (\"${tx.reason}\")",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Courier',
                    color:
                        tx.amount >= 0 ? Colors.green : const Color(0xFFD71921),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CLOSE", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcButton(
    String label, {
    Color? textColor,
    Color? bgColor,
    int flex = 1,
  }) {
    final defaultBg =
        widget.isDark ? const Color(0xFF1A1A1A) : Colors.grey[200]!;
    final defaultText = widget.isDark ? Colors.white : Colors.black87;

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: SizedBox.expand(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor ?? defaultBg,
              foregroundColor: textColor ?? defaultText,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _onCalcKeyPress(label),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
                color: textColor ?? defaultText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatorTab(Color? headerColor, Color? headerTextColor) {
    final liveResult = _evaluateExpression(_calcExpression);
    final resultText =
        liveResult != null ? "${liveResult.toStringAsFixed(2)} MAD" : "0.00 MAD";

    const accentRed = Color(0xFFD71921);
    final opBg = widget.isDark ? const Color(0xFF262626) : Colors.grey[300]!;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: headerColor,
          width: double.infinity,
          child: Text(
            "AMOUNT CALCULATOR",
            style: TextStyle(
              color: headerTextColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                // Display Screen
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF121212)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          _calcExpression.isEmpty ? "0" : _calcExpression,
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Courier',
                            color:
                                widget.isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "= $resultText",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                          color: liveResult != null && liveResult < 0
                              ? accentRed
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Keypad (flexes to fit screen without scrolling)
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalcButton('C', textColor: accentRed, bgColor: opBg),
                            _buildCalcButton('⌫', bgColor: opBg),
                            _buildCalcButton('÷', textColor: accentRed, bgColor: opBg),
                            _buildCalcButton('×', textColor: accentRed, bgColor: opBg),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalcButton('7'),
                            _buildCalcButton('8'),
                            _buildCalcButton('9'),
                            _buildCalcButton('-', textColor: accentRed, bgColor: opBg),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalcButton('4'),
                            _buildCalcButton('5'),
                            _buildCalcButton('6'),
                            _buildCalcButton('+', textColor: accentRed, bgColor: opBg),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalcButton('1'),
                            _buildCalcButton('2'),
                            _buildCalcButton('3'),
                            _buildCalcButton('=', textColor: Colors.white, bgColor: Colors.green),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildCalcButton('0', flex: 2),
                            _buildCalcButton('.'),
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: SizedBox.expand(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentRed,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: _validateCalculatorAmount,
                                    child: const Icon(Icons.check, size: 24, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _validateCalculatorAmount,
                          icon: const Icon(Icons.add_card, color: Colors.white),
                          label: const Text(
                            "USE AMOUNT & ADD TRANSACTION",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerColor =
        widget.isDark ? const Color(0xFF1A1A1A) : Colors.grey[200];
    final headerTextColor = widget.isDark ? Colors.white54 : Colors.grey[600];
    final moneyColor = widget.isDark ? const Color(0xFFD71921) : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.friend.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: "Share PDF",
            onPressed: _sharePdfStatement,
          ),
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
            const Tab(
              icon: Icon(Icons.calculate_outlined, size: 20),
              text: "CALCULATOR",
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
                          onTap: () => _editTransactionDialog(tx),
                          onLongPress: () => _editTransactionDialog(tx),
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
                            "${tx.date.toString().substring(0, 16)}${tx.isEdited ? ' (edited)' : ''}",
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

          // --- TAB 2: CALCULATOR ---
          _buildCalculatorTab(headerColor, headerTextColor),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _addTransaction(),
              backgroundColor: const Color(0xFFD71921),
              tooltip: "Add Transaction",
              child: const Icon(Icons.add_card),
            )
          : null,
    );
  }
}

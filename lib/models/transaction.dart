class TransactionEdit {
  final double previousAmount;
  final String previousReason;
  final DateTime editedAt;
  final String? editNote;

  TransactionEdit({
    required this.previousAmount,
    required this.previousReason,
    required this.editedAt,
    this.editNote,
  });

  Map<String, dynamic> toJson() => {
    'previousAmount': previousAmount,
    'previousReason': previousReason,
    'editedAt': editedAt.toIso8601String(),
    if (editNote != null && editNote!.trim().isNotEmpty) 'editNote': editNote!.trim(),
  };

  factory TransactionEdit.fromJson(Map<String, dynamic> json) {
    final num pAmt = (json['previousAmount'] as num?) ?? 0;
    final String pReason = (json['previousReason'] as String?) ?? '';
    final String dateStr =
        (json['editedAt'] as String?) ?? DateTime.now().toIso8601String();

    return TransactionEdit(
      previousAmount: pAmt.toDouble(),
      previousReason: pReason,
      editedAt: DateTime.parse(dateStr),
      editNote: json['editNote'] as String?,
    );
  }
}

class Transaction {
  double amount;
  final DateTime date;
  String reason;
  final List<TransactionEdit> editHistory;

  Transaction({
    required this.amount,
    required this.date,
    required this.reason,
    List<TransactionEdit>? editHistory,
  }) : editHistory = editHistory ?? [];

  bool get isEdited => editHistory.isNotEmpty;

  void correct({
    required double newAmount,
    required String newReason,
    String? note,
  }) {
    editHistory.add(TransactionEdit(
      previousAmount: amount,
      previousReason: reason,
      editedAt: DateTime.now(),
      editNote: note,
    ));
    amount = newAmount;
    reason = newReason;
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'date': date.toIso8601String(), // Standard time string format
    'reason': reason,
    if (editHistory.isNotEmpty)
      'editHistory': editHistory.map((e) => e.toJson()).toList(),
  };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final num parsedAmount = (json['amount'] as num?) ?? 0;
    final String parsedReason = (json['reason'] as String?) ?? 'Manual Entry';
    final String parsedDate = (json['date'] as String?) ?? DateTime.now().toIso8601String();

    final rawHistory = json['editHistory'] as List<dynamic>?;
    final List<TransactionEdit> historyList = rawHistory != null
        ? rawHistory
            .map((item) => TransactionEdit.fromJson(item as Map<String, dynamic>))
            .toList()
        : <TransactionEdit>[];

    return Transaction(
      amount: parsedAmount.toDouble(),
      date: DateTime.parse(parsedDate),
      reason: parsedReason,
      editHistory: historyList,
    );
  }
}


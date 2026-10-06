class Transaction {
  final double amount;
  final DateTime date;
  final String reason;

  Transaction({
    required this.amount,
    required this.date,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'date': date.toIso8601String(), // Standard time string format
    'reason': reason,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final num parsedAmount = (json['amount'] as num?) ?? 0;
    final String parsedReason = (json['reason'] as String?) ?? 'Manual Entry';
    final String parsedDate = (json['date'] as String?) ?? DateTime.now().toIso8601String();

    return Transaction(
      amount: parsedAmount.toDouble(),
      date: DateTime.parse(parsedDate),
      reason: parsedReason,
    );
  }
}

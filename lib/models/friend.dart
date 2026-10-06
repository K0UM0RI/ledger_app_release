import 'transaction.dart';

class Friend {
  final String id;
  final String name;
  String emoji; // Profile picture emoji
  double amountOwed;
  final List<Transaction> transactions;

  // Private constructor - used by factory methods
  Friend._({
    required this.id,
    required this.name,
    required this.emoji,
    required this.amountOwed,
    required this.transactions,
  });

  // Factory for creating a new friend with initial transaction
  factory Friend({
    required String id,
    required String name,
    String? emoji,
    required double initialTransaction,
    required String initialReason,
  }) {
    return Friend._(
      id: id,
      name: name,
      emoji: emoji ?? (name.isNotEmpty ? name[0].toUpperCase() : '👤'),
      amountOwed: initialTransaction,
      transactions: [
        Transaction(
          amount: initialTransaction,
          date: DateTime.now(),
          reason: initialReason,
        ),
      ],
    );
  }

  // Factory for loading from JSON
  factory Friend.fromJson(Map<String, dynamic> json) {
    final list = (json['transactions'] as List?) ?? <dynamic>[];
    List<Transaction> txList = list.map((i) => Transaction.fromJson(i)).toList();

    final num parsedAmountOwed = (json['amountOwed'] as num?) ?? 0;
    final String parsedName = (json['name'] as String?) ?? 'Unknown';
    final String parsedId = (json['id'] as String?) ?? DateTime.now().toIso8601String();

    return Friend._(
      id: parsedId,
      name: parsedName,
      emoji: json['emoji'] ?? (parsedName.isNotEmpty ? parsedName[0].toUpperCase() : '👤'),
      amountOwed: parsedAmountOwed.toDouble(),
      transactions: txList,
    );
  }

  void addTransaction(Transaction transaction) {
    transactions.add(transaction);
    amountOwed += transaction.amount;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'amountOwed': amountOwed,
    'transactions': transactions.map((t) => t.toJson()).toList(),
  };
}

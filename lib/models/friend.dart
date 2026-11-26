import 'transaction.dart';

class TransactionCycle {
  final int cycleNumber;
  final List<Transaction> transactions;
  final bool isSettled;

  const TransactionCycle({
    required this.cycleNumber,
    required this.transactions,
    required this.isSettled,
  });

  DateTime get startDate => transactions.first.date;
  DateTime get endDate => transactions.last.date;

  /// Total positive volume exchanged in this cycle.
  /// For a settled cycle (net 0), this equals abs(sum of negative amounts).
  double get totalVolume => transactions
      .where((t) => t.amount > 0)
      .fold(0.0, (sum, t) => sum + t.amount);

  /// Net balance of this cycle (0.0 when settled).
  double get netAmount {
    final sum = transactions.fold(0.0, (s, t) => s + t.amount);
    return sum.abs() < 0.005 ? 0.0 : sum;
  }
}

class Friend {
  final String id;
  final String name;
  String emoji; // Profile picture emoji
  double amountOwed;
  final List<Transaction> transactions;
  bool isArchived;
  bool isManuallyUnarchived;

  bool get hasZeroBalance => amountOwed.abs() < 0.005;

  /// Groups transactions chronologically into settled cycles (whenever the
  /// running balance returns to 0.00) plus an optional trailing active cycle.
  List<TransactionCycle> get transactionCycles {
    if (transactions.isEmpty) return const [];

    final indexed = transactions.asMap().entries.toList()
      ..sort((a, b) {
        final cmp = a.value.date.compareTo(b.value.date);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });

    final List<TransactionCycle> cycles = [];
    List<Transaction> current = [];
    double runningBalance = 0.0;

    for (final entry in indexed) {
      final tx = entry.value;
      current.add(tx);
      runningBalance += tx.amount;

      if (runningBalance.abs() < 0.005) {
        runningBalance = 0.0;
        cycles.add(
          TransactionCycle(
            cycleNumber: cycles.length + 1,
            transactions: List<Transaction>.unmodifiable(current),
            isSettled: true,
          ),
        );
        current = [];
      }
    }

    if (current.isNotEmpty) {
      cycles.add(
        TransactionCycle(
          cycleNumber: cycles.length + 1,
          transactions: List<Transaction>.unmodifiable(current),
          isSettled: false,
        ),
      );
    }

    return cycles;
  }

  // Private constructor - used by factory methods
  Friend._({
    required this.id,
    required this.name,
    required this.emoji,
    required this.amountOwed,
    required this.transactions,
    this.isArchived = false,
    this.isManuallyUnarchived = false,
  });

  // Factory for creating a new friend with optional initial transaction
  factory Friend({
    required String id,
    required String name,
    String? emoji,
    double initialTransaction = 0.0,
    String initialReason = '',
    bool isArchived = false,
    bool isManuallyUnarchived = false,
  }) {
    final hasInitialTransaction =
        initialTransaction != 0.0 || initialReason.isNotEmpty;
    return Friend._(
      id: id,
      name: name,
      emoji: emoji ?? (name.isNotEmpty ? name[0].toUpperCase() : '👤'),
      amountOwed: initialTransaction,
      isArchived: isArchived,
      isManuallyUnarchived: isManuallyUnarchived,
      transactions: hasInitialTransaction
          ? [
              Transaction(
                amount: initialTransaction,
                date: DateTime.now(),
                reason: initialReason.isEmpty ? 'Initial' : initialReason,
              ),
            ]
          : <Transaction>[],
    );
  }

  // Factory for loading from JSON
  factory Friend.fromJson(Map<String, dynamic> json) {
    final list = (json['transactions'] as List?) ?? <dynamic>[];
    List<Transaction> txList =
        list.map((i) => Transaction.fromJson(i as Map<String, dynamic>)).toList();

    final num parsedAmountOwed = (json['amountOwed'] as num?) ?? 0;
    final String parsedName = (json['name'] as String?) ?? 'Unknown';
    final String parsedId =
        (json['id'] as String?) ?? DateTime.now().toIso8601String();
    final bool parsedIsArchived = (json['isArchived'] as bool?) ?? false;
    final bool parsedIsManuallyUnarchived =
        (json['isManuallyUnarchived'] as bool?) ?? false;

    return Friend._(
      id: parsedId,
      name: parsedName,
      emoji: json['emoji'] ??
          (parsedName.isNotEmpty ? parsedName[0].toUpperCase() : '👤'),
      amountOwed: parsedAmountOwed.toDouble(),
      transactions: txList,
      isArchived: parsedIsArchived,
      isManuallyUnarchived: parsedIsManuallyUnarchived,
    );
  }

  void addTransaction(Transaction transaction) {
    transactions.add(transaction);
    amountOwed += transaction.amount;
    if (hasZeroBalance) {
      amountOwed = 0.0;
    }
    isManuallyUnarchived = false;
  }

  void correctTransaction(
    Transaction transaction,
    double newAmount,
    String newReason, {
    String? note,
  }) {
    final diff = newAmount - transaction.amount;
    transaction.correct(
      newAmount: newAmount,
      newReason: newReason,
      note: note,
    );
    amountOwed += diff;
    if (hasZeroBalance) {
      amountOwed = 0.0;
    }
    isManuallyUnarchived = false;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'amountOwed': amountOwed,
    'isArchived': isArchived,
    'isManuallyUnarchived': isManuallyUnarchived,
    'transactions': transactions.map((t) => t.toJson()).toList(),
  };
}

import 'borrowed_item.dart';
import 'transaction.dart';

class Friend {
  final String id;
  final String name;
  String emoji; // Profile picture emoji
  double amountOwed;
  final List<Transaction> transactions;
  final List<BorrowedItem> borrowedItems;

  // Private constructor - used by factory methods
  Friend._({
    required this.id,
    required this.name,
    required this.emoji,
    required this.amountOwed,
    required this.transactions,
    required this.borrowedItems,
  });

  // Factory for creating a new friend with initial transaction
  factory Friend({
    required String id,
    required String name,
    String? emoji,
    required double initialTransaction,
    required String initialReason,
    List<BorrowedItem>? borrowedItems,
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
      borrowedItems: borrowedItems ?? <BorrowedItem>[],
    );
  }

  // Factory for loading from JSON
  factory Friend.fromJson(Map<String, dynamic> json) {
    final list = (json['transactions'] as List?) ?? <dynamic>[];
    List<Transaction> txList =
        list.map((i) => Transaction.fromJson(i as Map<String, dynamic>)).toList();

    final borrowedList = (json['borrowedItems'] as List?) ?? <dynamic>[];
    List<BorrowedItem> bList = borrowedList
        .map((i) => BorrowedItem.fromJson(i as Map<String, dynamic>))
        .toList();

    final num parsedAmountOwed = (json['amountOwed'] as num?) ?? 0;
    final String parsedName = (json['name'] as String?) ?? 'Unknown';
    final String parsedId =
        (json['id'] as String?) ?? DateTime.now().toIso8601String();

    return Friend._(
      id: parsedId,
      name: parsedName,
      emoji: json['emoji'] ??
          (parsedName.isNotEmpty ? parsedName[0].toUpperCase() : '👤'),
      amountOwed: parsedAmountOwed.toDouble(),
      transactions: txList,
      borrowedItems: bList,
    );
  }

  void addTransaction(Transaction transaction) {
    transactions.add(transaction);
    amountOwed += transaction.amount;
  }

  void addBorrowedItem(BorrowedItem item) {
    borrowedItems.add(item);
  }

  void toggleBorrowedItem(String itemId) {
    final idx = borrowedItems.indexWhere((item) => item.id == itemId);
    if (idx != -1) {
      final old = borrowedItems[idx];
      final newStatus = !old.isReturned;
      borrowedItems[idx] = old.copyWith(
        isReturned: newStatus,
        returnedDate: newStatus ? DateTime.now() : null,
      );
    }
  }

  void removeBorrowedItem(String itemId) {
    borrowedItems.removeWhere((item) => item.id == itemId);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'amountOwed': amountOwed,
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'borrowedItems': borrowedItems.map((b) => b.toJson()).toList(),
  };
}

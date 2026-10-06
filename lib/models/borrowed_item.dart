class BorrowedItem {
  final String id;
  final String name;
  final DateTime date;
  final bool isReturned;
  final DateTime? returnedDate;
  final bool isLentByMe; // true = Lent to friend, false = Borrowed from friend
  final String notes;

  BorrowedItem({
    required this.id,
    required this.name,
    required this.date,
    this.isReturned = false,
    this.returnedDate,
    this.isLentByMe = true,
    this.notes = '',
  });

  BorrowedItem copyWith({
    String? id,
    String? name,
    DateTime? date,
    bool? isReturned,
    DateTime? returnedDate,
    bool? isLentByMe,
    String? notes,
  }) {
    return BorrowedItem(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      isReturned: isReturned ?? this.isReturned,
      returnedDate: returnedDate ?? this.returnedDate,
      isLentByMe: isLentByMe ?? this.isLentByMe,
      notes: notes ?? this.notes,
    );
  }

  factory BorrowedItem.fromJson(Map<String, dynamic> json) {
    return BorrowedItem(
      id: json['id'] as String? ?? DateTime.now().toIso8601String(),
      name: json['name'] as String? ?? 'Item',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      isReturned: json['isReturned'] as bool? ?? false,
      returnedDate: json['returnedDate'] != null
          ? DateTime.parse(json['returnedDate'] as String)
          : null,
      isLentByMe: json['isLentByMe'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date.toIso8601String(),
    'isReturned': isReturned,
    'returnedDate': returnedDate?.toIso8601String(),
    'isLentByMe': isLentByMe,
    'notes': notes,
  };
}

class Transaction {
  final int? id;
  final int userId;
  final double amount;
  final String type; // 'income', 'expense'
  final int? categoryId;
  final String? description;
  final DateTime date;

  Transaction({
    this.id,
    required this.userId,
    required this.amount,
    required this.type,
    this.categoryId,
    this.description,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'category_id': categoryId,
      'description': description,
      'date': date.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      userId: map['user_id'],
      amount: map['amount'].toDouble(),
      type: map['type'],
      categoryId: map['category_id'],
      description: map['description'],
      date: DateTime.parse(map['date']),
    );
  }
}

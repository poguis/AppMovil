class DebtLoan {
  final int? id;
  final int userId;
  final String personName;
  final double amount;
  final String type; // 'debt' (debo), 'loan' (me deben)
  final String? description;
  final DateTime dateCreated;
  final DateTime? dateDue;
  final bool isPaid;

  DebtLoan({
    this.id,
    required this.userId,
    required this.personName,
    required this.amount,
    required this.type,
    this.description,
    required this.dateCreated,
    this.dateDue,
    required this.isPaid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'person_name': personName,
      'amount': amount,
      'type': type,
      'description': description,
      'date_created': dateCreated.toIso8601String(),
      'date_due': dateDue?.toIso8601String(),
      'is_paid': isPaid ? 1 : 0,
    };
  }

  factory DebtLoan.fromMap(Map<String, dynamic> map) {
    return DebtLoan(
      id: map['id'],
      userId: map['user_id'],
      personName: map['person_name'],
      amount: map['amount'].toDouble(),
      type: map['type'],
      description: map['description'],
      dateCreated: DateTime.parse(map['date_created']),
      dateDue: map['date_due'] != null ? DateTime.parse(map['date_due']) : null,
      isPaid: map['is_paid'] == 1,
    );
  }
}

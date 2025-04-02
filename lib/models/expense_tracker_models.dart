import 'package:uuid/uuid.dart';

class ExpenseEntry {
  final String id;
  final double amount;
  final String description;
  final String category;
  final DateTime timestamp;

  ExpenseEntry({
    String? id,
    required this.amount,
    required this.description,
    required this.category,
    required this.timestamp,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static ExpenseEntry fromMap(Map<String, dynamic> map) {
    return ExpenseEntry(
      id: map['id'],
      amount: map['amount'].toDouble(),
      description: map['description'],
      category: map['category'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  ExpenseEntry copyWith({
    String? id,
    double? amount,
    String? description,
    String? category,
    DateTime? timestamp,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class ExpenseSettings {
  final double dailyBudget;
  final String currency;
  final bool reminderEnabled;
  final DateTime? reminderTime;

  ExpenseSettings({
    required this.dailyBudget,
    required this.currency,
    required this.reminderEnabled,
    this.reminderTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'daily_budget': dailyBudget,
      'currency': currency,
      'reminder_enabled': reminderEnabled,
      'reminder_time': reminderTime?.toIso8601String(),
    };
  }

  static ExpenseSettings fromMap(Map<String, dynamic> map) {
    return ExpenseSettings(
      dailyBudget: map['daily_budget'].toDouble(),
      currency: map['currency'],
      reminderEnabled: map['reminder_enabled'],
      reminderTime: map['reminder_time'] != null ? DateTime.parse(map['reminder_time']) : null,
    );
  }

  ExpenseSettings copyWith({
    double? dailyBudget,
    String? currency,
    bool? reminderEnabled,
    DateTime? reminderTime,
  }) {
    return ExpenseSettings(
      dailyBudget: dailyBudget ?? this.dailyBudget,
      currency: currency ?? this.currency,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
} 
import 'package:flutter/material.dart';
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
  final TimeOfDay? reminderTime;

  const ExpenseSettings({
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
      'reminder_time': reminderTime != null
          ? '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}:00'
          : null,
    };
  }

  factory ExpenseSettings.fromMap(Map<String, dynamic> map) {
    final timeStr = map['reminder_time'] as String?;
    TimeOfDay? reminderTime;
    if (timeStr != null) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        reminderTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    return ExpenseSettings(
      dailyBudget: (map['daily_budget'] as num).toDouble(),
      currency: map['currency'] as String,
      reminderEnabled: map['reminder_enabled'] as bool,
      reminderTime: reminderTime,
    );
  }

  ExpenseSettings copyWith({
    double? dailyBudget,
    String? currency,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
  }) {
    return ExpenseSettings(
      dailyBudget: dailyBudget ?? this.dailyBudget,
      currency: currency ?? this.currency,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

class ExpenseCategory {
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.name,
    required this.icon,
    required this.color,
  });
}

// Predefined expense categories
class ExpenseCategories {
  static const List<ExpenseCategory> categories = [
    ExpenseCategory(
      name: 'Food',
      icon: Icons.restaurant,
      color: Colors.orange,
    ),
    ExpenseCategory(
      name: 'Transport',
      icon: Icons.directions_car,
      color: Colors.blue,
    ),
    ExpenseCategory(
      name: 'Shopping',
      icon: Icons.shopping_bag,
      color: Colors.purple,
    ),
    ExpenseCategory(
      name: 'Entertainment',
      icon: Icons.movie,
      color: Colors.red,
    ),
    ExpenseCategory(
      name: 'Bills',
      icon: Icons.receipt,
      color: Colors.green,
    ),
    ExpenseCategory(
      name: 'Health',
      icon: Icons.medical_services,
      color: Colors.pink,
    ),
    ExpenseCategory(
      name: 'Other',
      icon: Icons.more_horiz,
      color: Colors.grey,
    ),
  ];

  static ExpenseCategory getCategoryByName(String name) {
    return categories.firstWhere(
      (category) => category.name == name,
      orElse: () => categories.last, // Return 'Other' if not found
    );
  }
}

enum ExpenseViewType {
  daily,
  weekly,
  monthly;

  String get label {
    switch (this) {
      case ExpenseViewType.daily:
        return 'Daily';
      case ExpenseViewType.weekly:
        return 'Weekly';
      case ExpenseViewType.monthly:
        return 'Monthly';
    }
  }
} 
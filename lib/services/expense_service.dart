import 'package:flutter/foundation.dart';
import '../features/expense_tracker/models/expense_tracker_models.dart';
import 'supabase_service.dart';

class ExpenseService {
  static final ExpenseService instance = ExpenseService._();
  final SupabaseService _supabaseService = SupabaseService.instance;
  
  ExpenseService._();

  Future<List<ExpenseEntry>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _supabaseService.getExpenses(
        startDate: startDate,
        endDate: endDate,
      );
      
      return response.map((data) => ExpenseEntry.fromMap(data)).toList();
    } catch (e) {
      debugPrint('Error in ExpenseService.getExpenses: $e');
      rethrow;
    }
  }

  Future<ExpenseEntry> createExpense(ExpenseEntry expense) async {
    try {
      final response = await _supabaseService.createExpense(expense.toMap());
      return ExpenseEntry.fromMap(response);
    } catch (e) {
      debugPrint('Error in ExpenseService.createExpense: $e');
      rethrow;
    }
  }

  Future<ExpenseEntry> updateExpense(ExpenseEntry expense) async {
    try {
      if (expense.id == null) {
        throw Exception('Expense ID cannot be null for update operation');
      }
      
      final response = await _supabaseService.updateExpense(
        expense.id!,
        expense.toMap(),
      );
      
      return ExpenseEntry.fromMap(response);
    } catch (e) {
      debugPrint('Error in ExpenseService.updateExpense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _supabaseService.deleteExpense(id);
    } catch (e) {
      debugPrint('Error in ExpenseService.deleteExpense: $e');
      rethrow;
    }
  }

  Future<ExpenseSettings> getExpenseSettings() async {
    try {
      final response = await _supabaseService.getUserSettings();
      return ExpenseSettings.fromMap(response);
    } catch (e) {
      debugPrint('Error in ExpenseService.getExpenseSettings: $e');
      rethrow;
    }
  }

  Future<ExpenseSettings> updateExpenseSettings(ExpenseSettings settings) async {
    try {
      final response = await _supabaseService.updateUserSettings(settings.toMap());
      return ExpenseSettings.fromMap(response);
    } catch (e) {
      debugPrint('Error in ExpenseService.updateExpenseSettings: $e');
      rethrow;
    }
  }
} 
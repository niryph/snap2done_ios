import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_tracker_models.dart';

class ExpenseEntryItem extends StatelessWidget {
  final ExpenseEntry expense;
  final Function(ExpenseEntry) onEdit;
  final VoidCallback onDelete;
  final String currency;

  const ExpenseEntryItem({
    Key? key,
    required this.expense,
    required this.onEdit,
    required this.onDelete,
    required this.currency,
  }) : super(key: key);

  void _showEditExpenseDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController(
      text: expense.amount.toString(),
    );
    final TextEditingController descriptionController = TextEditingController(
      text: expense.description,
    );
    String selectedCategory = expense.category;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Expense',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                  ),
                  items: ExpenseCategories.categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category.name,
                      child: Row(
                        children: [
                          Icon(category.icon, color: category.color, size: 20),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedCategory = value!;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            final amount = double.tryParse(amountController.text);
                            if (amount == null || amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid amount')),
                              );
                              return;
                            }

                            final description = descriptionController.text.trim();
                            if (description.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a description')),
                              );
                              return;
                            }

                            final updatedExpense = ExpenseEntry(
                              id: expense.id,
                              amount: amount,
                              category: selectedCategory,
                              description: description,
                              timestamp: expense.timestamp,
                            );

                            Navigator.pop(context);
                            onEdit(updatedExpense);
                          },
                          child: const Text('Update'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = ExpenseCategories.getCategoryByName(expense.category);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 4.0),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Container(
          padding: const EdgeInsets.all(6.0),
          decoration: BoxDecoration(
            color: category.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Icon(
            category.icon,
            color: category.color,
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Text(
              '${currency}${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                expense.category,
                style: TextStyle(
                  fontSize: 10,
                  color: category.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          expense.description,
          style: const TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          DateFormat('HH:mm').format(expense.timestamp),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        onTap: () => _showEditExpenseDialog(context),
      ),
    );
  }
} 
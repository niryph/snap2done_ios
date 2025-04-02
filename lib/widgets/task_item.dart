import 'package:flutter/material.dart';
import '../models/task_model.dart';

class TaskItem extends StatelessWidget {
  final TaskModel task;
  final Function(bool) onToggleCompletion;

  const TaskItem({
    Key? key,
    required this.task,
    required this.onToggleCompletion,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            onChanged: (value) {
              if (value != null) {
                onToggleCompletion(value);
              }
            },
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              task.description,
              style: TextStyle(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
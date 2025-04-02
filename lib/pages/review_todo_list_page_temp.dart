import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../utils/theme_provider.dart';
import '../utils/background_patterns.dart';

class _ReviewTodoListPageState extends State<ReviewTodoListPage> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    int completedTasks = _todoItems.where((item) => item.isCompleted).length;
    double progress = _todoItems.isEmpty ? 0 : completedTasks / _todoItems.length;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: isDarkMode ? Color(0xFF1E1E2E) : Colors.white,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: backgroundWidget),
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: widget.isViewMode 
                ? Text(_titleController.text)
                : Text('Edit Todo Card'),
              actions: [
                if (widget.isViewMode)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewTodoListPage(
                            ocrText: widget.ocrText,
                            initialResult: widget.initialResult,
                            onSaveCard: widget.onSaveCard,
                            isViewMode: false,
                          ),
                        ),
                      );
                    },
                  ),
                if (!widget.isViewMode)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _deleteCard,
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(60),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completedTasks of ${_todoItems.length} tasks completed',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: _selectedColor.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(_selectedColor),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!widget.isViewMode) ...[
                            TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Card Title',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildColorPicker(),
                            const SizedBox(height: 16),
                            _buildTagEditor(),
                            const SizedBox(height: 16),
                          ],
                          _buildTodoList(),
                        ],
                      ),
                    ),
                  ),
            floatingActionButton: widget.isViewMode
                ? FloatingActionButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Add Todo'),
                          content: TextField(
                            controller: _todoController,
                            decoration: InputDecoration(
                              hintText: 'Enter todo description',
                              border: OutlineInputBorder(),
                            ),
                            autofocus: true,
                            onSubmitted: (value) async {
                              if (value.isNotEmpty) {
                                await _addTodoItem(value);
                                _todoController.clear();
                                Navigator.pop(context);
                              }
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                if (_todoController.text.isNotEmpty) {
                                  await _addTodoItem(_todoController.text);
                                  _todoController.clear();
                                  Navigator.pop(context);
                                }
                              },
                              child: Text('Add'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Icon(Icons.add),
                    backgroundColor: _selectedColor,
                  )
                : FloatingActionButton(
                    onPressed: _saveTodoCard,
                    child: const Icon(Icons.save),
                  ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          ),
        ],
      ),
    );
  }
} 
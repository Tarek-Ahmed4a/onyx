import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskItem {
  final String id;
  String title;
  bool isCompleted;

  TaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'],
        title: json['title'],
        isCompleted: json['isCompleted'] ?? false,
      );
}

class TaskCategory {
  final String id;
  String name;
  List<TaskItem> items;

  TaskCategory({
    required this.id,
    required this.name,
    List<TaskItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory TaskCategory.fromJson(Map<String, dynamic> json) => TaskCategory(
        id: json['id'],
        name: json['name'],
        items: (json['items'] as List<dynamic>?)
                ?.map((item) => TaskItem.fromJson(item))
                .toList() ??
            [],
      );
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<TaskCategory> _categories = [];
  String? _activeCategoryId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataJson = prefs.getString('calendar_tasks_data');

    if (dataJson != null) {
      final List<dynamic> decoded = json.decode(dataJson);
      setState(() {
        _categories =
            decoded.map((item) => TaskCategory.fromJson(item)).toList();
        if (_categories.isNotEmpty) {
          _activeCategoryId = _categories.first.id;
        }
        _isLoading = false;
      });
    } else {
      // Initialize with a default category if empty
      final defaultCategory = TaskCategory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'My Tasks',
        items: [],
      );
      setState(() {
        _categories = [defaultCategory];
        _activeCategoryId = defaultCategory.id;
        _isLoading = false;
      });
      await _saveTasks();
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        json.encode(_categories.map((c) => c.toJson()).toList());
    await prefs.setString('calendar_tasks_data', encoded);
  }

  void _addCategory(String name) {
    if (name.trim().isEmpty) return;
    final newCategory = TaskCategory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    setState(() {
      _categories.add(newCategory);
      _activeCategoryId = newCategory.id;
    });
    _saveTasks();
  }

  void _deleteCategory(TaskCategory category) {
    if (_categories.length <= 1) {
      // Don't delete the last category
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last list.')),
      );
      return;
    }

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete List?'),
              content: Text(
                  'Are you sure you want to delete "${category.name}" and all its tasks?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _categories.remove(category);
                      if (_activeCategoryId == category.id) {
                        _activeCategoryId = _categories.first.id;
                      }
                    });
                    _saveTasks();
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  void _addTask(String title) {
    if (title.trim().isEmpty || _activeCategoryId == null) return;
    final activeCategory =
        _categories.firstWhere((c) => c.id == _activeCategoryId);

    final newTask = TaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
    );

    setState(() {
      activeCategory.items.add(newTask);
    });
    _saveTasks();
  }

  void _deleteTask(TaskItem task) {
    if (_activeCategoryId == null) return;
    final activeCategory =
        _categories.firstWhere((c) => c.id == _activeCategoryId);

    setState(() {
      activeCategory.items.remove(task);
    });
    _saveTasks();
  }

  void _toggleTask(TaskItem task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
    _saveTasks();
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'List Name'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _addCategory(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Task Title'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _addTask(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeCategory = _categories.firstWhere(
      (c) => c.id == _activeCategoryId,
      orElse: () => _categories.first,
    );

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length + 1,
              itemBuilder: (context, index) {
                if (index == _categories.length) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ActionChip(
                      label: const Text('+ New list'),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.primary),
                      onPressed: _showAddCategoryDialog,
                    ),
                  );
                }

                final category = _categories[index];
                final isActive = category.id == _activeCategoryId;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onLongPress: () => _deleteCategory(category),
                    child: ChoiceChip(
                      label: Text(category.name),
                      selected: isActive,
                      selectedColor:
                          Theme.of(context).colorScheme.primary.withAlpha(51),
                      backgroundColor: Theme.of(context).cardColor,
                      labelStyle: TextStyle(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _activeCategoryId = category.id;
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: activeCategory.items.isEmpty
          ? Center(
              child: Text(
                'No tasks yet. Add one!',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: activeCategory.items.length,
              itemBuilder: (context, index) {
                final task = activeCategory.items[index];
                return Dismissible(
                  key: Key(task.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteTask(task),
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => _toggleTask(task),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: task.isCompleted
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Colors.grey.shade600,
                                      width: 2,
                                    ),
                                    color: task.isCompleted
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                  ),
                                  child: task.isCompleted
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Color(0xFF1E1E1E),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.isCompleted
                                    ? Colors.grey.shade500
                                    : Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

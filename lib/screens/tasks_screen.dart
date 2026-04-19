import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/premium_empty_state.dart';
import '../widgets/custom_toast.dart';
import '../widgets/elite_header.dart';
import '../widgets/elite_card.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';
import '../models/note_model.dart';
import '../services/notification_service.dart';
import 'note_detail_screen.dart';

class TaskItem {
  final String id;
  String title;
  bool isCompleted;
  DateTime? scheduledAt;

  TaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.scheduledAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'scheduledAt': scheduledAt?.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'],
        title: json['title'],
        isCompleted: json['isCompleted'] ?? false,
        scheduledAt: json['scheduledAt'] != null
            ? DateTime.parse(json['scheduledAt'])
            : null,
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
  List<Note> _notes = [];
  String? _activeCategoryId;
  bool _isLoading = true;
  String _searchQuery = '';
  StreamSubscription? _categoriesSub;
  StreamSubscription? _notesSub;

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _notesSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _scheduleNotification(TaskItem task) async {
    if (task.scheduledAt == null) return;
    await NotificationService().scheduleTaskReminder(task.id, task.title, task.scheduledAt!);
  }

  Future<void> _cancelNotification(TaskItem task) async {
    await NotificationService().cancelTaskReminder(task.id);
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _categoriesSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('task_categories')
        .snapshots()
        .listen((snapshot) async {
      final loadedCats = snapshot.docs
          .map((doc) => TaskCategory.fromJson(doc.data()))
          .toList();

      if (loadedCats.isEmpty) {
        final defaultCategory = TaskCategory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'My Tasks',
          items: [],
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('task_categories')
            .doc(defaultCategory.id)
            .set(defaultCategory.toJson());
        return;
      }

      if (mounted) {
        setState(() {
          _categories = loadedCats;
          if (_activeCategoryId == null ||
              !loadedCats.any((c) => c.id == _activeCategoryId)) {
            _activeCategoryId = loadedCats.first.id;
          }
          _isLoading = false;
        });
      }
    });

    _notesSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notes')
        .snapshots()
        .listen((snapshot) {
      final loadedNotes =
          snapshot.docs.map((doc) => Note.fromJson(doc.data())).toList();
      loadedNotes.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) {
        setState(() {
          _notes = loadedNotes;
        });
      }
    });
  }

  void _addCategory(String name) async {
    if (name.trim().isEmpty) return;
    final newCategory = TaskCategory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('task_categories')
        .doc(newCategory.id)
        .set(newCategory.toJson());
    setState(() => _activeCategoryId = newCategory.id);
  }

  void _deleteCategory(TaskCategory category) {
    if (_categories.length <= 1) {
      CustomToast.show(
        context: context,
        message: 'Cannot delete the last list.',
        icon: Icons.warning_amber_rounded,
        color: Colors.orangeAccent,
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
                  onPressed: () async {
                    for (var task in category.items) {
                      _cancelNotification(task);
                    }
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('task_categories')
                          .doc(category.id)
                          .delete();
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        if (_activeCategoryId == category.id) {
                          _activeCategoryId = _categories
                              .firstWhere((c) => c.id != category.id)
                              .id;
                        }
                      });
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  void _addTask(String title, [DateTime? scheduledAt]) async {
    if (title.trim().isEmpty || _activeCategoryId == null) return;
    final activeCategory =
        _categories.firstWhere((c) => c.id == _activeCategoryId);

    final newTask = TaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      scheduledAt: scheduledAt,
    );

    HapticFeedback.lightImpact();
    activeCategory.items.add(newTask);
    if (scheduledAt != null) {
      _scheduleNotification(newTask);
    }
    CustomToast.show(
      context: context,
      message: 'Task added',
      icon: Icons.add_task,
      color: Colors.blueAccent,
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('task_categories')
          .doc(activeCategory.id)
          .set(activeCategory.toJson());
    }
  }

  void _deleteTask(TaskItem task) async {
    if (_activeCategoryId == null) return;
    final activeCategory =
        _categories.firstWhere((c) => c.id == _activeCategoryId);

    activeCategory.items.remove(task);
    _cancelNotification(task);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('task_categories')
          .doc(activeCategory.id)
          .set(activeCategory.toJson());
    }
  }

  void _toggleTask(TaskItem task) async {
    HapticFeedback.selectionClick();
    task.isCompleted = !task.isCompleted;

    if (task.isCompleted) {
      _cancelNotification(task);
    } else if (task.scheduledAt != null &&
        task.scheduledAt!.isAfter(DateTime.now())) {
      _scheduleNotification(task);
    }

    setState(() {});

    if (_activeCategoryId == null) return;
    final activeCategory =
        _categories.firstWhere((c) => c.id == _activeCategoryId);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('task_categories')
          .doc(activeCategory.id)
          .set(activeCategory.toJson());
    }
  }

  void _saveNoteFromDetail(Note note, bool isNew) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(note.id)
          .set(note.toJson());
    }
  }

  void _deleteNote(Note note) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(note.id)
          .delete();
    }
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
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('New Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  selectedDate == null
                                      ? 'Date'
                                      : '${selectedDate!.month}/${selectedDate!.day}',
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => selectedTime = time);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  selectedTime == null
                                      ? 'Time'
                                      : selectedTime!.format(context),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  DateTime? finalDateTime;
                  if (selectedDate != null) {
                    final time =
                        selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
                    finalDateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      time.hour,
                      time.minute,
                    );
                  }
                  _addTask(controller.text, finalDateTime);

                  if (finalDateTime != null) {
                    final timeString =
                        TimeOfDay.fromDateTime(finalDateTime).format(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Task saved. Alarm set for $timeString')),
                    );
                  }

                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Access Restricted',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign in to manage your personal workspace.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        body: Column(
          children: [
            const EliteHeader(title: 'Workspace'),
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  return Shimmer.fromColors(
                    baseColor: Colors.white.withValues(alpha: 0.05),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Container(
                      height: 70,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    final activeCategory = _categories.firstWhere(
      (c) => c.id == _activeCategoryId,
      orElse: () => _categories.first,
    );

    final categorySelector = SizedBox(
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
                label: const Text('+ New', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                onPressed: _showAddCategoryDialog,
              ),
            );
          }

          final category = _categories[index];
          final isSelected = category.id == _activeCategoryId;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onLongPress: () => _deleteCategory(category),
              child: ChoiceChip(
                label: Text(category.name),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _activeCategoryId = category.id;
                    });
                  }
                },
                backgroundColor: Colors.transparent,
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        },
      ),
    );

    final filteredTasks = activeCategory.items;

    final tasksListView = filteredTasks.isEmpty
        ? const PremiumEmptyState(
            icon: Icons.checklist_rtl_rounded,
            title: 'All Tasks Done!',
            subtitle: 'You are all caught up for this category. Add a new task to keep the momentum going.',
          )
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return Dismissible(
                key: Key(task.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteTask(task),
                child: EliteCard(
                   margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                               width: 20,
                               height: 20,
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 border: Border.all(
                                   color: task.isCompleted
                                       ? Theme.of(context).colorScheme.primary
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
                                       size: 14,
                                       color: Color(0xFF1E1E1E),
                                     )
                                   : null,
                             ),
                           ),
                         ),
                       ),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               task.title,
                               style: TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.bold,
                                 decoration: task.isCompleted
                                     ? TextDecoration.lineThrough
                                     : null,
                                 color: task.isCompleted
                                     ? Colors.grey.shade500
                                     : Colors.white,
                               ),
                             ),
                             if (task.scheduledAt != null) ...[
                               const SizedBox(height: 4),
                               Row(
                                 children: [
                                   Icon(
                                     Icons.alarm,
                                     size: 12,
                                     color: task.isCompleted
                                         ? Colors.grey.shade500
                                         : Theme.of(context)
                                             .colorScheme
                                             .primary,
                                   ),
                                   const SizedBox(width: 4),
                                   Text(
                                     '${task.scheduledAt!.month}/${task.scheduledAt!.day} at ${TimeOfDay.fromDateTime(task.scheduledAt!).format(context)}',
                                     style: TextStyle(
                                       fontSize: 10,
                                       fontWeight: FontWeight.bold,
                                       color: task.isCompleted
                                           ? Colors.grey.shade600
                                           : Colors.grey.shade400,
                                     ),
                                   ),
                                 ],
                               ),
                             ],
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
              );
            },
          );

    final tasksView = Column(
      children: [
        categorySelector,
        Expanded(child: tasksListView),
      ],
    );

    final filteredNotes = _notes
        .where((n) =>
            n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            n.content.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final notesGrid = filteredNotes.isEmpty
        ? const PremiumEmptyState(
            icon: Icons.note_alt_outlined,
            title: 'No Notes Found',
            subtitle: 'Start writing your thoughts and ideas. Tap + to create a note.',
          )
        : MasonryGridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: filteredNotes.length,
            itemBuilder: (context, index) {
              final note = filteredNotes[index];
              return Dismissible(
                key: Key(note.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteNote(note),
                child: EliteCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteDetailScreen(
                          note: note,
                          onSave: _saveNoteFromDetail,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.title.isNotEmpty)
                          Text(
                            note.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (note.title.isNotEmpty && note.content.isNotEmpty)
                          const SizedBox(height: 8),
                        if (note.content.isNotEmpty)
                          Text(
                            note.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '${note.date.month}/${note.date.day}/${note.date.year}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );

    final notesView = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search notes',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[850],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),
        Expanded(child: notesGrid),
      ],
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFFFFFFFF),
            labelColor: Color(0xFFFFFFFF),
            unselectedLabelColor: Color(0xFF888888),
            tabs: [
              Tab(text: 'To-Do'),
              Tab(text: 'Notes'),
            ],
          ),
        ),
        body: Column(
          children: [
            const EliteHeader(title: 'Workspace'),
            Expanded(
              child: TabBarView(
                children: [
                  tasksView,
                  notesView,
                ],
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                final isNotesTab = tabController.index == 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 90.0),
                  child: FloatingActionButton(
                    onPressed: isNotesTab
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NoteDetailScreen(
                                  onSave: _saveNoteFromDetail,
                                ),
                              ),
                            )
                        : _showAddTaskDialog,
                    child: Icon(isNotesTab ? Icons.edit_note : Icons.add),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../main.dart';
import '../models/note_model.dart';
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
    _requestPermissions();
    _loadData();
  }

  Future<void> _requestPermissions() async {
    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }

  Future<void> _scheduleNotification(TaskItem task) async {
    if (task.scheduledAt == null) return;

    final tz.TZDateTime scheduledDate =
        tz.TZDateTime.from(task.scheduledAt!, tz.local);

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        task.id.hashCode,
        'Task Reminder',
        task.title,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders_channel',
            'Task Reminders',
            channelDescription: 'Notifications for scheduled tasks',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _cancelNotification(TaskItem task) async {
    await flutterLocalNotificationsPlugin.cancel(task.id.hashCode);
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

    activeCategory.items.add(newTask);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('task_categories')
          .doc(activeCategory.id)
          .set(activeCategory.toJson());
    }

    if (scheduledAt != null) {
      _scheduleNotification(newTask);
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Tasks Locked',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign in to manage your tasks and notes.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
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
                label:
                    const Text('+ New', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
    );

    final tasksListView = activeCategory.items.isEmpty
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
                                        size: 16,
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
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isCompleted
                                      ? Colors.grey.shade500
                                      : Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color,
                                ),
                              ),
                              if (task.scheduledAt != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.alarm,
                                      size: 14,
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
                                        fontSize: 12,
                                        color: task.isCompleted
                                            ? Colors.grey.shade500
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
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
        ? Center(
            child: Text(
              'No notes found.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          )
        : MasonryGridView.builder(
            padding:
                const EdgeInsets.only(top: 8, bottom: 80, left: 16, right: 16),
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
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Colors.grey[850],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteDetailScreen(
                          note: note,
                          onSave: _saveNoteFromDetail,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
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
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withAlpha(200),
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
        appBar: AppBar(
          title: const Text('Tasks & Notes',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined,
                  color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CalendarScreen()),
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
        body: TabBarView(
          children: [
            tasksView,
            notesView,
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                final isNotesTab = tabController.index == 1;
                return FloatingActionButton(
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}

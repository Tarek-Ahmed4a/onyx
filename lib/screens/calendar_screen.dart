import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/elite_dialog.dart';
import 'profile_screen.dart';

class CalendarTask {
  final String id;
  String title;
  bool isCompleted;
  int? colorCode;
  DateTime? scheduledTime;

  CalendarTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.colorCode,
    this.scheduledTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'colorCode': colorCode,
        'scheduledTime': scheduledTime?.toIso8601String(),
      };

  factory CalendarTask.fromJson(Map<String, dynamic> json) => CalendarTask(
        id: json['id'],
        title: json['title'],
        isCompleted: json['isCompleted'] ?? false,
        colorCode: json['colorCode'],
        scheduledTime: json['scheduledTime'] != null
            ? DateTime.parse(json['scheduledTime'])
            : null,
      );
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ValueNotifier<List<CalendarTask>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, List<CalendarTask>> _tasks = {};
  StreamSubscription? _calendarSub;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadTasks();
  }

  @override
  void dispose() {
    _calendarSub?.cancel();
    _selectedEvents.dispose();
    super.dispose();
  }

  // Normalize to UTC midnight to perfectly match table_calendar's internal logic
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    final normalized = _normalizeDate(date);
    return "${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}";
  }

  List<CalendarTask> _getEventsForDay(DateTime day) {
    return _tasks[_dateKey(day)] ?? [];
  }

  Future<void> _loadTasks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _calendarSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('calendar_days')
        .snapshots()
        .listen((snapshot) {
      final newTasks = <String, List<CalendarTask>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['tasks'] != null) {
          final tasks = (data['tasks'] as List<dynamic>)
              .map((item) => CalendarTask.fromJson(item))
              .toList();
          newTasks[doc.id] = tasks;
        }
      }
      if (mounted) {
        setState(() {
          _tasks = newTasks;
        });
        if (_selectedDay != null) {
            _selectedEvents.value = _getEventsForDay(_selectedDay!);
        }
      }
    });
  }

  void _addTask(String title, [int? colorCode, DateTime? scheduledTime]) async {
    if (title.trim().isEmpty || _selectedDay == null) return;
    final key = _dateKey(_selectedDay!);
    final newTask = CalendarTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      colorCode: colorCode,
      scheduledTime: scheduledTime,
    );

    final currentList = _tasks[key] ?? [];
    currentList.add(newTask);
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('calendar_days').doc(key).set({
        'tasks': currentList.map((t) => t.toJson()).toList(),
      });
    }
  }

  void _deleteTask(CalendarTask task) async {
    if (_selectedDay == null) return;
    final key = _dateKey(_selectedDay!);
    final currentList = _tasks[key] ?? [];
    currentList.removeWhere((t) => t.id == task.id);
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('calendar_days').doc(key).set({
        'tasks': currentList.map((t) => t.toJson()).toList(),
      });
    }
  }

  void _toggleTask(CalendarTask task) async {
    if (_selectedDay == null) return;
    final key = _dateKey(_selectedDay!);
    
    task.isCompleted = !task.isCompleted;
    
    final currentList = _tasks[key] ?? [];
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('calendar_days').doc(key).set({
        'tasks': currentList.map((t) => t.toJson()).toList(),
      });
    }
  }

  void _showAddTaskDialog() {
    final controller = TextEditingController();
    int? selectedColor = Theme.of(context).colorScheme.primary.toARGB32();
    TimeOfDay? selectedTime;

    final List<int> presetColors = [
      Theme.of(context).colorScheme.primary.toARGB32(), // Brand Gold/Primary
      0xFFE53935, // Deep Red
      0xFF43A047, // Emerald Green
    ];

    EliteDialog.show(
      context: context,
      title: 'Calendar Event',
      glowColor: Color(selectedColor),
      content: StatefulBuilder(builder: (context, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'EVENT TITLE',
                labelStyle: const TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w900, color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: selectedTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setDialogState(() => selectedTime = time);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time, size: 16, color: Color(selectedColor!)),
                    const SizedBox(width: 8),
                    Text(
                      selectedTime == null ? 'SELECT TIME' : selectedTime!.format(context),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'COLOR PALETTE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...presetColors.map((colorValue) {
                  final isSelected = selectedColor == colorValue;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = colorValue),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(colorValue),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.white10),
                        boxShadow: [
                            if (isSelected) BoxShadow(color: Color(colorValue).withValues(alpha: 0.5), blurRadius: 10)
                        ],
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () {
                    Color pickerColor = Color(selectedColor ?? Theme.of(context).colorScheme.primary.toARGB32());
                    EliteDialog.show(
                      context: context,
                      title: 'Custom Spectrum',
                      glowColor: pickerColor,
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: pickerColor,
                          onColorChanged: (Color color) {
                            pickerColor = color;
                          },
                          pickerAreaHeightPercent: 0.8,
                          enableAlpha: false,
                          displayThumbColor: true,
                          paletteType: PaletteType.hsvWithHue,
                          labelTypes: const [],
                        ),
                      ),
                      actions: [
                        FilledButton(
                          child: const Text('SAVE'),
                          onPressed: () {
                            setDialogState(() => selectedColor = pickerColor.toARGB32());
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
                      ),
                    ),
                    child: const Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () {
            DateTime? scheduledDateTime;
            if (selectedTime != null && _selectedDay != null) {
              scheduledDateTime = DateTime(
                _selectedDay!.year,
                _selectedDay!.month,
                _selectedDay!.day,
                selectedTime!.hour,
                selectedTime!.minute,
              );
            }
            _addTask(controller.text, selectedColor, scheduledDateTime);
            Navigator.pop(context);
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }

  Widget _buildTaskPill(CalendarTask task) {
    Color bgColor = task.isCompleted
        ? Colors.grey[800]!
        : (task.colorCode != null ? Color(task.colorCode!) : Theme.of(context).colorScheme.primary);

    return Container(
      margin: const EdgeInsets.only(bottom: 2, left: 2, right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 8,
          color: task.isCompleted ? Colors.grey[400] : Colors.white,
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  Widget _buildCalendarCell(
    DateTime day, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final events = _getEventsForDay(day);

    TextStyle textStyle = TextStyle(
      fontSize: 12, // Reduced font size
      color: isOutside ? Colors.grey[700] : const Color(0xFFE0E0E0),
      fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
    );

    Widget dayNumberWidget = Text('${day.day}', style: textStyle);

    if (isToday) {
      dayNumberWidget = Container(
        decoration: const BoxDecoration(
          color: Color(0xFFD4AF37),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(4), // Reduced padding
        child: Text(
          '${day.day}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF121212), fontWeight: FontWeight.bold),
        ),
      );
    } else if (isSelected) {
      dayNumberWidget = Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Reduced padding
        child: Text(
          '${day.day}',
          style: const TextStyle(fontSize: 12, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
        ),
      );
    }

    final displayTasks = events.take(2).toList();
    final remainingCount = events.length - displayTasks.length;

    return Container(
      clipBehavior: Clip.hardEdge, // Prevent overflow bleed
      decoration: BoxDecoration(
        color: isOutside ? const Color(0xFF0C0C0C) : Colors.transparent,
        border: Border.all(color: Colors.grey[900]!, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.topCenter,
            child: dayNumberWidget,
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min, // Do not artificialy expand
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...displayTasks.map((task) => _buildTaskPill(task)),
              if (remainingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
                  child: Text(
                    '+$remainingCount more',
                    style: TextStyle(fontSize: 8, color: Colors.grey[400]), // Reduced font size
                  ),
                ),
            ],
          ),
        ],
      ),
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
              const Icon(Icons.calendar_today_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Calendar Locked',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign in to view your calendar and events.',
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
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        actions: [
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
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF000000),
            child: TableCalendar<CalendarTask>(
              firstDay: DateTime.utc(2000, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              rowHeight: 73,
              daysOfWeekHeight: 30,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.saturday,
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _selectedEvents.value = _getEventsForDay(selectedDay);
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() => _calendarFormat = format);
                }
              },
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              calendarStyle: const CalendarStyle(
                markersMaxCount: 0,
                outsideDaysVisible: true,
              ),
              calendarBuilders: CalendarBuilders<CalendarTask>(
                defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(day),
                todayBuilder: (context, day, focusedDay) => _buildCalendarCell(day, isToday: true),
                selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(day, isSelected: true, isToday: isSameDay(day, DateTime.now())),
                outsideBuilder: (context, day, focusedDay) => _buildCalendarCell(day, isOutside: true),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                leftChevronIcon:
                    Icon(Icons.chevron_left, color: Color(0xFFE0E0E0)),
                rightChevronIcon:
                    Icon(Icons.chevron_right, color: Color(0xFFE0E0E0)),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Color(0xFFE0E0E0)),
                weekendStyle: TextStyle(color: Color(0xFFE0E0E0)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<List<CalendarTask>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {
                if (value.isEmpty) {
                  return Center(
                    child: Text(
                      'No events for this day.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final task = value[index];
                    return Dismissible(
                      key: Key(task.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
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
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
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
                                      duration:
                                          const Duration(milliseconds: 200),
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
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.transparent,
                                      ),
                                      child: task.isCompleted
                                          ? Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Theme.of(context).colorScheme.onPrimary,
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
                                            : Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    if (task.scheduledTime != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: task.isCompleted
                                                ? Colors.grey.shade500
                                                : (task.colorCode != null ? Color(task.colorCode!) : Theme.of(context).colorScheme.primary),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            TimeOfDay.fromDateTime(task.scheduledTime!).format(context),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: task.isCompleted
                                                  ? Colors.grey.shade500
                                                  : (task.colorCode != null ? Color(task.colorCode!) : Theme.of(context).colorScheme.primary),
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
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          onPressed: _showAddTaskDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

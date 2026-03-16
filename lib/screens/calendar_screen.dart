import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarTask {
  final String id;
  String title;
  bool isCompleted;

  CalendarTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory CalendarTask.fromJson(Map<String, dynamic> json) => CalendarTask(
        id: json['id'],
        title: json['title'],
        isCompleted: json['isCompleted'] ?? false,
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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadTasks();
  }

  @override
  void dispose() {
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
    final prefs = await SharedPreferences.getInstance();
    final String? dataJson = prefs.getString('calendar_daily_tasks');
    if (dataJson != null) {
      final Map<String, dynamic> decoded = json.decode(dataJson);
      setState(() {
        _tasks = decoded.map((key, value) {
          return MapEntry(
            key,
            (value as List<dynamic>)
                .map((item) => CalendarTask.fromJson(item))
                .toList(),
          );
        });
      });
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(
      _tasks.map(
          (key, value) => MapEntry(key, value.map((t) => t.toJson()).toList())),
    );
    await prefs.setString('calendar_daily_tasks', encoded);
  }

  void _addTask(String title) {
    if (title.trim().isEmpty || _selectedDay == null) return;
    final key = _dateKey(_selectedDay!);
    final newTask = CalendarTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
    );

    setState(() {
      if (_tasks[key] != null) {
        _tasks[key]!.add(newTask);
      } else {
        _tasks[key] = [newTask];
      }
    });

    _selectedEvents.value = _getEventsForDay(_selectedDay!);
    _saveTasks();
  }

  void _deleteTask(CalendarTask task) {
    if (_selectedDay == null) return;
    final key = _dateKey(_selectedDay!);
    setState(() {
      _tasks[key]?.remove(task);
    });
    _selectedEvents.value = _getEventsForDay(_selectedDay!);
    _saveTasks();
  }

  void _toggleTask(CalendarTask task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
    _selectedEvents.value = _getEventsForDay(_selectedDay!);
    _saveTasks();
  }

  void _showAddTaskDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Calendar Event'),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskPill(CalendarTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2, left: 2, right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: task.isCompleted ? Colors.grey[800] : const Color(0xFF1E88E5), // Blue background for tasks
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
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
        padding: const EdgeInsets.all(6),
        child: Text(
          '${day.day}',
          style: const TextStyle(color: Color(0xFF121212), fontWeight: FontWeight.bold),
        ),
      );
    } else if (isSelected) {
      dayNumberWidget = Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '${day.day}',
          style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
        ),
      );
    }

    final displayTasks = events.take(2).toList();
    final remainingCount = events.length - displayTasks.length;

    return Container(
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...displayTasks.map((task) => _buildTaskPill(task)),
              if (remainingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
                  child: Text(
                    '+$remainingCount more',
                    style: TextStyle(fontSize: 9, color: Colors.grey[400]),
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
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
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
              startingDayOfWeek: StartingDayOfWeek.monday,
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

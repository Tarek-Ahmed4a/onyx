import 'package:flutter/material.dart';
import '../models/note_model.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note? note;
  final Function(Note, bool isNew) onSave;

  const NoteDetailScreen({super.key, this.note, required this.onSave});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _category;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _category = widget.note?.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveAndPop() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
        Navigator.pop(context);
        return;
    }

    final now = DateTime.now();
    Note finalNote;
    bool isNew = false;
    if (widget.note == null) {
      finalNote = Note(
        id: now.millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        date: now,
        category: _category,
      );
      isNew = true;
    } else {
      finalNote = widget.note!;
      finalNote.title = title;
      finalNote.content = content;
      finalNote.date = now;
      finalNote.category = _category;
    }

    widget.onSave(finalNote, isNew);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), 
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _saveAndPop,
                  ),
                  const Text('All notes', style: TextStyle(fontSize: 16)),
                  const Icon(Icons.arrow_drop_down),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.calendar_today), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: () {}),
                  const CircleAvatar(
                    radius: 14,
                    child: Icon(Icons.person, size: 18),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            // Title Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            // Middle section (Date/Time and Category)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Text(
                    '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_category ?? 'No category', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade400, size: 16),
                      ],
                    ),
                  )
                ],
              ),
            ),
            // Main Body (TextField)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Start typing...',
                    border: InputBorder.none,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            // Bottom Toolbar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(top: BorderSide(color: Colors.grey.shade800)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   IconButton(icon: const Icon(Icons.check_box_outlined), onPressed: () {}),
                   IconButton(icon: const Icon(Icons.text_format), onPressed: () {}),
                   IconButton(icon: const Icon(Icons.image_outlined), onPressed: () {}),
                   IconButton(icon: const Icon(Icons.edit), onPressed: () {}), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                  const Spacer(),
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
            // Middle section (Date/Time)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.note != null ? widget.note!.date.month : DateTime.now().month}/${widget.note != null ? widget.note!.date.day : DateTime.now().day}/${widget.note != null ? widget.note!.date.year : DateTime.now().year}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

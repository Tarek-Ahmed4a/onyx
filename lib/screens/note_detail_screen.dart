import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/note_model.dart';
import '../widgets/elite_dialog.dart';

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
  late TextEditingController _categoryController;
  String? _category;
  bool _isPinned = false;
  int? _selectedColor;
  TextAlign _textAlign = TextAlign.left;

  final List<int> _noteColors = [
    0xFF1E1E1E, // Default Dark
    0xFF2D2910, // Dim Yellow
    0xFF1B2D1B, // Dim Green
    0xFF1B2B32, // Dim Blue
    0xFF2D1B2D, // Dim Purple
    0xFF321B1B, // Dim Red
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _category = widget.note?.category;
    _categoryController = TextEditingController(text: _category ?? '');
    _isPinned = widget.note?.isPinned ?? false;
    _selectedColor = widget.note?.colorValue;
    _textAlign = widget.note?.textAlign == 'right' ? TextAlign.right : TextAlign.left;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _saveAndPop() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final category = _categoryController.text.trim();
    
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
        category: category.isEmpty ? null : category,
        isPinned: _isPinned,
        colorValue: _selectedColor,
        textAlign: _textAlign == TextAlign.right ? 'right' : 'left',
      );
      isNew = true;
    } else {
      finalNote = widget.note!;
      finalNote.title = title;
      finalNote.content = content;
      finalNote.date = now;
      finalNote.category = category.isEmpty ? null : category;
      finalNote.isPinned = _isPinned;
      finalNote.colorValue = _selectedColor;
      finalNote.textAlign = _textAlign == TextAlign.right ? 'right' : 'left';
    }

    widget.onSave(finalNote, isNew);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(_selectedColor ?? 0xFF000000);
    return Scaffold(
      backgroundColor: bgColor, 
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bgColor,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
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
                    IconButton(
                      icon: Icon(_textAlign == TextAlign.left ? Icons.format_align_left : Icons.format_align_right),
                      onPressed: () {
                        setState(() {
                          _textAlign = _textAlign == TextAlign.left ? TextAlign.right : TextAlign.left;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                      color: _isPinned ? Theme.of(context).colorScheme.primary : Colors.white,
                      onPressed: () {
                        setState(() {
                          _isPinned = !_isPinned;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.palette_outlined),
                      onPressed: () {
                        _showColorPicker();
                      },
                    ),
                  ],
                ),
              ),
              // Category Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _categoryController,
                  textAlign: _textAlign,
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    letterSpacing: 1.2,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'ADD CATEGORY/TAG',
                    hintStyle: TextStyle(fontSize: 10, letterSpacing: 1),
                    border: InputBorder.none,
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              // Title Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _titleController,
                  textAlign: _textAlign,
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
                  alignment: _textAlign == TextAlign.left ? Alignment.centerLeft : Alignment.centerRight,
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
                    textAlign: _textAlign,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Start typing...',
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker() {
    Color pickerColor = Color(_selectedColor ?? 0xFF1E1E1E);
    
    EliteDialog.show(
      context: context,
      title: 'Note Aesthetics',
      glowColor: pickerColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PRESETS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _noteColors.length,
              itemBuilder: (context, index) {
                final colorVal = _noteColors[index];
                final isSelected = _selectedColor == (colorVal == 0xFF1E1E1E ? null : colorVal);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorVal == 0xFF1E1E1E ? null : colorVal;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Color(colorVal),
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.white10),
                      boxShadow: [
                        if (isSelected) BoxShadow(color: Color(colorVal).withValues(alpha: 0.5), blurRadius: 10)
                      ],
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'CUSTOM HUD',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 12),
          ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
            labelTypes: const [],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () {
            setState(() {
              _selectedColor = pickerColor.toARGB32();
            });
            Navigator.pop(context);
          },
          child: const Text('APPLY'),
        ),
      ],
    );
  }
}

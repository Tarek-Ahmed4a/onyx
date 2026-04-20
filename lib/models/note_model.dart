class Note {
  final String id;
  String title;
  String content;
  DateTime date;
  String? category;
  bool isPinned;
  int? colorValue;
  String textAlign;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.category,
    this.isPinned = false,
    this.colorValue,
    this.textAlign = 'left',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date.toIso8601String(),
        if (category != null) 'category': category,
        'isPinned': isPinned,
        if (colorValue != null) 'colorValue': colorValue,
        'textAlign': textAlign,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        date: DateTime.parse(json['date']),
        category: json['category'],
        isPinned: json['isPinned'] ?? false,
        colorValue: json['colorValue'],
        textAlign: json['textAlign'] ?? 'left',
      );
}

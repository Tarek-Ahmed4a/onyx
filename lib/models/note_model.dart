class Note {
  final String id;
  String title;
  String content;
  DateTime date;
  String? category;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date.toIso8601String(),
        if (category != null) 'category': category,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        date: DateTime.parse(json['date']),
        category: json['category'],
      );
}

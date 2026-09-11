/// Content received from another app through the operating system share sheet.
class SharedContent {
  final String? text;
  final String? subject;
  final String? filePath;
  final String? mimeType;

  const SharedContent({this.text, this.subject, this.filePath, this.mimeType});

  factory SharedContent.fromMap(Map<dynamic, dynamic> map) {
    return SharedContent(
      text: map['text']?.toString(),
      subject: map['subject']?.toString(),
      filePath: map['filePath']?.toString(),
      mimeType: map['mimeType']?.toString(),
    );
  }

  bool get hasFile => filePath != null && filePath!.isNotEmpty;
  bool get isImage => mimeType?.startsWith('image/') == true;
  bool get isVideo => mimeType?.startsWith('video/') == true;
  bool get isSupported => hasFile || (text?.trim().isNotEmpty == true);

  String get displayText => (text ?? subject ?? '').trim();
}

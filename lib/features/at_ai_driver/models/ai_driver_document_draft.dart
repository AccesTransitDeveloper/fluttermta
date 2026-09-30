class AiDriverDocumentDraft {
  final String id;
  final String title;
  final String description;
  final String? localFilePath;
  final String? originalFileName;
  final DateTime? capturedAt;
  final String uploadStatus;

  const AiDriverDocumentDraft({
    required this.id,
    required this.title,
    required this.description,
    this.localFilePath,
    this.originalFileName,
    this.capturedAt,
    this.uploadStatus = 'notSubmitted',
  });

  bool get isCollected =>
      localFilePath != null && localFilePath!.trim().isNotEmpty;

  AiDriverDocumentDraft copyWith({
    String? localFilePath,
    String? originalFileName,
    DateTime? capturedAt,
  }) {
    return AiDriverDocumentDraft(
      id: id,
      title: title,
      description: description,
      localFilePath: localFilePath ?? this.localFilePath,
      originalFileName: originalFileName ?? this.originalFileName,
      capturedAt: capturedAt ?? this.capturedAt,
      uploadStatus: localFilePath != null ? 'notSubmitted' : uploadStatus,
    );
  }

  AiDriverDocumentDraft withoutFile() {
    return AiDriverDocumentDraft(
      id: id,
      title: title,
      description: description,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'localFilePath': localFilePath,
    'originalFileName': originalFileName,
    'capturedAt': capturedAt?.toIso8601String(),
    'uploadStatus': uploadStatus,
    'networkDestination': null,
  };

  factory AiDriverDocumentDraft.fromJson(Map<String, dynamic> json) {
    return AiDriverDocumentDraft(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      localFilePath: json['localFilePath'] as String?,
      originalFileName: json['originalFileName'] as String?,
      capturedAt: json['capturedAt'] == null
          ? null
          : DateTime.tryParse(json['capturedAt'] as String),
      uploadStatus:
          const {'uploaded', 'uncertain'}.contains(json['uploadStatus'])
          ? json['uploadStatus'] as String
          : 'notSubmitted',
    );
  }

  AiDriverDocumentDraft markUploaded() => AiDriverDocumentDraft(
    id: id,
    title: title,
    description: description,
    localFilePath: localFilePath,
    originalFileName: originalFileName,
    capturedAt: capturedAt,
    uploadStatus: 'uploaded',
  );

  AiDriverDocumentDraft markUncertain() => AiDriverDocumentDraft(
    id: id,
    title: title,
    description: description,
    localFilePath: localFilePath,
    originalFileName: originalFileName,
    capturedAt: capturedAt,
    uploadStatus: 'uncertain',
  );
}

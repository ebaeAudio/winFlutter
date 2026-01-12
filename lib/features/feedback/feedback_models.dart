enum FeedbackKind {
  bug('bug', 'Report a bug'),
  improvement('improvement', 'Suggest an improvement');

  const FeedbackKind(this.dbValue, this.label);

  final String dbValue;
  final String label;
}

class FeedbackDraft {
  const FeedbackDraft({
    required this.kind,
    required this.description,
    this.details,
    this.entryPoint,
    this.includeContext = true,
  });

  final FeedbackKind kind;
  final String description;
  final String? details;
  final String? entryPoint;
  final bool includeContext;
}


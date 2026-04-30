enum DocumentReviewStatus {
  pending,
  approved,
  rejected;

  String get value => switch (this) {
        DocumentReviewStatus.pending => 'PENDING',
        DocumentReviewStatus.approved => 'APPROVED',
        DocumentReviewStatus.rejected => 'REJECTED',
      };

  static DocumentReviewStatus fromRaw(dynamic raw) {
    final normalized = raw?.toString().trim().toUpperCase();
    return switch (normalized) {
      'APPROVED' => DocumentReviewStatus.approved,
      'REJECTED' => DocumentReviewStatus.rejected,
      _ => DocumentReviewStatus.pending,
    };
  }
}

class MaintenancePriority {
  static const low = 'LOW';
  static const medium = 'MEDIUM';
  static const high = 'HIGH';
}

class MaintenanceStatus {
  static const marked = 'MARKED';
  static const inProgress = 'IN_PROGRESS';
  static const completed = 'COMPLETED';
}

class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.machineId,
    required this.issueTitle,
    required this.issueDescription,
    required this.priority,
    required this.status,
    required this.reportedByName,
    required this.startedByName,
    required this.completedByName,
    required this.reportedAt,
    required this.startedAt,
    required this.completedAt,
    required this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int machineId;
  final String issueTitle;
  final String? issueDescription;
  final String priority;
  final String status;
  final String? reportedByName;
  final String? startedByName;
  final String? completedByName;
  final DateTime reportedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isMarked => status == MaintenanceStatus.marked;

  bool get isInProgress => status == MaintenanceStatus.inProgress;

  bool get isCompleted => status == MaintenanceStatus.completed;

  MaintenanceRecord copyWith({
    int? id,
    int? machineId,
    String? issueTitle,
    Object? issueDescription = _sentinel,
    String? priority,
    String? status,
    Object? reportedByName = _sentinel,
    Object? startedByName = _sentinel,
    Object? completedByName = _sentinel,
    DateTime? reportedAt,
    Object? startedAt = _sentinel,
    Object? completedAt = _sentinel,
    Object? resolutionNotes = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      issueTitle: issueTitle ?? this.issueTitle,
      issueDescription: identical(issueDescription, _sentinel)
          ? this.issueDescription
          : issueDescription as String?,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      reportedByName: identical(reportedByName, _sentinel)
          ? this.reportedByName
          : reportedByName as String?,
      startedByName: identical(startedByName, _sentinel)
          ? this.startedByName
          : startedByName as String?,
      completedByName: identical(completedByName, _sentinel)
          ? this.completedByName
          : completedByName as String?,
      reportedAt: reportedAt ?? this.reportedAt,
      startedAt: identical(startedAt, _sentinel)
          ? this.startedAt
          : startedAt as DateTime?,
      completedAt: identical(completedAt, _sentinel)
          ? this.completedAt
          : completedAt as DateTime?,
      resolutionNotes: identical(resolutionNotes, _sentinel)
          ? this.resolutionNotes
          : resolutionNotes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const _sentinel = Object();

class StaffRole {
  static const admin = 'ADMIN';
  static const manager = 'MANAGER';
  static const cashier = 'CASHIER';
  static const technician = 'TECHNICIAN';
  static const support = 'SUPPORT';
}

class StaffLeaveStatus {
  static const pending = 'PENDING';
  static const approved = 'APPROVED';
  static const rejected = 'REJECTED';
}

class StaffPayoutStatus {
  static const scheduled = 'SCHEDULED';
  static const paid = 'PAID';
}

class StaffMember {
  const StaffMember({
    required this.id,
    required this.fullName,
    required this.role,
    required this.phone,
    required this.hourlyRate,
    required this.isActive,
  });

  final int id;
  final String fullName;
  final String role;
  final String phone;
  final double hourlyRate;
  final bool isActive;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'role': role,
      'phone': phone,
      'hourlyRate': hourlyRate,
      'isActive': isActive,
    };
  }

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as int,
      fullName: json['fullName'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String,
      hourlyRate: (json['hourlyRate'] as num).toDouble(),
      isActive: json['isActive'] as bool,
    );
  }
}

class StaffShift {
  const StaffShift({
    required this.id,
    required this.staffId,
    required this.shiftDate,
    required this.startTimeLabel,
    required this.endTimeLabel,
    required this.branch,
    required this.assignment,
    required this.hours,
  });

  final int id;
  final int staffId;
  final DateTime shiftDate;
  final String startTimeLabel;
  final String endTimeLabel;
  final String branch;
  final String assignment;
  final double hours;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'shiftDate': shiftDate.toIso8601String(),
      'startTimeLabel': startTimeLabel,
      'endTimeLabel': endTimeLabel,
      'branch': branch,
      'assignment': assignment,
      'hours': hours,
    };
  }

  factory StaffShift.fromJson(Map<String, dynamic> json) {
    return StaffShift(
      id: json['id'] as int,
      staffId: json['staffId'] as int,
      shiftDate: DateTime.parse(json['shiftDate'] as String),
      startTimeLabel: json['startTimeLabel'] as String,
      endTimeLabel: json['endTimeLabel'] as String,
      branch: json['branch'] as String,
      assignment: json['assignment'] as String,
      hours: (json['hours'] as num).toDouble(),
    );
  }
}

class StaffLeaveRequest {
  const StaffLeaveRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.reason,
    required this.requestedAt,
    this.reviewedByName,
  });

  final int id;
  final int staffId;
  final String staffName;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String reason;
  final DateTime requestedAt;
  final String? reviewedByName;

  int get dayCount => endDate.difference(startDate).inDays + 1;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status,
      'reason': reason,
      'requestedAt': requestedAt.toIso8601String(),
      'reviewedByName': reviewedByName,
    };
  }

  factory StaffLeaveRequest.fromJson(Map<String, dynamic> json) {
    return StaffLeaveRequest(
      id: json['id'] as int,
      staffId: json['staffId'] as int,
      staffName: json['staffName'] as String,
      leaveType: json['leaveType'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: json['status'] as String,
      reason: json['reason'] as String,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      reviewedByName: json['reviewedByName'] as String?,
    );
  }

  StaffLeaveRequest copyWith({
    String? status,
    Object? reviewedByName = _sentinel,
  }) {
    return StaffLeaveRequest(
      id: id,
      staffId: staffId,
      staffName: staffName,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      status: status ?? this.status,
      reason: reason,
      requestedAt: requestedAt,
      reviewedByName: identical(reviewedByName, _sentinel)
          ? this.reviewedByName
          : reviewedByName as String?,
    );
  }
}

class StaffPayout {
  const StaffPayout({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.periodLabel,
    required this.hoursWorked,
    required this.grossAmount,
    required this.bonusAmount,
    required this.deductionsAmount,
    required this.netAmount,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  final int id;
  final int staffId;
  final String staffName;
  final String periodLabel;
  final double hoursWorked;
  final double grossAmount;
  final double bonusAmount;
  final double deductionsAmount;
  final double netAmount;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'periodLabel': periodLabel,
      'hoursWorked': hoursWorked,
      'grossAmount': grossAmount,
      'bonusAmount': bonusAmount,
      'deductionsAmount': deductionsAmount,
      'netAmount': netAmount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
    };
  }

  factory StaffPayout.fromJson(Map<String, dynamic> json) {
    return StaffPayout(
      id: json['id'] as int,
      staffId: json['staffId'] as int,
      staffName: json['staffName'] as String,
      periodLabel: json['periodLabel'] as String,
      hoursWorked: (json['hoursWorked'] as num).toDouble(),
      grossAmount: (json['grossAmount'] as num).toDouble(),
      bonusAmount: (json['bonusAmount'] as num).toDouble(),
      deductionsAmount: (json['deductionsAmount'] as num).toDouble(),
      netAmount: (json['netAmount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
    );
  }

  StaffPayout copyWith({
    String? status,
    Object? paidAt = _sentinel,
  }) {
    return StaffPayout(
      id: id,
      staffId: staffId,
      staffName: staffName,
      periodLabel: periodLabel,
      hoursWorked: hoursWorked,
      grossAmount: grossAmount,
      bonusAmount: bonusAmount,
      deductionsAmount: deductionsAmount,
      netAmount: netAmount,
      status: status ?? this.status,
      createdAt: createdAt,
      paidAt: identical(paidAt, _sentinel) ? this.paidAt : paidAt as DateTime?,
    );
  }
}

const _sentinel = Object();

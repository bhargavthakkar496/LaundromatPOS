class ReservationStatus {
  static const booked = 'BOOKED';
  static const fulfilled = 'FULFILLED';
  static const cancelled = 'CANCELLED';
}

class MachineReservation {
  const MachineReservation({
    required this.id,
    required this.machineId,
    required this.customerId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    this.preferredWasherSizeKg,
    this.detergentAddOn,
    this.dryerDurationMinutes,
  });

  final int id;
  final int machineId;
  final int customerId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final DateTime createdAt;
  final int? preferredWasherSizeKg;
  final String? detergentAddOn;
  final int? dryerDurationMinutes;

  bool get isBooked => status == ReservationStatus.booked;

  bool overlaps(DateTime otherStart, DateTime otherEnd) {
    return startTime.isBefore(otherEnd) && endTime.isAfter(otherStart);
  }
}

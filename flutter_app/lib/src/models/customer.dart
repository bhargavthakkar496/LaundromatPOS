class Customer {
  const Customer({
    required this.id,
    required this.fullName,
    required this.phone,
    this.preferredWasherSizeKg,
    this.preferredDetergentAddOn,
    this.preferredDryerDurationMinutes,
  });

  final int id;
  final String fullName;
  final String phone;
  final int? preferredWasherSizeKg;
  final String? preferredDetergentAddOn;
  final int? preferredDryerDurationMinutes;

  Customer copyWith({
    int? id,
    String? fullName,
    String? phone,
    Object? preferredWasherSizeKg = _sentinel,
    Object? preferredDetergentAddOn = _sentinel,
    Object? preferredDryerDurationMinutes = _sentinel,
  }) {
    return Customer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      preferredWasherSizeKg: identical(preferredWasherSizeKg, _sentinel)
          ? this.preferredWasherSizeKg
          : preferredWasherSizeKg as int?,
      preferredDetergentAddOn: identical(
            preferredDetergentAddOn,
            _sentinel,
          )
          ? this.preferredDetergentAddOn
          : preferredDetergentAddOn as String?,
      preferredDryerDurationMinutes: identical(
            preferredDryerDurationMinutes,
            _sentinel,
          )
          ? this.preferredDryerDurationMinutes
          : preferredDryerDurationMinutes as int?,
    );
  }
}

const _sentinel = Object();

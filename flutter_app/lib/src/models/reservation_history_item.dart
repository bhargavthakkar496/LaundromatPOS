import 'customer.dart';
import 'machine.dart';
import 'machine_reservation.dart';

class ReservationHistoryItem {
  const ReservationHistoryItem({
    required this.reservation,
    required this.machine,
    required this.customer,
  });

  final MachineReservation reservation;
  final Machine machine;
  final Customer customer;
}

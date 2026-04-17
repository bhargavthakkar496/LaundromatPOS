import 'customer.dart';
import 'machine.dart';
import 'order.dart';

class OrderHistoryItem {
  const OrderHistoryItem({
    required this.order,
    required this.machine,
    required this.customer,
    this.dryerMachine,
    this.ironingMachine,
  });

  final Order order;
  final Machine machine;
  final Customer customer;
  final Machine? dryerMachine;
  final Machine? ironingMachine;
}

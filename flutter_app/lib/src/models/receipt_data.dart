import 'customer.dart';
import 'machine.dart';
import 'order.dart';

class ReceiptData {
  const ReceiptData({
    required this.order,
    required this.customer,
    required this.machine,
  });

  final Order order;
  final Customer customer;
  final Machine machine;
}

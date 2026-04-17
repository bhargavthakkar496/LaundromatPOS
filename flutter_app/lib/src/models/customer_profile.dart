import 'customer.dart';
import 'machine.dart';
import 'order_history_item.dart';
import 'reservation_history_item.dart';

class FavoriteMachineStat {
  const FavoriteMachineStat({
    required this.machine,
    required this.usageCount,
  });

  final Machine machine;
  final int usageCount;
}

class CustomerProfile {
  const CustomerProfile({
    required this.customer,
    required this.orders,
    required this.totalSpent,
    required this.totalVisits,
    required this.favoriteMachines,
    required this.upcomingReservations,
  });

  final Customer customer;
  final List<OrderHistoryItem> orders;
  final double totalSpent;
  final int totalVisits;
  final List<FavoriteMachineStat> favoriteMachines;
  final List<ReservationHistoryItem> upcomingReservations;
}

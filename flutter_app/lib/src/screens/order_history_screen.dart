import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/order_history_item.dart';
import '../models/order.dart';
import '../services/currency_formatter.dart';
import '../widgets/machine_icon.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  final PosRepository repository;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderHistory),
        actions: [
          TextButton(
            onPressed: onLogout,
            child: Text(l10n.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<OrderHistoryItem>>(
        future: repository.getOrderHistory(),
        builder: (context, snapshot) {
          final orders = snapshot.data ?? const <OrderHistoryItem>[];

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orders.isEmpty) {
            return const Center(child: Text('No completed orders yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = orders[index];
              final formattedDate =
                  DateFormat('dd MMM, hh:mm a').format(item.order.timestamp);
              return Card(
                child: ListTile(
                  leading: MachineIcon(machine: item.machine),
                  title:
                      Text('${item.machine.name} • ${item.customer.fullName}'),
                  subtitle: Text(
                    '${item.order.paymentMethod} • ${CurrencyFormatter.formatAmountForContext(context, item.order.amount)} • $formattedDate',
                  ),
                  trailing: Text(
                    item.order.paymentStatus == PaymentStatus.refunded
                        ? 'Refunded'
                        : item.machine.currentOrderId == item.order.id &&
                                item.machine.isReadyForPickup
                            ? 'Ready'
                            : item.machine.currentOrderId == item.order.id &&
                                    item.machine.isInUse
                                ? 'Running'
                                : 'Completed',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

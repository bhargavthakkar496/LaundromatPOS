import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../models/order_history_item.dart';
import '../models/order.dart';
import '../services/open_external_url.dart';
import '../services/whatsapp_notification_service.dart';
import '../widgets/machine_icon.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  final PosRepository repository;
  final Future<void> Function() onLogout;

  Future<void> _sendRefundNotification(
    BuildContext context,
    OrderHistoryItem item,
  ) async {
    final updated = await repository.markRefundProcessed(item.order.id);
    if (updated == null) {
      return;
    }
    final updatedItem = await repository.getOrderHistoryItemByOrderId(updated.id);
    if (updatedItem == null) {
      return;
    }
    final phone = WhatsAppNotificationService.normalizePhone(
      updatedItem.customer.phone,
    );
    final message = Uri.encodeComponent(
      WhatsAppNotificationService.buildRefundProcessedMessage(updatedItem),
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    final launched = await openExternalUrl(url);
    if (!context.mounted) {
      return;
    }
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp for refund notification.'),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OrderHistoryScreen(
            repository: repository,
            onLogout: onLogout,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        actions: [
          TextButton(
            onPressed: onLogout,
            child: const Text('Log Out'),
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
                  title: Text('${item.machine.name} • ${item.customer.fullName}'),
                  subtitle: Text(
                    '${item.order.paymentMethod} • INR ${item.order.amount.toStringAsFixed(0)} • $formattedDate',
                  ),
                  trailing: item.order.paymentStatus != PaymentStatus.refunded
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'refund') {
                              _sendRefundNotification(context, item);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'refund',
                              child: Text('Refund & Notify'),
                            ),
                          ],
                          child: Text(
                            item.machine.currentOrderId == item.order.id &&
                                    item.machine.isReadyForPickup
                                ? 'Ready'
                                : item.machine.currentOrderId == item.order.id &&
                                        item.machine.isInUse
                                    ? 'Running'
                                    : 'Completed',
                          ),
                        )
                      : const Text('Refunded'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

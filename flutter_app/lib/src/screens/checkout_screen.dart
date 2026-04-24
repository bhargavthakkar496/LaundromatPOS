import 'package:flutter/material.dart';

import '../config/demo_settings.dart';
import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/machine.dart';
import '../models/order.dart';
import '../models/payment_session.dart';
import '../models/pos_user.dart';
import '../models/receipt_data.dart';
import '../services/open_external_url.dart';
import '../services/currency_formatter.dart';
import '../services/whatsapp_notification_service.dart';
import '../widgets/customer_details_form.dart';
import '../widgets/machine_icon.dart';
import '../widgets/payment_status_sheet.dart';
import '../widgets/receipt_actions.dart';
import 'order_history_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.machine,
    required this.onLogout,
  });

  final PosRepository repository;
  final PosUser user;
  final Machine machine;
  final Future<void> Function() onLogout;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _paymentMethods = const ['UPI QR', 'Card', 'Cash'];
  String _paymentMethod = 'UPI QR';
  bool _submitting = false;
  Order? _order;
  ReceiptData? _receipt;
  Machine? _cycleMachine;

  Future<void> _sendPaymentSuccessNotification() async {
    final receipt = _receipt;
    if (receipt == null) {
      return;
    }
    final phone = WhatsAppNotificationService.normalizePhone(
      receipt.customer.phone,
    );
    final message = Uri.encodeComponent(
      WhatsAppNotificationService.buildPaymentSuccessMessage(
        receipt,
        locale: Localizations.localeOf(context),
      ),
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    final launched = await openExternalUrl(url);
    if (!mounted) {
      return;
    }
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp for payment notification.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _completeCheckout() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final paymentSession = await showModalBottomSheet<PaymentSession>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      showDragHandle: true,
      builder: (context) => PaymentStatusSheet(
        repository: widget.repository,
        amount: widget.machine.price,
        paymentMethod: _paymentMethod,
        referencePrefix: 'POS',
      ),
    );

    if (!mounted) {
      return;
    }

    if (paymentSession == null || !paymentSession.isPaid) {
      setState(() {
        _submitting = false;
      });
      return;
    }

    final customer = await widget.repository.saveWalkInCustomer(
      fullName: _customerNameController.text.trim(),
      phone: _customerPhoneController.text.trim(),
    );

    final order = await widget.repository.createPaidOrder(
      machine: widget.machine,
      customer: customer,
      user: widget.user,
      paymentMethod: _paymentMethod,
      paymentReference: paymentSession.reference,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
      _order = order;
      _receipt = ReceiptData(
        order: order,
        customer: customer,
        machine: widget.machine,
      );
      _cycleMachine = widget.machine.copyWith(
        status: MachineStatus.inUse,
        currentOrderId: order.id,
        cycleStartedAt: order.timestamp,
        cycleEndsAt: order.timestamp.add(widget.machine.cycleDuration),
      );
    });

    if (DemoSettings.autoOpenWhatsAppNotifications) {
      await _sendPaymentSuccessNotification();
    }
  }

  Future<void> _viewHistory() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OrderHistoryScreen(
          repository: widget.repository,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.checkout)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MachineIcon(machine: widget.machine, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.machine.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '${widget.machine.type} • ${widget.machine.capacityKg}kg'),
                    const SizedBox(height: 8),
                    Text(
                      'Amount: ${CurrencyFormatter.formatAmountForContext(context, widget.machine.price)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomerDetailsForm(
              nameController: _customerNameController,
              phoneController: _customerPhoneController,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: _paymentMethods
                  .map(
                    (method) => DropdownMenuItem<String>(
                      value: method,
                      child: Text(method),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _paymentMethod = value;
                      });
                    },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _completeCheckout,
              child: Text(
                  _submitting ? 'Processing payment...' : 'Complete Payment'),
            ),
            if (_order != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment successful',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Reference: ${_order!.paymentReference}'),
                      Text(
                          'Status: ${_order!.status} / ${_order!.paymentStatus}'),
                      if (_cycleMachine != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Cycle started • ${_cycleMachine!.productionCycleMinutes} min estimated • Machine ready for pickup after completion',
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _sendPaymentSuccessNotification,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Send Payment Success Notification'),
                      ),
                      if (_receipt != null) ...[
                        const SizedBox(height: 16),
                        ReceiptActions(receipt: _receipt!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _viewHistory,
                child: const Text('Open Order History'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

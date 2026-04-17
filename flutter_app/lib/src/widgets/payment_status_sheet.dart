import 'dart:async';

import 'package:flutter/material.dart';

import '../data/pos_repository.dart';
import '../models/payment_session.dart';

class PaymentStatusSheet extends StatefulWidget {
  const PaymentStatusSheet({
    super.key,
    required this.repository,
    required this.amount,
    required this.paymentMethod,
    required this.referencePrefix,
  });

  final PosRepository repository;
  final double amount;
  final String paymentMethod;
  final String referencePrefix;

  @override
  State<PaymentStatusSheet> createState() => _PaymentStatusSheetState();
}

class _PaymentStatusSheetState extends State<PaymentStatusSheet> {
  PaymentSession? _session;
  Timer? _timer;
  bool _loading = true;
  bool _polling = false;
  String? _error;
  int _attempt = 1;

  @override
  void initState() {
    super.initState();
    _initializeSession(simulateFailure: widget.paymentMethod == 'UPI QR');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeSession({bool simulateFailure = false}) async {
    try {
      final session = await widget.repository.createPaymentSession(
        amount: widget.amount,
        paymentMethod: widget.paymentMethod,
        referencePrefix: widget.referencePrefix,
        attempt: _attempt,
        shouldFail: simulateFailure,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _loading = false;
      });
      _startPolling();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollStatus();
    });
  }

  Future<void> _retryPayment() async {
    _timer?.cancel();
    setState(() {
      _attempt += 1;
      _loading = true;
      _polling = false;
      _error = null;
      _session = null;
    });
    await _initializeSession(simulateFailure: false);
  }

  Future<void> _pollStatus() async {
    final session = _session;
    if (session == null || _polling || session.isPaid || session.isFailed) {
      return;
    }

    setState(() {
      _polling = true;
    });

    try {
      final updated = await widget.repository.pollPaymentSession(session.id);
      if (!mounted) {
        return;
      }
      if (updated.isPaid) {
        _timer?.cancel();
      } else if (updated.isFailed) {
        _timer?.cancel();
      }
      setState(() {
        _session = updated;
        _polling = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _polling = false;
      });
    }
  }

  String get _statusLabel {
    switch (_session?.status) {
      case PaymentSessionStatus.awaitingScan:
        return 'Awaiting scan';
      case PaymentSessionStatus.processing:
        return 'Processing payment';
      case PaymentSessionStatus.paid:
        return 'Payment received';
      case PaymentSessionStatus.failed:
        return 'Payment failed';
      default:
        return 'Preparing payment';
    }
  }

  String get _statusMessage {
    switch (_session?.status) {
      case PaymentSessionStatus.awaitingScan:
        return widget.paymentMethod == 'UPI QR'
            ? 'Scan this QR with any UPI app to continue.'
            : 'Customer is reviewing the payment on the terminal.';
      case PaymentSessionStatus.processing:
        return 'Bank confirmation is in progress. We are checking payment status automatically.';
      case PaymentSessionStatus.paid:
        return 'Payment is complete. You can finish checkout now.';
      case PaymentSessionStatus.failed:
        return _session?.failureReason ??
            'Payment could not be confirmed. Retry to generate a fresh request.';
      default:
        return 'Creating a payment request...';
    }
  }

  IconData get _paymentIcon {
    if (widget.paymentMethod == 'UPI QR') {
      return Icons.qr_code_2_rounded;
    }
    if (widget.paymentMethod == 'Card') {
      return Icons.credit_card;
    }
    return Icons.payments_outlined;
  }

  Color get _statusColor {
    switch (_session?.status) {
      case PaymentSessionStatus.awaitingScan:
        return const Color(0xFF0E7490);
      case PaymentSessionStatus.processing:
        return const Color(0xFFC86B3C);
      case PaymentSessionStatus.paid:
        return const Color(0xFF2A9D8F);
      case PaymentSessionStatus.failed:
        return const Color(0xFFB42318);
      default:
        return const Color(0xFF6B7280);
    }
  }

  int get _statusStepIndex {
    switch (_session?.status) {
      case PaymentSessionStatus.awaitingScan:
        return 0;
      case PaymentSessionStatus.processing:
        return 1;
      case PaymentSessionStatus.paid:
        return 2;
      case PaymentSessionStatus.failed:
        return 1;
      default:
        return 0;
    }
  }

  Widget _buildStep(
    BuildContext context, {
    required int index,
    required String title,
    required String caption,
  }) {
    final isActive = _statusStepIndex >= index;
    final isFailure =
        _session?.status == PaymentSessionStatus.failed && index == 2;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFailure
              ? const Color(0xFFFEE4E2)
              : isActive
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFailure
                ? const Color(0xFFFDA29B)
                : isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. $title',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Status',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Live status updates are being polled automatically for this payment.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Unable to load payment session: $_error'),
                ),
              )
            else if (session != null) ...[
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to pay',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Open your payment app.\n2. Scan the QR and approve the amount.\n3. Keep this screen open while we confirm the payment.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStep(
                    context,
                    index: 0,
                    title: 'Scan',
                    caption: 'Scan or open the payment request',
                  ),
                  const SizedBox(width: 8),
                  _buildStep(
                    context,
                    index: 1,
                    title: 'Confirm',
                    caption: 'Approve the payment in your app',
                  ),
                  const SizedBox(width: 8),
                  _buildStep(
                    context,
                    index: 2,
                    title: session.isFailed ? 'Retry' : 'Paid',
                    caption: session.isFailed
                        ? 'Create a fresh payment request'
                        : 'Wait for confirmation',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  width: 184,
                  height: 184,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_paymentIcon, size: 92, color: _statusColor),
                      const SizedBox(height: 8),
                      Text(
                        widget.paymentMethod,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Attempt ${session.attempt}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: _statusColor),
                          const SizedBox(width: 8),
                          Text(
                            _statusLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(_statusMessage),
                      const SizedBox(height: 14),
                      Text('Amount: INR ${session.amount.toStringAsFixed(0)}'),
                      Text('Reference: ${session.reference}'),
                      Text('QR payload: ${session.qrPayload}'),
                      Text('Last checked: ${session.checkedAt.hour.toString().padLeft(2, '0')}:${session.checkedAt.minute.toString().padLeft(2, '0')}:${session.checkedAt.second.toString().padLeft(2, '0')}'),
                    ],
                  ),
                ),
              ),
              if (session.isFailed) ...[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFFEE4E2),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      session.failureReason ??
                          'Payment failed. Retry to continue with a fresh request.',
                    ),
                  ),
                ),
              ],
              if (session.isPaid) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Confirmation received. The order can now be completed.',
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: session != null && session.isFailed
                      ? OutlinedButton.icon(
                          onPressed: _loading ? null : _retryPayment,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Retry Payment'),
                        )
                      : OutlinedButton.icon(
                          onPressed: _loading || _polling ? null : _pollStatus,
                          icon: const Icon(Icons.refresh),
                          label: Text(_polling ? 'Checking...' : 'Refresh Status'),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: session != null && session.isPaid
                        ? () => Navigator.of(context).pop(session)
                        : null,
                    child: const Text('Finish Payment'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../models/order_history_item.dart';
import '../models/pos_user.dart';
import '../models/refund_request.dart';
import '../services/open_external_url.dart';
import '../services/whatsapp_notification_service.dart';

class RefundRequestsScreen extends StatefulWidget {
  const RefundRequestsScreen({
    super.key,
    required this.repository,
    required this.user,
  });

  final PosRepository repository;
  final PosUser user;

  @override
  State<RefundRequestsScreen> createState() => _RefundRequestsScreenState();
}

class _RefundRequestsScreenState extends State<RefundRequestsScreen> {
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  List<RefundRequest> _requests = const [];
  bool _loading = true;
  int? _processingRequestId;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }
    final requests = await widget.repository.getRefundRequests();
    if (!mounted) {
      return;
    }
    setState(() {
      _requests = requests;
      _loading = false;
    });
  }

  Future<void> _processRefundRequest(RefundRequest request) async {
    setState(() {
      _processingRequestId = request.id;
    });

    final updated = await widget.repository.markRefundRequestProcessed(
      requestId: request.id,
      processedByName: widget.user.displayName,
    );

    if (!mounted) {
      return;
    }

    if (updated == null) {
      setState(() {
        _processingRequestId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund processing failed.')),
      );
      return;
    }

    final historyItem = await widget.repository.getOrderHistoryItemByOrderId(
      request.orderId,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _processingRequestId = null;
    });

    if (historyItem != null) {
      await _notifyRefundProcessed(historyItem);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refund processed and moved out of queue.')),
    );
    _loadRequests(showLoading: false);
  }

  Future<void> _notifyRefundProcessed(OrderHistoryItem item) async {
    final phone =
        WhatsAppNotificationService.normalizePhone(item.customer.phone);
    final message = Uri.encodeComponent(
      WhatsAppNotificationService.buildRefundProcessedMessage(item),
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    final launched = await openExternalUrl(url);
    if (!mounted || launched) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Refund was processed, but WhatsApp could not be opened.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((item) => item.isPending).toList();
    final processed = _requests.where((item) => item.isProcessed).toList();
    final pendingAmount = pending.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Queue'),
        actions: [
          IconButton(
            onPressed:
                _loading ? null : () => _loadRequests(showLoading: false),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C2D12), Color(0xFFB42318)],
                    ),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Refund Review Queue',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Only requests initiated from Operator Payments appear here. Process them after reviewing the payment reference, reason, and customer details.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _QueueMetric(
                              label: 'Pending', value: '${pending.length}'),
                          _QueueMetric(
                            label: 'Pending Amount',
                            value: 'INR ${pendingAmount.toStringAsFixed(0)}',
                          ),
                          _QueueMetric(
                            label: 'Processed',
                            value: '${processed.length}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pending Requests',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No pending refund requests right now.'),
                    ),
                  )
                else
                  ...pending.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RefundRequestCard(
                        request: request,
                        subtitle:
                            'Requested ${_dateTimeFormat.format(request.requestedAt)}',
                        action: FilledButton.icon(
                          onPressed: _processingRequestId == request.id
                              ? null
                              : () => _processRefundRequest(request),
                          icon: const Icon(Icons.assignment_turned_in_outlined),
                          label: Text(
                            _processingRequestId == request.id
                                ? 'Processing Refund...'
                                : 'Process Refund & Notify',
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Processed Requests',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (processed.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child:
                          Text('Processed refund requests will appear here.'),
                    ),
                  )
                else
                  ...processed.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RefundRequestCard(
                        request: request,
                        subtitle: request.processedAt == null
                            ? 'Processed'
                            : 'Processed ${_dateTimeFormat.format(request.processedAt!)}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _QueueMetric extends StatelessWidget {
  const _QueueMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundRequestCard extends StatelessWidget {
  const _RefundRequestCard({
    required this.request,
    required this.subtitle,
    this.action,
  });

  final RefundRequest request;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tone =
        request.isPending ? const Color(0xFFD97706) : const Color(0xFF2A9D8F);
    final badge = request.isPending ? 'Pending Review' : 'Processed';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${request.customerName} • ${request.machineName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(color: tone, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(subtitle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                Text('Phone: ${request.customerPhone}'),
                Text('Amount: INR ${request.amount.toStringAsFixed(0)}'),
                Text('Method: ${request.paymentMethod}'),
                Text('Ref: ${request.paymentReference}'),
                if ((request.requestedByName ?? '').isNotEmpty)
                  Text('Requested by: ${request.requestedByName}'),
                if ((request.processedByName ?? '').isNotEmpty)
                  Text('Processed by: ${request.processedByName}'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Reason: ${request.reason}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

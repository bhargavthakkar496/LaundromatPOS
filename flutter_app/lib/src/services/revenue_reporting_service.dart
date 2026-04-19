import '../models/order.dart';
import '../models/order_history_item.dart';
import '../models/refund_request.dart';
import '../models/revenue.dart';

class RevenueReportingService {
  static List<OrderHistoryItem> filterTransactions({
    required List<OrderHistoryItem> history,
    DateTime? start,
    DateTime? end,
    String? paymentMethod,
    String? paymentStatus,
    String? service,
    String? machineType,
    String? searchQuery,
  }) {
    final normalizedSearch = searchQuery?.trim().toLowerCase() ?? '';
    return history.where((item) {
      final order = item.order;
      if (start != null && order.timestamp.isBefore(start)) {
        return false;
      }
      if (end != null && !order.timestamp.isBefore(end)) {
        return false;
      }
      if (paymentMethod != null &&
          paymentMethod.isNotEmpty &&
          paymentMethod != 'ALL' &&
          order.paymentMethod != paymentMethod) {
        return false;
      }
      if (paymentStatus != null &&
          paymentStatus.isNotEmpty &&
          paymentStatus != 'ALL' &&
          order.paymentStatus != paymentStatus) {
        return false;
      }
      if (service != null &&
          service.isNotEmpty &&
          service != 'ALL' &&
          !order.selectedServices.contains(service)) {
        return false;
      }
      if (machineType != null &&
          machineType.isNotEmpty &&
          machineType != 'ALL' &&
          !_orderMatchesMachineType(item, machineType)) {
        return false;
      }
      if (normalizedSearch.isEmpty) {
        return true;
      }
      return item.customer.fullName.toLowerCase().contains(normalizedSearch) ||
          item.customer.phone.toLowerCase().contains(normalizedSearch) ||
          item.machine.name.toLowerCase().contains(normalizedSearch) ||
          order.paymentReference.toLowerCase().contains(normalizedSearch) ||
          order.paymentMethod.toLowerCase().contains(normalizedSearch);
    }).toList()
      ..sort((left, right) =>
          right.order.timestamp.compareTo(left.order.timestamp));
  }

  static RevenueSummary buildSummary({
    required List<OrderHistoryItem> transactions,
    required List<RefundRequest> refundRequests,
  }) {
    final grossRevenue = transactions.fold<double>(
      0,
      (sum, item) => sum + item.order.amount,
    );
    final refundedRevenue = transactions
        .where((item) => item.order.paymentStatus == PaymentStatus.refunded)
        .fold<double>(0, (sum, item) => sum + item.order.amount);
    final netRevenue = grossRevenue - refundedRevenue;
    final averageTicket =
        transactions.isEmpty ? 0.0 : netRevenue / transactions.length;

    final paymentTotals = <String, double>{};
    final paymentCounts = <String, int>{};
    final serviceTotals = <String, double>{};
    final serviceCounts = <String, int>{};
    final machineTypeTotals = <String, double>{};
    final machineTypeCounts = <String, int>{};
    final machineTotals = <String, double>{};
    final machineCounts = <String, int>{};

    for (final item in transactions) {
      final signedAmount = item.order.paymentStatus == PaymentStatus.refunded
          ? -item.order.amount
          : item.order.amount;

      paymentTotals.update(
        item.order.paymentMethod,
        (value) => value + signedAmount,
        ifAbsent: () => signedAmount,
      );
      paymentCounts.update(
        item.order.paymentMethod,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      for (final service in item.order.selectedServices) {
        serviceTotals.update(
          service,
          (value) => value + signedAmount,
          ifAbsent: () => signedAmount,
        );
        serviceCounts.update(service, (value) => value + 1, ifAbsent: () => 1);
      }

      for (final type in _machineTypesForOrder(item)) {
        machineTypeTotals.update(
          type,
          (value) => value + signedAmount,
          ifAbsent: () => signedAmount,
        );
        machineTypeCounts.update(type, (value) => value + 1, ifAbsent: () => 1);
      }

      machineTotals.update(
        item.machine.name,
        (value) => value + signedAmount,
        ifAbsent: () => signedAmount,
      );
      machineCounts.update(item.machine.name, (value) => value + 1,
          ifAbsent: () => 1);
    }

    final pendingRefundCount =
        refundRequests.where((item) => item.isPending).length;
    final pendingRefundAmount = refundRequests
        .where((item) => item.isPending)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final cashNet = paymentTotals['Cash'] ?? 0.0;
    final cardNet = paymentTotals['Card'] ?? 0.0;
    final upiNet = paymentTotals['UPI QR'] ?? 0.0;
    final otherNet = paymentTotals.entries
        .where((entry) =>
            entry.key != 'Cash' && entry.key != 'Card' && entry.key != 'UPI QR')
        .fold<double>(0, (sum, entry) => sum + entry.value);

    return RevenueSummary(
      transactionCount: transactions.length,
      grossRevenue: grossRevenue,
      refundedRevenue: refundedRevenue,
      netRevenue: netRevenue,
      averageTicket: averageTicket,
      pendingRefundCount: pendingRefundCount,
      pendingRefundAmount: pendingRefundAmount,
      cashNet: cashNet,
      cardNet: cardNet,
      upiNet: upiNet,
      otherNet: otherNet,
      paymentBreakdown: _breakdownFromMap(paymentTotals, paymentCounts),
      serviceBreakdown: _breakdownFromMap(serviceTotals, serviceCounts),
      machineTypeBreakdown:
          _breakdownFromMap(machineTypeTotals, machineTypeCounts),
      topMachineBreakdown:
          _breakdownFromMap(machineTotals, machineCounts, limit: 5),
    );
  }

  static DayEndCheckout buildDayEndCheckout({
    required int id,
    required DateTime businessDate,
    required double openingCash,
    required double closingCashCounted,
    String? notes,
    required String closedByName,
    required List<OrderHistoryItem> history,
    required List<RefundRequest> refundRequests,
  }) {
    final start =
        DateTime(businessDate.year, businessDate.month, businessDate.day);
    final end = start.add(const Duration(days: 1));
    final transactions = filterTransactions(
      history: history,
      start: start,
      end: end,
    );
    final dayRefunds = refundRequests.where((request) {
      if (!request.isPending) {
        return false;
      }
      return transactions.any((item) => item.order.id == request.orderId);
    }).toList();
    final summary = buildSummary(
      transactions: transactions,
      refundRequests: dayRefunds,
    );
    final expectedDrawerCash = openingCash + summary.cashNet;

    return DayEndCheckout(
      id: id,
      businessDate: start,
      closedAt: DateTime.now(),
      closedByName: closedByName,
      transactionCount: summary.transactionCount,
      grossRevenue: summary.grossRevenue,
      refundedRevenue: summary.refundedRevenue,
      netRevenue: summary.netRevenue,
      cashNet: summary.cashNet,
      digitalNet: summary.cardNet + summary.upiNet + summary.otherNet,
      openingCash: openingCash,
      expectedDrawerCash: expectedDrawerCash,
      countedDrawerCash: closingCashCounted,
      cashVariance: (closingCashCounted - expectedDrawerCash).toDouble(),
      pendingRefundCount: summary.pendingRefundCount,
      pendingRefundAmount: summary.pendingRefundAmount,
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
    );
  }

  static bool _orderMatchesMachineType(
      OrderHistoryItem item, String machineType) {
    return _machineTypesForOrder(item).contains(machineType);
  }

  static Set<String> _machineTypesForOrder(OrderHistoryItem item) {
    return <String>{
      item.machine.type,
      if (item.dryerMachine != null) item.dryerMachine!.type,
      if (item.ironingMachine != null) item.ironingMachine!.type,
    };
  }

  static List<RevenueBreakdownItem> _breakdownFromMap(
    Map<String, double> totals,
    Map<String, int> counts, {
    int? limit,
  }) {
    final items = totals.entries
        .map(
          (entry) => RevenueBreakdownItem(
            label: entry.key,
            orderCount: counts[entry.key] ?? 0,
            amount: entry.value,
          ),
        )
        .toList()
      ..sort((left, right) => right.amount.compareTo(left.amount));
    if (limit == null || items.length <= limit) {
      return items;
    }
    return items.take(limit).toList();
  }
}

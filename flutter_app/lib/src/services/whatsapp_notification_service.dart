import 'package:flutter/material.dart';

import '../models/order_history_item.dart';
import '../models/receipt_data.dart';
import 'currency_formatter.dart';

class WhatsAppNotificationService {
  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String buildPaymentSuccessMessage(
    ReceiptData receipt, {
    required Locale locale,
  }) {
    return [
      'Payment successful for your laundromat order.',
      'Order #${receipt.order.id}',
      'Machine: ${receipt.machine.name}',
      'Amount paid: ${CurrencyFormatter.formatAmount(receipt.order.amount, locale)}',
      'Payment method: ${receipt.order.paymentMethod}',
      'Reference: ${receipt.order.paymentReference}',
      'Your cycle has been started.',
    ].join('\n');
  }

  static String buildCycleCompletedMessage(OrderHistoryItem item) {
    return [
      'Your laundry cycle is complete and the machine is ready for pickup.',
      'Order #${item.order.id}',
      'Machine: ${item.machine.name}',
      'Reference: ${item.order.paymentReference}',
      'Please collect your load at the counter.',
    ].join('\n');
  }

  static String buildMachineDelayMessage(
    OrderHistoryItem item, {
    int extraMinutes = 10,
  }) {
    return [
      'There is a delay with your laundry cycle.',
      'Order #${item.order.id}',
      'Machine: ${item.machine.name}',
      'We expect an additional $extraMinutes minutes before completion.',
      'We will update you again once the machine is ready.',
    ].join('\n');
  }

  static String buildRefundProcessedMessage(
    OrderHistoryItem item, {
    required Locale locale,
  }) {
    return [
      'Your refund has been processed.',
      'Order #${item.order.id}',
      'Amount refunded: ${CurrencyFormatter.formatAmount(item.order.amount, locale)}',
      'Original reference: ${item.order.paymentReference}',
      'Please contact support if you do not see the refund shortly.',
    ].join('\n');
  }
}

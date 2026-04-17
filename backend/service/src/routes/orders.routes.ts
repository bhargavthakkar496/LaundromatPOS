import type { Router } from 'express';

import {
  createManualOrderHandler,
  createPaidOrderHandler,
  getOrderHistoryItemHandler,
  listOrderHistoryHandler,
  refundOrderHandler,
} from '../controllers/orders.controller.js';

export function registerOrderRoutes(router: Router) {
  router.get('/orders/history', listOrderHistoryHandler);
  router.get('/orders/:orderId/history-item', getOrderHistoryItemHandler);
  router.post('/orders/paid', createPaidOrderHandler);
  router.post('/orders/manual', createManualOrderHandler);
  router.post('/orders/:orderId/refund', refundOrderHandler);
}

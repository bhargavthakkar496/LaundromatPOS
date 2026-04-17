import type { Router } from 'express';

import {
  clearActiveOrderSessionHandler,
  completeActiveOrderPaymentHandler,
  confirmActiveOrderSessionHandler,
  getActiveOrderSessionHandler,
  saveActiveOrderDraftHandler,
} from '../controllers/active_order_session.controller.js';

export function registerActiveOrderSessionRoutes(router: Router) {
  router.get('/active-order-session', getActiveOrderSessionHandler);
  router.delete('/active-order-session', clearActiveOrderSessionHandler);
  router.post('/active-order-session/draft', saveActiveOrderDraftHandler);
  router.post('/active-order-session/confirm', confirmActiveOrderSessionHandler);
  router.post('/active-order-session/payment', completeActiveOrderPaymentHandler);
}

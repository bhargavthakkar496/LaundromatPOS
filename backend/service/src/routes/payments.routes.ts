import type { Router } from 'express';

import {
  createPaymentSessionHandler,
  getPaymentSessionHandler,
} from '../controllers/payments.controller.js';

export function registerPaymentRoutes(router: Router) {
  router.post('/payments/sessions', createPaymentSessionHandler);
  router.get('/payments/sessions/:sessionId', getPaymentSessionHandler);
}

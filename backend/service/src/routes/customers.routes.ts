import type { Router } from 'express';

import {
  getCustomerByPhoneHandler,
  getCustomerProfileHandler,
  saveWalkInCustomerHandler,
} from '../controllers/customers.controller.js';

export function registerCustomerRoutes(router: Router) {
  router.get('/customers/by-phone', getCustomerByPhoneHandler);
  router.post('/customers/walk-in', saveWalkInCustomerHandler);
  router.get('/customers/profile', getCustomerProfileHandler);
}

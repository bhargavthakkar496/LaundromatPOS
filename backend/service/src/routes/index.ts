import { Router } from 'express';

import { registerActiveOrderSessionRoutes } from './active_order_session.routes.js';
import { registerAuthRoutes } from './auth.routes.js';
import { registerCustomerRoutes } from './customers.routes.js';
import { registerMachineRoutes } from './machines.routes.js';
import { registerOrderRoutes } from './orders.routes.js';
import { registerPaymentRoutes } from './payments.routes.js';
import { registerReservationRoutes } from './reservations.routes.js';

export function buildApiRouter() {
  const router = Router();
  registerAuthRoutes(router);
  registerMachineRoutes(router);
  registerCustomerRoutes(router);
  registerOrderRoutes(router);
  registerPaymentRoutes(router);
  registerReservationRoutes(router);
  registerActiveOrderSessionRoutes(router);
  return router;
}

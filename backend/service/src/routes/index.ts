import { Router } from "express";

import { registerActiveOrderSessionRoutes } from "./active_order_session.routes.js";
import { registerAuthRoutes } from "./auth.routes.js";
import { registerCustomerRoutes } from "./customers.routes.js";
import { registerInventoryRoutes } from "./inventory.routes.js";
import { registerMaintenanceRoutes } from "./maintenance.routes.js";
import { registerMachineRoutes } from "./machines.routes.js";
import { registerOrderRoutes } from "./orders.routes.js";
import { registerPaymentRoutes } from "./payments.routes.js";
import { registerPricingRoutes } from "./pricing.routes.js";
import { registerRefundRequestRoutes } from "./refund_requests.routes.js";
import { registerReservationRoutes } from "./reservations.routes.js";
import { registerStaffRoutes } from "./staff.routes.js";

export function buildApiRouter() {
  const router = Router();
  registerAuthRoutes(router);
  registerMachineRoutes(router);
  registerMaintenanceRoutes(router);
  registerInventoryRoutes(router);
  registerCustomerRoutes(router);
  registerOrderRoutes(router);
  registerPaymentRoutes(router);
  registerPricingRoutes(router);
  registerRefundRequestRoutes(router);
  registerReservationRoutes(router);
  registerActiveOrderSessionRoutes(router);
  registerStaffRoutes(router);
  return router;
}

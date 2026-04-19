import type { Router } from "express";

import {
  approveInventoryRestockRequestHandler,
  createInventoryRestockRequestHandler,
  getInventoryDashboardHandler,
  listInventoryItemMovementsHandler,
  listInventoryItemsHandler,
  listInventoryRestockRequestsHandler,
  procureInventoryRestockRequestHandler,
} from "../controllers/inventory.controller.js";

export function registerInventoryRoutes(router: Router) {
  router.get("/inventory/dashboard", getInventoryDashboardHandler);
  router.get("/inventory/items", listInventoryItemsHandler);
  router.get(
    "/inventory/items/:inventoryItemId/movements",
    listInventoryItemMovementsHandler,
  );
  router.get(
    "/inventory/restock-requests",
    listInventoryRestockRequestsHandler,
  );
  router.post(
    "/inventory/restock-requests",
    createInventoryRestockRequestHandler,
  );
  router.post(
    "/inventory/restock-requests/:restockRequestId/approve",
    approveInventoryRestockRequestHandler,
  );
  router.post(
    "/inventory/restock-requests/:restockRequestId/procure",
    procureInventoryRestockRequestHandler,
  );
}

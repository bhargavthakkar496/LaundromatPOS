import type { Router } from "express";

import {
  createRefundRequestHandler,
  listRefundRequestsHandler,
  processRefundRequestHandler,
} from "../controllers/refund_requests.controller.js";

export function registerRefundRequestRoutes(router: Router) {
  router.get("/refund-requests", listRefundRequestsHandler);
  router.post("/refund-requests", createRefundRequestHandler);
  router.post(
    "/refund-requests/:requestId/process",
    processRefundRequestHandler,
  );
}
import type { Router } from 'express';

import {
  completeMaintenanceRecordHandler,
  createMaintenanceRecordHandler,
  listMaintenanceEligibleMachinesHandler,
  listMaintenanceRecordsHandler,
  startMaintenanceRecordHandler,
} from '../controllers/maintenance.controller.js';

export function registerMaintenanceRoutes(router: Router) {
  router.get('/maintenance/eligible-machines', listMaintenanceEligibleMachinesHandler);
  router.get('/maintenance/records', listMaintenanceRecordsHandler);
  router.post('/maintenance/records', createMaintenanceRecordHandler);
  router.post('/maintenance/records/:recordId/start', startMaintenanceRecordHandler);
  router.post('/maintenance/records/:recordId/complete', completeMaintenanceRecordHandler);
}
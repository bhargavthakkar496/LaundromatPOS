import type { Router } from 'express';

import {
  getMachineHandler,
  listMachinesHandler,
  listReservableMachinesHandler,
  markMachinePickupHandler,
} from '../controllers/machines.controller.js';

export function registerMachineRoutes(router: Router) {
  router.get('/machines', listMachinesHandler);
  router.get('/machines/reservable', listReservableMachinesHandler);
  router.get('/machines/:machineId', getMachineHandler);
  router.post('/machines/:machineId/pickup', markMachinePickupHandler);
}

import type { Router } from 'express';

import { createReservationHandler } from '../controllers/reservations.controller.js';

export function registerReservationRoutes(router: Router) {
  router.post('/reservations', createReservationHandler);
}

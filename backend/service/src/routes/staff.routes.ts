import type { Router } from 'express';

import {
  createStaffPayoutHandler,
  listStaffLeaveRequestsHandler,
  listStaffMembersHandler,
  listStaffPayoutsHandler,
  listStaffShiftsHandler,
  markStaffPayoutPaidHandler,
  saveStaffShiftHandler,
  updateStaffLeaveRequestHandler,
} from '../controllers/staff.controller.js';

export function registerStaffRoutes(router: Router) {
  router.get('/staff/members', listStaffMembersHandler);
  router.get('/staff/shifts', listStaffShiftsHandler);
  router.post('/staff/shifts', saveStaffShiftHandler);
  router.get('/staff/leave-requests', listStaffLeaveRequestsHandler);
  router.patch('/staff/leave-requests/:leaveRequestId', updateStaffLeaveRequestHandler);
  router.get('/staff/payouts', listStaffPayoutsHandler);
  router.post('/staff/payouts', createStaffPayoutHandler);
  router.post('/staff/payouts/:payoutId/pay', markStaffPayoutPaidHandler);
}

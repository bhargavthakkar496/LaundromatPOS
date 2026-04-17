import type { Router } from 'express';

import { loginHandler } from '../controllers/auth.controller.js';

export function registerAuthRoutes(router: Router) {
  router.post('/auth/login', loginHandler);
}

import type { Router } from 'express';

import {
  createPricingCampaignHandler,
  listPricingCampaignsHandler,
  listPricingServiceFeesHandler,
  previewPricingQuoteHandler,
  updateMachinePriceHandler,
  updatePricingCampaignHandler,
  updatePricingServiceFeeHandler,
} from '../controllers/pricing.controller.js';

export function registerPricingRoutes(router: Router) {
  router.get('/pricing/service-fees', listPricingServiceFeesHandler);
  router.patch('/pricing/service-fees/:serviceCode', updatePricingServiceFeeHandler);
  router.get('/pricing/campaigns', listPricingCampaignsHandler);
  router.post('/pricing/campaigns', createPricingCampaignHandler);
  router.patch('/pricing/campaigns/:campaignId', updatePricingCampaignHandler);
  router.patch('/pricing/machines/:machineId', updateMachinePriceHandler);
  router.post('/pricing/quote', previewPricingQuoteHandler);
}
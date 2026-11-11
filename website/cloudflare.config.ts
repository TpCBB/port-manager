import { defineConfig } from 'cf/config';

export default defineConfig({
  worker: {
    name: 'port-manager',
    compatibilityDate: '2026-11-11',
    workersDev: true,
    domains: ['port-manager.tpc28yo.xyz'],
    previewUrls: false,
    assets: {
      htmlHandling: 'auto-trailing-slash',
      notFoundHandling: '404-page',
    },
    observability: {
      enabled: true,
      logs: { enabled: true, headSamplingRate: 1 },
      traces: { enabled: true, headSamplingRate: 0.01 },
    },
  },
});

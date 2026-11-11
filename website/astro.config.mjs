import { defineConfig } from 'astro/config';
import { siteURL } from './site.config.mjs';

export default defineConfig({
  site: siteURL,
  output: 'static',
  vite: {
    server: { fs: { allow: ['..'] } },
  },
});

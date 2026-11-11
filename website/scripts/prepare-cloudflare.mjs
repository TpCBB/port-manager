import { access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { loadAndParseConfig } from '@cloudflare/config';
import {
  cleanBuildOutputDir,
  readBuildOutput,
  writeAssets,
  writeRootConfig,
  writeWorkerConfig,
} from '@cloudflare/build-output-utils';

// Package Astro's existing static output using Cloudflare's official utilities.
// Exact package versions are pinned while the cf Build Output API is in beta.
const root = fileURLToPath(new URL('../', import.meta.url));
const sourceDirectory = fileURLToPath(new URL('../dist/', import.meta.url));
const buildContext = { mode: 'production', isPreview: false };
await access(new URL('../dist/index.html', import.meta.url));
const { result } = await loadAndParseConfig(
  fileURLToPath(new URL('../cloudflare.config.ts', import.meta.url)),
  buildContext,
);
if (!result.success) throw new Error(result.error.message);
const { worker, containers, ...settings } = result.data;
if (!worker || containers?.length)
  throw new Error('Expected one static website Worker.');
await cleanBuildOutputDir(root);
await writeAssets({ root, sourceDirectory });
await writeWorkerConfig({ root, config: worker });
await writeRootConfig(root, settings, buildContext);
const output = await readBuildOutput(root);
if (!output.workers.default.assetsDir || output.workers.default.bundleDir) {
  throw new Error('Expected an assets-only build.');
}
console.log(
  `Prepared static website for ${output.workers.default.config.name}.`,
);

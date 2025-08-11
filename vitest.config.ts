import { defineConfig } from 'vitest/config';
import path from 'node:path';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts', 'tests/**/*.int.test.ts'],
    pool: 'forks'
  },
  resolve: {
    alias: {
      '@thankful/database': path.resolve(__dirname, 'packages/database/src/index.ts'),
      '@thankful/metrics': path.resolve(__dirname, 'packages/metrics/src/index.ts'),
      '@thankful/verification': path.resolve(__dirname, 'packages/verification/src/index.ts'),
      '@thankful/ratelimit': path.resolve(__dirname, 'packages/ratelimit/src/index.ts'),
      '@thankful/notifications': path.resolve(__dirname, 'packages/notifications/src/index.ts')
    }
  }
});



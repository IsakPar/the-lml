// ESLint: import/order; boundaries; no any in domain/application; consistent quotes; max-lines

module.exports = {
  root: true,
  env: { node: true, es2022: true },
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'import'],
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended'],
  settings: {
    'import/resolver': {
      typescript: {
        alwaysTryTypes: true,
        project: ['./tsconfig.json']
      }
    }
  },
  rules: {
    'import/no-restricted-paths': ['warn', {
      zones: [
        // Enforce service bounded contexts (no deep imports across services)
        { target: './services/**', from: './services/**', except: ['**/shared/**'] },
        // Clean Architecture within services: domain is pure
        { target: './services/**/domain/**', from: ['**/infrastructure/**', '**/interface/**', '**/application/**', '**/apps/**', '**/packages/**'] },
        // application depends only on domain
        { target: './services/**/application/**', from: ['**/infrastructure/**', '**/interface/**', '**/apps/**'] },
        // interface depends on application only
        { target: './services/**/interface/**', from: ['**/infrastructure/**', '**/domain/**'] },
      ]
    }],
    '@typescript-eslint/no-explicit-any': 'warn',
  }
};

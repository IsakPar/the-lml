/* eslint-env node */
module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'boundaries'],
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended'],
  ignorePatterns: ['dist', 'node_modules'],
  rules: {
    'import/no-default-export': 'error',
    'max-lines': ['warn', { max: 200, skipBlankLines: true, skipComments: true }],
    'boundaries/element-types': ['error', {
      default: 'disallow',
      rules: [
        { from: ['packages/**'], allow: ['packages/**'] },
        { from: ['services/**/domain/**'], allow: ['services/**/domain/**'] },
        { from: ['services/**/application/**'], allow: ['services/**/domain/**', 'services/**/application/**', 'packages/**'] },
        { from: ['services/**/infrastructure/**'], allow: ['services/**/application/**', 'packages/**'] },
        { from: ['packages/platform/**'], allow: ['services/**/application/**', 'services/**/infrastructure/**', 'packages/**'] },
        { from: ['apps/**'], allow: ['packages/platform/**', 'packages/**'] }
      ]
    }]
  },
  overrides: [
    {
      files: ['apps/**/src/composition.ts', 'packages/platform/**/src/**/*.ts'],
      rules: {
        'boundaries/element-types': 'off'
      }
    },
    {
      files: ['**/*.test.ts', '**/*.spec.ts'],
      rules: {
        'boundaries/element-types': 'off'
      }
    }
  ]
};



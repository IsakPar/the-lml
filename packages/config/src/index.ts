export function loadConfig() {
  return {
    env: process.env.NODE_ENV ?? 'development'
  };
}




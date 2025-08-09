async function main() {
  // Placeholder worker bootstrap; will import from @platform/worker later
  // eslint-disable-next-line no-console
  console.log('Worker starting...');
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});



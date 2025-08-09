import { z } from 'zod';
const EnvSchema = z
    .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    DATABASE_URL: z.string().min(1),
    REDIS_URL: z.string().min(1),
    MONGODB_URL: z.string().min(1),
    STRIPE_SECRET_KEY: z.string().min(1),
    STRIPE_WEBHOOK_SECRET: z.string().min(1),
    HOLD_TTL_SECONDS: z.coerce.number().int().positive().default(120),
    HOLD_EXTENSION_SECONDS: z.coerce.number().int().nonnegative().default(60),
    HOLD_MAX_TTL_SECONDS: z.coerce.number().int().positive().default(180),
    RATE_LIMIT_HOLD_PER_MIN: z.coerce.number().int().positive().default(10),
    RATE_LIMIT_AUTH_PER_MIN: z.coerce.number().int().positive().default(20)
})
    .superRefine((env, ctx) => {
    const allowed = env.HOLD_TTL_SECONDS + env.HOLD_EXTENSION_SECONDS <= env.HOLD_MAX_TTL_SECONDS;
    if (!allowed) {
        ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: 'HOLD_EXTENSION_SECONDS must be <= HOLD_MAX_TTL_SECONDS - HOLD_TTL_SECONDS'
        });
    }
});
export function loadConfig(source = process.env) {
    const parsed = EnvSchema.safeParse(source);
    if (!parsed.success) {
        // eslint-disable-next-line no-console
        console.error(parsed.error.format());
        throw new Error('Invalid configuration');
    }
    return parsed.data;
}

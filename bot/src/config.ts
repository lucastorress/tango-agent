import { z } from "zod";

const envSchema = z
  .object({
    TELEGRAM_BOT_TOKEN: z.string().min(1, "TELEGRAM_BOT_TOKEN is required"),
    TELEGRAM_USER_ID: z
      .string()
      .min(1, "TELEGRAM_USER_ID is required")
      .transform((v) => v.split(",").map(Number)),
    ANTHROPIC_API_KEY: z.string().optional(),
    CLAUDE_CODE_OAUTH_TOKEN: z.string().optional(),
    BOT_DEFAULT_MODEL: z.enum(["haiku", "sonnet", "opus"]).default("haiku"),
    BOT_SESSION_TTL_MINUTES: z.coerce.number().default(120),
    BOT_MAX_TURNS: z.coerce.number().default(30),
    BOT_BOOTSTRAP_DIR: z.string().default("/home/node/bootstrap"),
    BOT_DATA_DIR: z.string().default("/home/node/data"),
    BOT_CWD: z.string().default("/home/node/workspace"),
  })
  .refine((env) => env.ANTHROPIC_API_KEY || env.CLAUDE_CODE_OAUTH_TOKEN, {
    message:
      "At least one of ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN must be set",
  });

export type Config = z.infer<typeof envSchema>;

let _config: Config | null = null;

export function loadConfig(): Config {
  if (_config) return _config;
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    console.error("Configuration error:");
    for (const issue of result.error.issues) {
      console.error(`  - ${issue.path.join(".")}: ${issue.message}`);
    }
    process.exit(1);
  }
  _config = result.data;
  return _config;
}

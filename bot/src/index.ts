import { loadConfig } from "./config.js";
import { createBot } from "./bot.js";
import { loadTeam } from "./agent.js";

async function main() {
  console.log("🥭 Tango Bot starting...");

  const config = loadConfig();

  // Pre-load bootstrap files
  loadTeam(config);

  const { bot, sessions } = createBot(config);

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    console.log(`\n${signal} received, shutting down...`);
    bot.stop();
    sessions.save();
    console.log("Sessions saved. Bye!");
    process.exit(0);
  };

  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  // Auto-save sessions periodically (every 5 min)
  setInterval(() => sessions.save(), 5 * 60 * 1000);

  // Start polling
  console.log("Bot polling started");
  bot.start({
    onStart: () => console.log("🥭 Tango Bot is running!"),
    allowed_updates: ["message"],
  });
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});

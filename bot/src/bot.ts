import { Bot } from "grammy";
import { apiThrottler } from "@grammyjs/transformer-throttler";
import type { Config } from "./config.js";
import { SessionManager } from "./session.js";
import { TelegramStreamer } from "./streamer.js";
import { runAgent, reloadTeam } from "./agent.js";

// Per-chat mutex to serialize message processing
const chatLocks = new Map<number, Promise<void>>();

function withLock(chatId: number, fn: () => Promise<void>): Promise<void> {
  const prev = chatLocks.get(chatId) ?? Promise.resolve();
  const next = prev.then(fn, fn);
  chatLocks.set(chatId, next);
  // Cleanup when done
  next.finally(() => {
    if (chatLocks.get(chatId) === next) chatLocks.delete(chatId);
  });
  return next;
}

export function createBot(config: Config): { bot: Bot; sessions: SessionManager } {
  const bot = new Bot(config.TELEGRAM_BOT_TOKEN);
  const sessions = new SessionManager(config);
  const allowedUsers = new Set(config.TELEGRAM_USER_ID);

  // Rate limiting
  bot.api.config.use(apiThrottler());

  // Auth middleware: silently drop unauthorized users and groups
  bot.use(async (ctx, next) => {
    // Ignore non-private chats
    if (ctx.chat?.type !== "private") return;
    // Ignore unauthorized users
    if (!ctx.from || !allowedUsers.has(ctx.from.id)) return;
    await next();
  });

  // Commands

  bot.command("start", async (ctx) => {
    await ctx.reply(
      "🥭 Tango Bot ativo!\n\n" +
        "Manda uma mensagem e eu respondo.\n" +
        "/reset — Nova conversa\n" +
        "/model haiku|sonnet|opus — Trocar modelo\n" +
        "/reload — Recarregar bootstrap\n" +
        "/status — Ver status",
    );
  });

  bot.command("reset", async (ctx) => {
    sessions.reset(ctx.chat.id);
    await ctx.reply("Sessao resetada. Proxima mensagem inicia conversa nova.");
  });

  bot.command("model", async (ctx) => {
    const arg = ctx.match?.trim().toLowerCase();
    if (!arg || !["haiku", "sonnet", "opus"].includes(arg)) {
      const session = sessions.get(ctx.chat.id);
      const current = session?.model ?? config.BOT_DEFAULT_MODEL;
      await ctx.reply(
        `Modelo atual: ${current}\nUso: /model haiku|sonnet|opus`,
      );
      return;
    }
    const session = sessions.getOrCreate(ctx.chat.id, config.BOT_DEFAULT_MODEL);
    session.model = arg;
    sessions.set(ctx.chat.id, session);
    await ctx.reply(`Modelo trocado para: ${arg}`);
  });

  bot.command("reload", async (ctx) => {
    reloadTeam(config);
    await ctx.reply("Bootstrap recarregado.");
  });

  bot.command("status", async (ctx) => {
    const session = sessions.get(ctx.chat.id);
    const stats = sessions.status();
    const model = session?.model ?? config.BOT_DEFAULT_MODEL;
    const hasSession = session?.sessionId ? "sim" : "nao";
    await ctx.reply(
      `🥭 Tango Bot\n` +
        `Modelo: ${model}\n` +
        `Sessao ativa: ${hasSession}\n` +
        `Sessoes totais: ${stats.active}`,
    );
  });

  // Message handler

  bot.on("message:text", async (ctx) => {
    const chatId = ctx.chat.id;
    const text = ctx.message.text;

    // Skip commands (already handled)
    if (text.startsWith("/")) return;

    await withLock(chatId, async () => {
      const session = sessions.getOrCreate(chatId, config.BOT_DEFAULT_MODEL);
      const streamer = new TelegramStreamer(chatId, ctx.api);

      try {
        await streamer.start();

        const result = await runAgent(
          config,
          session,
          text,
          (chunk) => streamer.append(chunk),
        );

        // Update session
        if (result.sessionId) {
          session.sessionId = result.sessionId;
        }
        session.lastActivity = Date.now();
        sessions.set(chatId, session);

        // Send final response
        await streamer.sendFinal(result.text);
      } catch (err) {
        const errMsg = err instanceof Error ? err.message : String(err);
        console.error(`Error processing message for chat ${chatId}:`, errMsg);

        let userMsg = "Erro ao processar mensagem. Tente novamente.";
        if (errMsg.includes("abort")) {
          userMsg = "Timeout — a query demorou mais de 5 minutos. Tente simplificar o pedido.";
        } else if (errMsg.includes("rate_limit")) {
          userMsg = "Rate limit atingido. Aguarde um momento e tente novamente.";
        }

        try {
          await streamer.sendFinal(userMsg);
        } catch {
          await ctx.reply(userMsg);
        }
      }
    });
  });

  return { bot, sessions };
}

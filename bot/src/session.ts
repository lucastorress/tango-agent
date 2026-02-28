import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import type { Config } from "./config.js";

export interface ChatSession {
  sessionId?: string;
  lastActivity: number;
  model: string;
}

type SessionStore = Map<number, ChatSession>;

export class SessionManager {
  private sessions: SessionStore = new Map();
  private filePath: string;
  private ttlMs: number;

  constructor(config: Config) {
    this.filePath = join(config.BOT_DATA_DIR, "sessions.json");
    this.ttlMs = config.BOT_SESSION_TTL_MINUTES * 60 * 1000;
    this.load();
  }

  get(chatId: number): ChatSession | undefined {
    const session = this.sessions.get(chatId);
    if (!session) return undefined;
    if (Date.now() - session.lastActivity > this.ttlMs) {
      this.sessions.delete(chatId);
      return undefined;
    }
    return session;
  }

  set(chatId: number, session: ChatSession): void {
    this.sessions.set(chatId, session);
  }

  touch(chatId: number): void {
    const session = this.sessions.get(chatId);
    if (session) session.lastActivity = Date.now();
  }

  setModel(chatId: number, model: string): void {
    const session = this.sessions.get(chatId);
    if (session) {
      session.model = model;
    }
  }

  reset(chatId: number): void {
    this.sessions.delete(chatId);
  }

  getOrCreate(chatId: number, defaultModel: string): ChatSession {
    let session = this.get(chatId);
    if (!session) {
      session = { lastActivity: Date.now(), model: defaultModel };
      this.sessions.set(chatId, session);
    }
    return session;
  }

  status(): { active: number; total: number } {
    this.cleanup();
    return { active: this.sessions.size, total: this.sessions.size };
  }

  save(): void {
    try {
      mkdirSync(dirname(this.filePath), { recursive: true });
      const data: Record<string, ChatSession> = {};
      for (const [k, v] of this.sessions) data[String(k)] = v;
      writeFileSync(this.filePath, JSON.stringify(data, null, 2));
    } catch (err) {
      console.error("Failed to save sessions:", err);
    }
  }

  private load(): void {
    try {
      const raw = readFileSync(this.filePath, "utf-8");
      const data = JSON.parse(raw) as Record<string, ChatSession>;
      for (const [k, v] of Object.entries(data)) {
        this.sessions.set(Number(k), v);
      }
      this.cleanup();
      console.log(`Loaded ${this.sessions.size} sessions from disk`);
    } catch {
      // File doesn't exist or is corrupt — start fresh
    }
  }

  private cleanup(): void {
    const now = Date.now();
    for (const [k, v] of this.sessions) {
      if (now - v.lastActivity > this.ttlMs) this.sessions.delete(k);
    }
  }
}

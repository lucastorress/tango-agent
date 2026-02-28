import type { Api } from "grammy";

const TELEGRAM_MAX_LENGTH = 4096;
const FLUSH_INTERVAL_MS = 1000;

export class TelegramStreamer {
  private chatId: number;
  private api: Api;
  private messageId: number | null = null;
  private buffer = "";
  private lastSent = "";
  private timer: ReturnType<typeof setInterval> | null = null;
  private messageIds: number[] = [];
  private finished = false;

  constructor(chatId: number, api: Api) {
    this.chatId = chatId;
    this.api = api;
  }

  async start(): Promise<void> {
    const msg = await this.api.sendMessage(this.chatId, "...");
    this.messageId = msg.message_id;
    this.messageIds.push(msg.message_id);
    this.timer = setInterval(() => this.flush(), FLUSH_INTERVAL_MS);
  }

  append(text: string): void {
    this.buffer += text;
  }

  async finish(): Promise<void> {
    this.finished = true;
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    await this.flush();
  }

  async sendFinal(text: string): Promise<void> {
    this.finished = true;
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }

    if (!text || text.trim() === "") return;

    // If no message was sent yet, send a new one
    if (!this.messageId) {
      await this.sendChunked(text);
      return;
    }

    // Replace the placeholder with final text
    const chunks = splitText(text, TELEGRAM_MAX_LENGTH);
    try {
      await this.api.editMessageText(this.chatId, this.messageId, chunks[0]);
    } catch {
      // ignore edit errors
    }
    for (let i = 1; i < chunks.length; i++) {
      const msg = await this.api.sendMessage(this.chatId, chunks[i]);
      this.messageIds.push(msg.message_id);
    }
  }

  private async flush(): Promise<void> {
    if (!this.messageId) return;

    const text = this.buffer.trim() || "...";
    if (text === this.lastSent) return;

    // If buffer exceeds limit, start a new message
    if (text.length > TELEGRAM_MAX_LENGTH) {
      const cutoff = text.lastIndexOf("\n", TELEGRAM_MAX_LENGTH - 100);
      const splitAt = cutoff > 0 ? cutoff : TELEGRAM_MAX_LENGTH;
      const first = text.slice(0, splitAt);
      const rest = text.slice(splitAt);

      try {
        await this.api.editMessageText(this.chatId, this.messageId, first);
        this.lastSent = first;
      } catch {
        // ignore "message not modified"
      }

      const msg = await this.api.sendMessage(this.chatId, rest.trim() || "...");
      this.messageId = msg.message_id;
      this.messageIds.push(msg.message_id);
      this.buffer = rest;
      this.lastSent = "";
      return;
    }

    try {
      await this.api.editMessageText(this.chatId, this.messageId, text);
      this.lastSent = text;
    } catch {
      // ignore "message not modified" or other transient errors
    }
  }

  private async sendChunked(text: string): Promise<void> {
    const chunks = splitText(text, TELEGRAM_MAX_LENGTH);
    for (const chunk of chunks) {
      const msg = await this.api.sendMessage(this.chatId, chunk);
      this.messageIds.push(msg.message_id);
    }
  }
}

function splitText(text: string, maxLen: number): string[] {
  if (text.length <= maxLen) return [text];
  const chunks: string[] = [];
  let remaining = text;
  while (remaining.length > 0) {
    if (remaining.length <= maxLen) {
      chunks.push(remaining);
      break;
    }
    const cutoff = remaining.lastIndexOf("\n", maxLen);
    const splitAt = cutoff > 0 ? cutoff : maxLen;
    chunks.push(remaining.slice(0, splitAt));
    remaining = remaining.slice(splitAt).trimStart();
  }
  return chunks;
}

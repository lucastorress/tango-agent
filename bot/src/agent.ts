import { readFileSync } from "node:fs";
import { join } from "node:path";
import { query, type SDKMessage, type AgentDefinition } from "@anthropic-ai/claude-agent-sdk";
import type { Config } from "./config.js";
import type { ChatSession } from "./session.js";

// Bootstrap file loading

function readBootstrap(baseDir: string, agent: string, file: string): string {
  try {
    return readFileSync(join(baseDir, agent, file), "utf-8");
  } catch {
    return "";
  }
}

function loadAgentPrompt(baseDir: string, agent: string, files: string[]): string {
  return files
    .map((f) => readBootstrap(baseDir, agent, f))
    .filter(Boolean)
    .join("\n\n---\n\n");
}

// Agent definitions

interface AgentTeam {
  tangoPrompt: string;
  agents: Record<string, AgentDefinition>;
}

let _team: AgentTeam | null = null;

export function loadTeam(config: Config): AgentTeam {
  if (_team) return _team;

  const dir = config.BOT_BOOTSTRAP_DIR;

  const tangoPrompt = loadAgentPrompt(dir, "tango", [
    "IDENTITY.md",
    "SOUL.md",
    "USER.md",
    "AGENTS.md",
    "HEARTBEAT.md",
  ]);

  const atlasPrompt = loadAgentPrompt(dir, "atlas", [
    "IDENTITY.md",
    "SOUL.md",
    "AGENTS.md",
  ]);

  const pixelPrompt =
    loadAgentPrompt(dir, "pixel", [
      "IDENTITY.md",
      "SOUL.md",
      "AGENTS.md",
      "TOOLS.md",
    ]) + "\n\nSeu workspace: /home/node/workspace-pixel\nProjetos: /home/node/projects/";

  const hawkPrompt =
    loadAgentPrompt(dir, "hawk", [
      "IDENTITY.md",
      "SOUL.md",
      "AGENTS.md",
      "TOOLS.md",
    ]) + "\n\nSeu workspace: /home/node/workspace-hawk\nProjetos: /home/node/projects/";

  const sentinelPrompt =
    loadAgentPrompt(dir, "sentinel", [
      "IDENTITY.md",
      "SOUL.md",
      "AGENTS.md",
      "TOOLS.md",
    ]) + "\n\nSeu workspace: /home/node/workspace-sentinel\nProjetos: /home/node/projects/";

  const agents: Record<string, AgentDefinition> = {
    atlas: {
      description:
        "Estrategista e pesquisador. Pesquisa profunda, analise, specs, comparacoes. Use para tarefas que precisam de pesquisa web ou analise de dados.",
      prompt: atlasPrompt,
      tools: ["WebSearch", "WebFetch", "Read", "Grep", "Glob"],
      model: "haiku",
    },
    pixel: {
      description:
        "Construtor. Codigo, implementacao, refactor, testes, git. Use para qualquer tarefa de programacao.",
      prompt: pixelPrompt,
      tools: ["Read", "Edit", "Write", "Bash", "Grep", "Glob"],
      model: "sonnet",
    },
    hawk: {
      description:
        "Guardiao de qualidade. Code review, testes, debugging, validacao de arquitetura. Use para revisar codigo ou investigar bugs.",
      prompt: hawkPrompt,
      tools: ["Read", "Edit", "Write", "Bash", "Grep", "Glob"],
      model: "sonnet",
    },
    sentinel: {
      description:
        "Seguranca e operacoes. Auditoria, hardening, deploy, Docker, CI/CD. Use para tarefas de seguranca ou infraestrutura.",
      prompt: sentinelPrompt,
      tools: ["Read", "Edit", "Write", "Bash", "Grep", "Glob"],
      model: "sonnet",
    },
  };

  _team = { tangoPrompt, agents };
  console.log("Agent team loaded from bootstrap files");
  return _team;
}

export function reloadTeam(config: Config): AgentTeam {
  _team = null;
  return loadTeam(config);
}

// Query execution

const MAX_RETRIES = 3;
const RETRY_BASE_MS = 2000;

export interface QueryResult {
  text: string;
  sessionId?: string;
  cost?: number;
  turns?: number;
}

export async function runAgent(
  config: Config,
  session: ChatSession,
  userMessage: string,
  onText: (chunk: string) => void,
  abortSignal?: AbortSignal,
): Promise<QueryResult> {
  const team = loadTeam(config);

  const abortController = new AbortController();
  if (abortSignal) {
    abortSignal.addEventListener("abort", () => abortController.abort());
  }

  // Timeout: 5 minutes
  const timeout = setTimeout(() => abortController.abort(), 5 * 60 * 1000);

  let lastError: Error | null = null;

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const result = await executeQuery(
        config,
        team,
        session,
        userMessage,
        onText,
        abortController,
      );
      clearTimeout(timeout);
      return result;
    } catch (err) {
      lastError = err as Error;
      const msg = lastError.message || "";

      // Retry on rate limit or overloaded
      if (msg.includes("rate_limit") || msg.includes("overloaded") || msg.includes("529")) {
        const delay = RETRY_BASE_MS * Math.pow(2, attempt);
        console.warn(`Rate limited, retrying in ${delay}ms (attempt ${attempt + 1}/${MAX_RETRIES})`);
        await sleep(delay);
        continue;
      }

      // Don't retry other errors
      break;
    }
  }

  clearTimeout(timeout);
  throw lastError ?? new Error("Query failed");
}

async function executeQuery(
  config: Config,
  team: AgentTeam,
  session: ChatSession,
  userMessage: string,
  onText: (chunk: string) => void,
  abortController: AbortController,
): Promise<QueryResult> {
  const q = query({
    prompt: userMessage,
    options: {
      systemPrompt: team.tangoPrompt,
      model: session.model ?? config.BOT_DEFAULT_MODEL,
      allowedTools: ["WebSearch", "WebFetch", "Task"],
      permissionMode: "bypassPermissions",
      allowDangerouslySkipPermissions: true,
      cwd: config.BOT_CWD,
      resume: session.sessionId,
      maxTurns: config.BOT_MAX_TURNS,
      settingSources: [],
      agents: team.agents,
      abortController,
      includePartialMessages: true,
    },
  });

  let sessionId: string | undefined;
  let resultText = "";
  let cost: number | undefined;
  let turns: number | undefined;

  for await (const message of q) {
    switch (message.type) {
      case "system":
        if (message.subtype === "init") {
          sessionId = message.session_id;
        }
        break;

      case "stream_event":
        // Only handle top-level assistant messages (not subagent)
        if (message.parent_tool_use_id) break;
        if (
          message.event.type === "content_block_delta" &&
          "delta" in message.event &&
          message.event.delta.type === "text_delta"
        ) {
          onText(message.event.delta.text);
        }
        break;

      case "assistant":
        // Capture full text from top-level assistant messages
        if (message.parent_tool_use_id) break;
        resultText = "";
        if (message.message?.content) {
          for (const block of message.message.content) {
            if (block.type === "text") resultText += block.text;
          }
        }
        break;

      case "result":
        sessionId = message.session_id;
        cost = message.total_cost_usd;
        turns = message.num_turns;
        if (message.subtype === "success" && message.result) {
          resultText = message.result;
        }
        break;
    }
  }

  return { text: resultText, sessionId, cost, turns };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

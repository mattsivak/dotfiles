import { spawnSync } from "node:child_process";
import { listSessions, currentSession, killSession } from "../tmux.ts";

function fzfPick(prompt: string, options: string[], defaultQuery?: string): string | null {
  const args = ["--prompt", prompt, "--reverse"];
  if (defaultQuery) args.push("--query", defaultQuery);

  const result = spawnSync("fzf", args, {
    input: options.join("\n"),
    encoding: "utf-8",
    stdio: ["pipe", "pipe", "inherit"],
  });

  if (result.status !== 0) return null;
  return result.stdout.trim() || null;
}

export function exit(): void {
  const sessions = listSessions();

  if (sessions.length === 0) {
    console.error("No tmux sessions found.");
    process.exit(1);
  }

  const current = currentSession();

  const lines = sessions.map((s) => {
    const marker = s.attached ? " (attached)" : "";
    return `${s.name.padEnd(20)} ${String(s.windowCount).padStart(2)} windows${marker}`;
  });

  const selection = fzfPick("kill session > ", lines, current ?? undefined);
  if (!selection) {
    process.exit(0);
  }

  const target = selection.split(/\s+/)[0];
  killSession(target);
  console.log(`Killed session: ${target}`);
}

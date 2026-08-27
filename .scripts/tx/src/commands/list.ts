import { listSessions, currentSession } from "../tmux.ts";

export function list(): void {
  const sessions = listSessions();

  if (sessions.length === 0) {
    console.error("No tmux sessions found.");
    process.exit(1);
  }

  const current = currentSession();

  for (const s of sessions) {
    const marker = s.name === current ? " *" : "";
    console.log(
      `${s.name.padEnd(20)} ${String(s.windowCount).padStart(2)} windows   ${s.activeWindowName}${marker}`
    );
  }
}

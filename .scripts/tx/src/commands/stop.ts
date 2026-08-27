import confirm from "@inquirer/confirm";
import { listSessions, killServer, TmuxError } from "../tmux.ts";
import { BACK, withBack } from "../prompts.ts";

export async function stop(): Promise<void> {
  const sessions = listSessions();

  if (sessions.length === 0) {
    console.error("No tmux server running.");
    process.exit(1);
  }

  console.log(`Active sessions (${sessions.length}):`);
  for (const s of sessions) {
    const marker = s.attached ? " (attached)" : "";
    console.log(`  ${s.name} — ${s.windowCount} window(s)${marker}`);
  }

  const confirmed = await withBack((ctx) =>
    confirm({
      message: `Kill tmux server and all ${sessions.length} session(s)?`,
      default: false,
    }, ctx),
  );
  if (confirmed === BACK) {
    process.exit(0);
  }

  if (!confirmed) process.exit(0);

  try {
    killServer();
  } catch (e) {
    if (e instanceof TmuxError) {
      console.error(`Error: ${e.message}`);
      process.exit(1);
    }
    throw e;
  }

  console.log("Tmux server stopped.");
}

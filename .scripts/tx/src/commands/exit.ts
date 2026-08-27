import checkbox from "@inquirer/checkbox";
import confirm from "@inquirer/confirm";
import { listSessions, currentSession, killSession, TmuxError } from "../tmux.ts";
import { parseArgs } from "../args.ts";
import { BACK, withBack } from "../prompts.ts";

function killOrExit(name: string): void {
  try {
    killSession(name);
  } catch (e) {
    if (e instanceof TmuxError) {
      console.error(`Error killing "${name}": ${e.message}`);
      process.exit(1);
    }
    throw e;
  }
}

export async function exit(args: string[]): Promise<void> {
  const { pageSize, positional } = parseArgs(args);

  // Direct mode: `tx exit a b c` kills each named session, skipping the UI.
  if (positional.length > 0) {
    for (const name of positional) {
      killOrExit(name);
      console.log(`Killed session: ${name}`);
    }
    return;
  }

  const sessions = listSessions();

  if (sessions.length === 0) {
    console.error("No tmux sessions found.");
    process.exit(1);
  }

  const current = currentSession();

  // Put current session first so the cursor lands on it.
  const sorted = [...sessions].sort((a, b) => {
    if (a.name === current) return -1;
    if (b.name === current) return 1;
    return 0;
  });

  const choices = sorted.map((s) => {
    const tag = s.name === current ? " (current)" : s.attached ? " (attached)" : "";
    return {
      name: `${s.name.padEnd(20)} ${String(s.windowCount).padStart(2)} windows${tag}`,
      value: s.name,
      checked: s.name === current,
    };
  });

  // Main loop: ESC at confirm goes back to the picker.
  while (true) {
    const selected = await withBack((ctx) =>
      checkbox(
        {
          message: "Select sessions to kill (space toggles, enter confirms)",
          pageSize,
          choices,
          loop: false,
        },
        ctx,
      ),
    );
    if (selected === BACK) {
      process.exit(0);
    }
    if (selected.length === 0) {
      console.log("Nothing selected.");
      process.exit(0);
    }

    const includesCurrent = current !== null && selected.includes(current);
    const plural = selected.length === 1 ? "" : "s";
    let message = `Kill ${selected.length} session${plural}: ${selected.join(", ")}?`;
    if (includesCurrent) {
      message += `\n⚠ includes current session "${current}" — you will be detached`;
    }

    const confirmed = await withBack((ctx) => confirm({ message, default: false }, ctx));
    if (confirmed === BACK) {
      continue;
    }
    if (!confirmed) continue;

    // Kill non-current sessions first so the client stays alive throughout;
    // the current session (if selected) is killed last.
    const others = selected.filter((name) => name !== current);
    for (const name of others) {
      killOrExit(name);
    }

    console.log(`Killed: ${selected.join(", ")}`);

    if (includesCurrent) {
      killOrExit(current!);
    }
    return;
  }
}

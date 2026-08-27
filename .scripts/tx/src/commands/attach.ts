import search from "@inquirer/search";
import input from "@inquirer/input";
import {
  listWindows,
  switchClient,
  attachSession,
  newWindow,
  newSession,
  sessionExists,
  isInsideTmux,
  TmuxError,
  type TmuxWindow,
} from "../tmux.ts";
import { parseArgs } from "../args.ts";
import { loadTemplates, applyTemplate } from "../templates.ts";
import { BACK, withBack } from "../prompts.ts";

const NEW_WINDOW_VALUE = "__new_window__";
const NEW_SESSION_VALUE = "__new_session__";
const CUSTOM_SESSION_VALUE = "__custom_session__";

function shortenPath(fullPath: string): string {
  const home = process.env.HOME ?? "";
  if (home && fullPath.startsWith(home)) {
    return "~" + fullPath.slice(home.length);
  }
  return fullPath;
}

function groupBySession(windows: TmuxWindow[]): Map<string, TmuxWindow[]> {
  const groups = new Map<string, TmuxWindow[]>();
  for (const w of windows) {
    const existing = groups.get(w.session);
    if (existing) {
      existing.push(w);
    } else {
      groups.set(w.session, [w]);
    }
  }
  return groups;
}

function attachToTarget(target: string): void {
  if (isInsideTmux()) {
    switchClient(target);
  } else {
    attachSession(target);
  }
}

export async function attach(args: string[]): Promise<void> {
  const { pageSize, positional } = parseArgs(args);
  const directTarget = positional[0];

  if (directTarget) {
    attachToTarget(directTarget);
    return;
  }

  const windows = listWindows();
  const groups = groupBySession(windows);

  // --- Main loop: ESC goes back to session picker ---
  sessionLoop: while (true) {
    // --- Step 1: pick a session ---
    let sessionSelection: string;

    if (windows.length === 0) {
      // No tmux running — go straight to new session flow
      sessionSelection = NEW_SESSION_VALUE;
    } else {
      const sessionChoices = [
          ...[...groups.entries()].map(([session, wins]) => {
            const activePath = wins.find((w) => w.active)?.path;
            const display = activePath ? shortenPath(activePath) : "";
            const count = wins.length;
            return {
              name: `${session.padEnd(20)} ${String(count).padStart(2)} windows   ${display}`,
              value: session,
            };
          }),
        { name: "+ new session", value: NEW_SESSION_VALUE },
      ];

      const sessionResult = await withBack((ctx) =>
        search({
          message: "session",
          pageSize,
          source: (term) => {
            if (!term) return sessionChoices;
            const lower = term.toLowerCase();
            return sessionChoices.filter((c) => c.name.toLowerCase().includes(lower));
          },
        }, ctx),
      );
      if (sessionResult === BACK) {
        process.exit(0);
      }
      sessionSelection = sessionResult;
    }

    if (sessionSelection === NEW_SESSION_VALUE) {
      // --- Step 2: template picker (ESC goes back to session picker) ---
      const templates = loadTemplates();
      
      interface Choice {
        value: string;
        name: string;
        description?: string;
      }

      const templateChoices: Choice[] = [
        { value: CUSTOM_SESSION_VALUE, name: "Custom", description: "Create empty named session" },
        ...templates.map((t) => ({
          value: t.name,
          name: t.name,
          description: t.description ?? `${t.sessions.length} session(s)`,
        })),
      ];

      templateLoop: while (true) {
        const templateSelection = await withBack((ctx) =>
          search({
            message: "Select template",
            pageSize,
            source: (term) => {
              if (!term) return templateChoices;
              const lower = term.toLowerCase();
              return templateChoices.filter(
                (c) =>
                  c.name.toLowerCase().includes(lower) ||
                (c.description?.toLowerCase().includes(lower) ?? false),
              );
            },
          }, ctx),
        );
        if (templateSelection === BACK) {
          if (windows.length === 0) process.exit(0);
          continue sessionLoop;
        }

        if (templateSelection === CUSTOM_SESSION_VALUE) {
          const name = await withBack((ctx) =>
            input({
              message: "Session name",
              required: true,
              validate: (value) => {
                if (sessionExists(value)) return `Session "${value}" already exists`;
                return true;
              },
            }, ctx),
          );
          if (name === BACK) {
            continue templateLoop;
          }

          try {
            newSession(name);
          } catch (e) {
            if (e instanceof TmuxError) {
              console.error(`Error: ${e.message}`);
              process.exit(1);
            }
            throw e;
          }
        } else {
          // Apply selected template
          const template = templates.find((t) => t.name === templateSelection);
          if (!template) {
            console.error(`Template "${templateSelection}" not found`);
            process.exit(1);
          }
          try {
            applyTemplate(template);
          } catch (e) {
            if (e instanceof TmuxError) {
              console.error(`Error: ${e.message}`);
              process.exit(1);
            }
            throw e;
          }
        }
        return;
      }
    }

    const sessionWindows = groups.get(sessionSelection);
    if (!sessionWindows) {
      console.error(`Session not found: ${sessionSelection}`);
      process.exit(1);
    }

    // --- Step 2: pick a window (ESC goes back to session picker) ---
    const windowChoices = [
      ...sessionWindows.map((w) => {
        const marker = w.active ? "* " : "  ";
        return {
          name: `${w.target.padEnd(16)} ${marker}${w.windowName.padEnd(20)} ${shortenPath(w.path)}`,
          value: w.target,
        };
      }),
      ...(isInsideTmux() ? [{ name: "+ new window", value: NEW_WINDOW_VALUE }] : []),
    ];

    const windowSelection = await withBack((ctx) =>
      search({
        message: sessionSelection,
        pageSize,
        source: (term) => {
          if (!term) return windowChoices;
          const lower = term.toLowerCase();
          return windowChoices.filter((c) => c.name.toLowerCase().includes(lower));
        },
      }, ctx),
    );
    if (windowSelection === BACK) {
      continue sessionLoop;
    }

    if (windowSelection === NEW_WINDOW_VALUE) {
      const name = await withBack((ctx) => input({ message: "Window name", required: true }, ctx));
      if (name === BACK) {
        continue;
      }

      try {
        newWindow(name);
      } catch (e) {
        if (e instanceof TmuxError) {
          console.error(`Error: ${e.message}`);
          process.exit(1);
        }
        throw e;
      }
      return;
    }

    attachToTarget(windowSelection);
    return;
  }
}

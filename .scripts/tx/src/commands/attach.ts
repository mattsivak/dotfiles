import { spawnSync } from "node:child_process";
import {
  listWindows,
  switchClient,
  attachSession,
  newWindow,
  newSession,
  isInsideTmux,
  type TmuxWindow,
} from "../tmux.ts";

const NEW_WINDOW_LABEL = "+ new window";
const NEW_SESSION_LABEL = "+ new session";

function fzfPick(prompt: string, options: string[]): string | null {
  const result = spawnSync("fzf", ["--prompt", prompt, "--reverse"], {
    input: options.join("\n"),
    encoding: "utf-8",
    stdio: ["pipe", "pipe", "inherit"],
  });

  if (result.status !== 0) return null;
  return result.stdout.trim() || null;
}

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

function pickSession(groups: Map<string, TmuxWindow[]>): string | null {
  const lines: string[] = [NEW_SESSION_LABEL];

  for (const [session, windows] of groups) {
    const windowCount = windows.length;
    const activePath = windows.find((w) => w.active)?.path;
    const display = activePath ? shortenPath(activePath) : "";
    lines.push(`${session.padEnd(20)} ${String(windowCount).padStart(2)} windows   ${display}`);
  }

  return fzfPick("session > ", lines);
}

function pickWindow(session: string, windows: TmuxWindow[]): string | null {
  const lines: string[] = [];

  if (isInsideTmux()) {
    lines.push(NEW_WINDOW_LABEL);
  }

  for (const w of windows) {
    const marker = w.active ? "*" : " ";
    lines.push(
      `${w.target.padEnd(16)} ${marker} ${w.windowName.padEnd(20)} ${shortenPath(w.path)}`
    );
  }

  return fzfPick(`${session} > `, lines);
}

export function attach(): void {
  const windows = listWindows();

  if (windows.length === 0) {
    console.error("No tmux windows found. Is tmux running?");
    process.exit(1);
  }

  const groups = groupBySession(windows);

  // Step 1: pick a session
  const sessionSelection = pickSession(groups);
  if (!sessionSelection) {
    process.exit(0);
  }

  if (sessionSelection === NEW_SESSION_LABEL) {
    newSession();
    return;
  }

  const session = sessionSelection.split(/\s+/)[0];
  const sessionWindows = groups.get(session);

  if (!sessionWindows) {
    console.error(`Session not found: ${session}`);
    process.exit(1);
  }

  // Step 2: pick a window within that session
  const windowSelection = pickWindow(session, sessionWindows);
  if (!windowSelection) {
    process.exit(0);
  }

  if (windowSelection === NEW_WINDOW_LABEL) {
    newWindow();
    return;
  }

  const target = windowSelection.split(/\s+/)[0];

  if (isInsideTmux()) {
    switchClient(target);
  } else {
    attachSession(target);
  }
}

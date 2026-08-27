import { execFileSync } from "node:child_process";

export class TmuxError extends Error {
  constructor(
    message: string,
    public readonly exitCode: number = 1,
  ) {
    super(message);
    this.name = "TmuxError";
  }
}

function tmux(args: string[], opts?: { capture?: boolean }): string {
  try {
    const result = execFileSync("tmux", args, {
      encoding: "utf-8",
      stdio: opts?.capture ? ["pipe", "pipe", "pipe"] : ["inherit", "inherit", "pipe"],
    });
    return result ?? "";
  } catch (err: any) {
    const stderr = (err.stderr ?? "").toString().trim();
    throw new TmuxError(stderr || `tmux ${args[0]} failed`, err.status ?? 1);
  }
}

export interface TmuxWindow {
  /** target for tmux commands, e.g. "main:1" */
  target: string;
  session: string;
  windowIndex: string;
  windowName: string;
  path: string;
  active: boolean;
}

export function listWindows(): TmuxWindow[] {
  const format = [
    "#{session_name}",
    "#{window_index}",
    "#{window_name}",
    "#{pane_current_path}",
    "#{window_active}",
  ].join("\t");

  let raw: string;
  try {
    raw = tmux(["list-windows", "-a", "-F", format], { capture: true });
  } catch {
    return [];
  }

  return raw
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [session, windowIndex, windowName, path, active] = line.split("\t");
      return {
        target: `${session}:${windowIndex}`,
        session,
        windowIndex,
        windowName,
        path,
        active: active === "1",
      };
    });
}

export function switchClient(target: string): void {
  tmux(["switch-client", "-t", target]);
}

export function attachSession(target: string): void {
  tmux(["attach-session", "-t", target]);
}

export function newWindow(name?: string): void {
  const session = tmux(["display-message", "-p", "#{session_name}"], { capture: true }).trim();
  const args = ["new-window", "-d", "-P", "-F", "#{session_name}:#{window_index}", "-t", session];
  if (name) args.push("-n", name);
  const target = tmux(args, { capture: true }).trim();
  switchClient(target);
}

export function newSession(name?: string, dir?: string): void {
  if (isInsideTmux()) {
    const args = ["new-session", "-d"];
    if (name) args.push("-s", name);
    if (dir) args.push("-c", dir);
    tmux(args);
    const target =
      name ??
      tmux(["list-sessions", "-F", "#{session_name}"], { capture: true })
        .trim()
        .split("\n")
        .pop()!;
    switchClient(target);
  } else {
    const args = ["new-session"];
    if (name) args.push("-s", name);
    if (dir) args.push("-c", dir);
    tmux(args);
  }
}

export interface TmuxSession {
  name: string;
  windowCount: number;
  attached: boolean;
  activeWindowName: string;
}

export function listSessions(): TmuxSession[] {
  const format = [
    "#{session_name}",
    "#{session_windows}",
    "#{session_attached}",
    "#{window_name}",
  ].join("\t");

  let raw: string;
  try {
    raw = tmux(["list-sessions", "-F", format], { capture: true });
  } catch {
    return [];
  }

  return raw
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [name, windowCount, attached, activeWindowName] = line.split("\t");
      return {
        name,
        windowCount: parseInt(windowCount, 10),
        attached: attached !== "0",
        activeWindowName,
      };
    });
}

export function currentSession(): string | null {
  if (!isInsideTmux()) return null;
  try {
    return tmux(["display-message", "-p", "#{session_name}"], { capture: true }).trim();
  } catch {
    return null;
  }
}

export function killSession(name: string): void {
  tmux(["kill-session", "-t", name]);
}

export function renameSession(target: string, newName: string): void {
  tmux(["rename-session", "-t", target, newName]);
}

export function sessionExists(name: string): boolean {
  try {
    tmux(["has-session", "-t", name], { capture: true });
    return true;
  } catch {
    return false;
  }
}

export function isInsideTmux(): boolean {
  return "TMUX" in process.env;
}

/**
 * Create a new detached session with optional starting directory
 */
export function newSessionDetached(name: string, dir?: string): void {
  const args = ["new-session", "-d", "-s", name];
  if (dir) args.push("-c", dir);
  tmux(args);
}

/**
 * Create a new window in a specific session
 */
export function newWindowInSession(session: string, name?: string, dir?: string): void {
  const args = ["new-window", "-t", session];
  if (name) args.push("-n", name);
  if (dir) args.push("-c", dir);
  tmux(args);
}

/**
 * Send keys to a target (session:window)
 */
export function sendKeys(target: string, keys: string, literal: boolean = false): void {
  const args = ["send-keys", "-t", target];
  if (literal) args.push("-l");
  args.push(keys);
  // Add Enter key to execute commands (unless it's a control sequence)
  if (!keys.startsWith("C-") && !literal) {
    args.push("C-m");
  }
  tmux(args);
}

/**
 * Rename a window
 */
export function renameWindow(session: string, windowIndex: string, name: string): void {
  tmux(["rename-window", "-t", `${session}:${windowIndex}`, name]);
}

/**
 * Kill the entire tmux server (all sessions)
 */
export function killServer(): void {
  tmux(["kill-server"]);
}

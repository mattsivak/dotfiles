import { execFileSync } from "node:child_process";

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
    raw = execFileSync("tmux", ["list-windows", "-a", "-F", format], {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
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
  execFileSync("tmux", ["switch-client", "-t", target], {
    stdio: "inherit",
  });
}

export function attachSession(target: string): void {
  execFileSync("tmux", ["attach-session", "-t", target], {
    stdio: "inherit",
  });
}

export function newWindow(): void {
  execFileSync("tmux", ["new-window"], { stdio: "inherit" });
}

export function newSession(name?: string): void {
  const args = ["new-session"];
  if (isInsideTmux()) args.push("-d");
  if (name) args.push("-s", name);
  execFileSync("tmux", args, { stdio: "inherit" });
}

export interface TmuxSession {
  name: string;
  windowCount: number;
  attached: boolean;
}

export function listSessions(): TmuxSession[] {
  const format = ["#{session_name}", "#{session_windows}", "#{session_attached}"].join("\t");

  let raw: string;
  try {
    raw = execFileSync("tmux", ["list-sessions", "-F", format], {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
  } catch {
    return [];
  }

  return raw
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [name, windowCount, attached] = line.split("\t");
      return {
        name,
        windowCount: parseInt(windowCount, 10),
        attached: attached !== "0",
      };
    });
}

export function currentSession(): string | null {
  if (!isInsideTmux()) return null;
  try {
    return execFileSync("tmux", ["display-message", "-p", "#{session_name}"], {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
  } catch {
    return null;
  }
}

export function killSession(name: string): void {
  execFileSync("tmux", ["kill-session", "-t", name], { stdio: "inherit" });
}

export function isInsideTmux(): boolean {
  return "TMUX" in process.env;
}

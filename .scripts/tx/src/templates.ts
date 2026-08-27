import { parse, stringify } from "yaml";
import { readFileSync, writeFileSync, readdirSync, unlinkSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import {
  sessionExists,
  renameSession,
  newSessionDetached,
  newWindowInSession,
  sendKeys,
  switchClient,
  attachSession,
  isInsideTmux,
  renameWindow,
  listWindows,
} from "./tmux.ts";

export interface TemplateWindow {
  name?: string;
  cmd?: string;
}

export interface TemplateSession {
  name: string;
  dir?: string;
  windows: TemplateWindow[];
}

export interface Template {
  name: string;
  description?: string;
  sessions: TemplateSession[];
  attach?: string; // target to attach to after creation (e.g. "session", "session:windowName", "session:2")
}

export function getTemplatesDir(): string {
  const dir = join(homedir(), ".config", "tx", "templates");
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  return dir;
}

export function getTemplatePath(name: string): string {
  return join(getTemplatesDir(), `${name}.yaml`);
}

export function loadTemplates(): Template[] {
  const dir = getTemplatesDir();
  const files = readdirSync(dir).filter((f) => f.endsWith(".yaml"));
  return files
    .map((f) => {
      try {
        const content = readFileSync(join(dir, f), "utf-8");
        return parse(content) as Template;
      } catch {
        return null;
      }
    })
    .filter((t): t is Template => t !== null);
}

export function loadTemplate(name: string): Template | null {
  const path = getTemplatePath(name);
  if (!existsSync(path)) return null;
  try {
    const content = readFileSync(path, "utf-8");
    return parse(content) as Template;
  } catch {
    return null;
  }
}

export function saveTemplate(template: Template): void {
  const path = getTemplatePath(template.name);
  writeFileSync(path, stringify(template), "utf-8");
}

export function deleteTemplate(name: string): boolean {
  const path = getTemplatePath(name);
  if (!existsSync(path)) return false;
  unlinkSync(path);
  return true;
}

export function templateExists(name: string): boolean {
  return existsSync(getTemplatePath(name));
}

/**
 * Find the next available suffix for a session name.
 * If "foo" exists, returns "foo-1". If "foo-1" exists, returns "foo-2", etc.
 */
function findNextSuffix(baseName: string): string {
  let suffix = 1;
  while (sessionExists(`${baseName}-${suffix}`)) {
    suffix++;
  }
  return `${baseName}-${suffix}`;
}

/**
 * Resolve session name conflicts by renaming existing sessions.
 * Returns the name to use for the new session (always the original name).
 */
function resolveSessionName(name: string): string {
  if (sessionExists(name)) {
    const newName = findNextSuffix(name);
    renameSession(name, newName);
    console.log(`Renamed existing session "${name}" to "${newName}"`);
  }
  return name;
}

/**
 * Expand ~ to home directory in paths
 */
function expandPath(path: string): string {
  if (path.startsWith("~/")) {
    return join(homedir(), path.slice(2));
  }
  return path;
}

/**
 * Apply a template - create all sessions and windows
 */
export function applyTemplate(template: Template): void {
  const createdSessions: string[] = [];

  for (const session of template.sessions) {
    const sessionName = resolveSessionName(session.name);
    const dir = session.dir ? expandPath(session.dir) : undefined;

    // Create the session (detached)
    newSessionDetached(sessionName, dir);
    createdSessions.push(sessionName);

    // First window is created with the session, send command if specified
    const firstWindow = session.windows[0];
    if (firstWindow) {
      if (firstWindow.name) {
        renameWindow(sessionName, "1", firstWindow.name);
      }
      if (firstWindow.cmd) {
        sendKeys(`${sessionName}:1`, firstWindow.cmd);
      }
    }

    // Create additional windows
    for (let i = 1; i < session.windows.length; i++) {
      const win = session.windows[i];
      const windowIndex = i + 1;
      newWindowInSession(sessionName, win.name, dir);
      if (win.cmd) {
        sendKeys(`${sessionName}:${windowIndex}`, win.cmd);
      }
    }
  }

  // Resolve the attach target (supports "session", "session:windowName", "session:windowIndex")
  const attachTarget = resolveAttachTarget(template.attach, createdSessions);
  if (attachTarget) {
    if (isInsideTmux()) {
      switchClient(attachTarget);
    } else {
      attachSession(attachTarget);
    }
  }

  console.log(`Created ${createdSessions.length} session(s) from template "${template.name}"`);
}

/**
 * Resolve an attach target string to a valid tmux target.
 * Supports:
 *   - "session"              -> attaches to session
 *   - "session:windowName"   -> finds window by name, falls back to index
 *   - "session:windowIndex"  -> attaches to session:index
 * If no attach is specified, defaults to the first created session.
 */
function resolveAttachTarget(attach: string | undefined, createdSessions: string[]): string | undefined {
  const raw = attach ?? createdSessions[0];
  if (!raw) return undefined;

  const colonIdx = raw.indexOf(":");
  if (colonIdx === -1) {
    // Session only
    return raw;
  }

  const sessionName = raw.slice(0, colonIdx);
  const windowPart = raw.slice(colonIdx + 1);

  // Try to find the window by name first
  const windows = listWindows().filter((w) => w.session === sessionName);
  const byName = windows.find((w) => w.windowName === windowPart);
  if (byName) {
    return byName.target;
  }

  // Fall back to treating it as an index
  const byIndex = windows.find((w) => w.windowIndex === windowPart);
  if (byIndex) {
    return byIndex.target;
  }

  // If neither matched, return the raw string and let tmux handle it
  return raw;
}

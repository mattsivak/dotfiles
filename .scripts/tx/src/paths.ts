import { homedir } from "node:os";
import { join, resolve } from "node:path";

/**
 * Expand ~ to the home directory and resolve to an absolute path.
 */
export function expandPath(path: string): string {
  let p = path.trim();
  if (p === "~") p = homedir();
  else if (p.startsWith("~/")) p = join(homedir(), p.slice(2));
  // resolve() also normalizes away trailing slashes and "..".
  return resolve(p);
}

/**
 * tmux treats "." and ":" as target separators, so they can't appear in a
 * session name. Squash them (and whitespace) into dashes.
 */
export function sanitizeSessionName(name: string): string {
  return name
    .trim()
    .replace(/[.:\s]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

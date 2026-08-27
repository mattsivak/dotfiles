import search from "@inquirer/search";
import { execFileSync } from "node:child_process";
import { statSync } from "node:fs";
import { homedir } from "node:os";
import { expandPath } from "./paths.ts";
import { fitWidth, pickerPageSize } from "./layout.ts";
import { PromptResult, withBack } from "./prompts.ts";

/**
 * Directories that are never worth walking into.
 */
const EXCLUDES = [
  ".git",
  "node_modules",
  ".cache",
  ".npm",
  ".nvm",
  ".cargo",
  ".rustup",
  ".bun",
  ".gnupg",
  ".password-store",
  ".venv",
  "venv",
  "__pycache__",
  "target",
  "dist",
  "build",
  ".next",
  "Library",
];

/** Roots to walk, colon-separated. Defaults to $HOME. */
function roots(): string[] {
  const raw = process.env.TX_DIR_ROOTS;
  const list = raw ? raw.split(":").filter(Boolean) : [homedir()];
  return list.map(expandPath).filter((d) => isDir(d));
}

function maxDepth(): number {
  const n = parseInt(process.env.TX_DIR_DEPTH ?? "", 10);
  return Number.isFinite(n) && n > 0 ? n : 4;
}

function isDir(path: string): boolean {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

function run(cmd: string, args: string[]): string[] {
  try {
    const out = execFileSync(cmd, args, {
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 10_000,
      maxBuffer: 64 * 1024 * 1024,
    });
    return out.split("\n").filter(Boolean);
  } catch {
    return [];
  }
}

function which(cmd: string): boolean {
  try {
    execFileSync("/bin/sh", ["-c", `command -v ${cmd}`], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

/** Directories ranked by zoxide frecency — instant, no filesystem walk. */
function zoxideDirs(): string[] {
  if (!which("zoxide")) return [];
  return run("zoxide", ["query", "--list"]).map((d) => d.replace(/\/+$/, ""));
}

/** Shallow paths first, then alphabetical — so the unfiltered list is useful. */
function byDepthThenName(a: string, b: string): number {
  const da = a.split("/").length;
  const db = b.split("/").length;
  return da !== db ? da - db : a.localeCompare(b);
}

/** Every directory under the configured roots, via fd (or find as a fallback). */
function walkedDirs(): string[] {
  const bin = which("fd") ? "fd" : which("fdfind") ? "fdfind" : null;
  const out: string[] = [];

  for (const root of roots()) {
    if (bin) {
      const args = ["--type", "d", "--hidden", "--max-depth", String(maxDepth())];
      for (const e of EXCLUDES) args.push("--exclude", e);
      args.push(".", root);
      out.push(...run(bin, args));
    } else {
      const args = [root, "-maxdepth", String(maxDepth()), "-type", "d"];
      for (const e of EXCLUDES) args.push("-not", "-path", `*/${e}/*`, "-not", "-name", e);
      out.push(...run("find", args));
    }
  }

  return out.map((d) => d.replace(/\/+$/, "")).sort(byDepthThenName);
}

let cache: string[] | null = null;

/** Candidate directories: zoxide frecency first, then the walked roots. */
export function candidateDirs(): string[] {
  if (cache) return cache;
  const seen = new Set<string>();
  const list: string[] = [];
  for (const dir of [...zoxideDirs(), ...walkedDirs()]) {
    if (!dir || seen.has(dir)) continue;
    seen.add(dir);
    list.push(dir);
  }
  cache = list;
  return list;
}

/**
 * Fuzzy subsequence score. Higher is better; null means no match.
 * Rewards consecutive hits, word boundaries, and matches in the basename.
 */
export function fuzzyScore(text: string, term: string): number | null {
  const hay = text.toLowerCase();
  const needle = term.toLowerCase().replace(/\s+/g, "");
  if (!needle) return 0;

  const baseStart = hay.lastIndexOf("/") + 1;
  let score = 0;
  let ti = 0;
  let prev = -1;

  for (const ch of needle) {
    const idx = hay.indexOf(ch, ti);
    if (idx === -1) return null;
    if (idx === prev + 1) score += 8; // consecutive
    if (idx === 0 || hay[idx - 1] === "/" || hay[idx - 1] === "-" || hay[idx - 1] === "_") {
      score += 6; // word boundary
    }
    if (idx >= baseStart) score += 4; // in the last path segment
    prev = idx;
    ti = idx + 1;
  }

  // Prefer shorter, shallower paths when scores are otherwise close.
  score -= hay.length * 0.05;
  score -= (hay.split("/").length - 1) * 0.5;
  return score;
}

function homeRelative(path: string): string {
  const home = homedir();
  return path === home ? "~" : path.startsWith(home + "/") ? `~${path.slice(home.length)}` : path;
}

interface DirChoice {
  value: string;
  name: string;
  description?: string;
}

function toChoice(dir: string, description?: string): DirChoice {
  // Truncated so a deep path can't wrap onto a second row and break paging.
  return { value: dir, name: fitWidth(homeRelative(dir)), description };
}

/**
 * Fuzzy-search picker over directories. ESC returns BACK.
 *
 * Typing a path that exists but isn't in the index (or is outside the walked
 * roots) always offers itself as the top result.
 */
export async function promptForDir(
  message = "Start directory",
  pageSize: number = pickerPageSize(),
): Promise<PromptResult<string>> {
  const cwd = process.cwd();

  return withBack((ctx) =>
    search<string>(
      {
        message,
        source: (term) => {
          const typed = (term ?? "").trim();

          if (!typed) {
            const defaults: DirChoice[] = [toChoice(cwd, "current directory")];
            const seen = new Set([cwd]);
            for (const dir of candidateDirs()) {
              if (seen.has(dir)) continue;
              seen.add(dir);
              defaults.push(toChoice(dir));
              if (defaults.length >= 200) break;
            }
            return defaults;
          }

          const results: DirChoice[] = [];
          const seen = new Set<string>();

          // A literal path the user typed wins the top slot.
          const literal = expandPath(typed);
          if (isDir(literal)) {
            results.push(toChoice(literal, "as typed"));
            seen.add(literal);
          }

          const scored = candidateDirs()
            .filter((d) => !seen.has(d))
            .map((d) => ({ dir: d, score: fuzzyScore(homeRelative(d), typed) }))
            .filter((r): r is { dir: string; score: number } => r.score !== null)
            .sort((a, b) => b.score - a.score)
            .slice(0, 200);

          for (const { dir } of scored) results.push(toChoice(dir));
          return results;
        },
        pageSize,
      },
      ctx,
    ),
  );
}

import { pickerPageSize } from "./layout.ts";

/**
 * Parse common CLI flags shared across commands.
 *
 * --max-rows=N   Limit the number of visible rows in interactive pickers.
 *               Defaults to the terminal height minus the prompt/help chrome,
 *               so the search input always stays on screen.
 *
 * Any non-flag argument (not starting with --) is treated as a positional arg.
 */
export function parseArgs(args: string[]): { pageSize: number; positional: string[] } {
  let pageSize = pickerPageSize();
  const positional: string[] = [];

  for (const arg of args) {
    const m = arg.match(/^--max-rows=(\d+)$/);
    if (m) {
      pageSize = Math.max(1, parseInt(m[1], 10));
    } else if (!arg.startsWith("--")) {
      positional.push(arg);
    }
  }

  return { pageSize, positional };
}

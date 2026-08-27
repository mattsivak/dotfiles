/**
 * Parse common CLI flags shared across commands.
 *
 * --max-rows=N   Limit the number of visible rows in interactive pickers.
 *               Defaults to the full terminal height.
 *
 * Any non-flag argument (not starting with --) is treated as a positional arg.
 */
export function parseArgs(args: string[]): { pageSize: number; positional: string[] } {
  let pageSize = process.stdout.rows ?? 24;
  const positional: string[] = [];

  for (const arg of args) {
    const m = arg.match(/^--max-rows=(\d+)$/);
    if (m) {
      pageSize = parseInt(m[1], 10);
    } else if (!arg.startsWith("--")) {
      positional.push(arg);
    }
  }

  return { pageSize, positional };
}

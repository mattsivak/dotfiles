/**
 * Terminal sizing for interactive pickers.
 *
 * Inquirer renders a picker as: the prompt/input line, the choice list, an
 * optional description line for the highlighted choice, and a help line. Giving
 * it a pageSize of the full terminal height makes that chrome overflow, which
 * scrolls the input line off the top of the screen. Always leave room for it.
 */

/** Lines a picker needs besides its choice list: prompt + description + help. */
const CHROME_ROWS = 4;

/** Never shrink a list below this, even in a tiny window. */
const MIN_PAGE_SIZE = 3;

export function terminalRows(): number {
  return process.stdout.rows || 24;
}

export function terminalColumns(): number {
  return process.stdout.columns || 80;
}

/**
 * How many choice rows a picker may draw without pushing its input off-screen.
 */
export function pickerPageSize(reserved: number = CHROME_ROWS): number {
  return Math.max(MIN_PAGE_SIZE, terminalRows() - reserved);
}

/**
 * Truncate to the terminal width so a long entry can't wrap onto a second row
 * and throw the page size off. Keeps the tail, which is the telling part of a
 * path, and marks the cut with a leading ellipsis.
 */
export function fitWidth(text: string, reserved: number = 4): string {
  const max = Math.max(10, terminalColumns() - reserved);
  if (text.length <= max) return text;
  return "…" + text.slice(text.length - (max - 1));
}

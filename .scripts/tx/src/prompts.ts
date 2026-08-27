import { ExitPromptError, AbortPromptError } from "@inquirer/core";
import type { Context } from "@inquirer/type";

export const BACK = Symbol("prompt-back");

export type PromptResult<T> = T | typeof BACK;

export async function withBack<T>(
  prompt: (context: Context) => Promise<T>,
): Promise<PromptResult<T>> {
  const ac = new AbortController();

  // Inquirer already puts stdin in raw mode and emits keypress events.
  // Listen for the raw ESC byte (\x1b) to abort the prompt.
  const onData = (data: Buffer) => {
    if (data.length === 1 && data[0] === 0x1b) {
      ac.abort();
    }
  };
  process.stdin.on("data", onData);

  try {
    return await prompt({ signal: ac.signal });
  } catch (e) {
    if (e instanceof AbortPromptError || e instanceof ExitPromptError) return BACK;
    throw e;
  } finally {
    process.stdin.removeListener("data", onData);
  }
}

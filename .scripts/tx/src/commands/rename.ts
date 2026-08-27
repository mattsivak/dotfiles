import input from "@inquirer/input";
import { currentSession, renameSession, TmuxError } from "../tmux.ts";
import { BACK, withBack } from "../prompts.ts";

export async function rename(args: string[]): Promise<void> {
  let target: string;
  let newName: string;

  if (args.length >= 2) {
    target = args[0];
    newName = args[1];
  } else if (args.length === 1) {
    const current = currentSession();
    if (!current) {
      console.error("Not inside a tmux session. Specify the session: tx rename <session> <new-name>");
      process.exit(1);
    }
    target = current;
    newName = args[0];
  } else {
    const current = currentSession();
    if (!current) {
      console.error("Not inside a tmux session. Specify the session: tx rename <session> <new-name>");
      process.exit(1);
    }
    target = current;
    const result = await withBack((ctx) => input({ message: `Rename "${target}" to`, required: true }, ctx));
    if (result === BACK) {
      process.exit(0);
    }
    newName = result;
  }

  try {
    renameSession(target, newName!);
  } catch (e) {
    if (e instanceof TmuxError) {
      console.error(`Error: ${e.message}`);
      process.exit(1);
    }
    throw e;
  }

  console.log(`Renamed ${target} → ${newName!}`);
}

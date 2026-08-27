import { attach } from "./commands/attach.ts";
import { exit } from "./commands/exit.ts";
import { list } from "./commands/list.ts";
import { newCmd } from "./commands/new.ts";
import { rename } from "./commands/rename.ts";
import { stop } from "./commands/stop.ts";
import { templateCmd } from "./commands/template.ts";

const COMMANDS: Record<string, { desc: string; fn: (args: string[]) => void | Promise<void> }> = {
  attach: {
    desc: "Attach to a session/window: tx attach [target]",
    fn: attach,
  },
  exit: {
    desc: "Kill tmux sessions (multi-select): tx exit [name...]",
    fn: exit,
  },
  list: {
    desc: "List all tmux sessions",
    fn: list,
  },
  new: {
    desc: "Create a new session: tx new [name] [-t template] [--dir] [--name]",
    fn: newCmd,
  },
  rename: {
    desc: "Rename a session: tx rename [session] <new-name>",
    fn: rename,
  },
  stop: {
    desc: "Stop tmux server (kill all sessions)",
    fn: stop,
  },
  template: {
    desc: "Manage templates: tx template <list|show|edit|create|delete>",
    fn: templateCmd,
  },
};

function usage(): void {
  console.log("tx — tmux utility toolkit\n");
  console.log("Usage: tx <command>\n");
  console.log("Commands:");
  for (const [name, cmd] of Object.entries(COMMANDS)) {
    console.log(`  ${name.padEnd(12)} ${cmd.desc}`);
  }
  console.log("\nFlags for tx new:");
  console.log("  -t, --template=NAME  Apply a template without the picker");
  console.log("  -d, --dir            Pick a start directory (fuzzy folder search)");
  console.log("      --dir=PATH       Use PATH as the start directory, skipping the picker");
  console.log("  -n, --name           Ask what to call the session");
  console.log("      --name=NAME      Use NAME for the session, skipping the prompt");
}

export async function run(args: string[]): Promise<void> {
  const command = args[0];

  if (!command || command === "--help" || command === "-h") {
    usage();
    process.exit(0);
  }

  const cmd = COMMANDS[command];
  if (!cmd) {
    console.error(`Unknown command: ${command}\n`);
    usage();
    process.exit(1);
  }

  await cmd.fn(args.slice(1));
}

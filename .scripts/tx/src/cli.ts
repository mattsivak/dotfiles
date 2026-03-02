import { attach } from "./commands/attach.ts";
import { exit } from "./commands/exit.ts";

const COMMANDS: Record<string, { desc: string; fn: () => void }> = {
  attach: {
    desc: "Pick a tmux window to switch to, or create a new one",
    fn: attach,
  },
  exit: {
    desc: "Pick a tmux session to kill",
    fn: exit,
  },
};

function usage(): void {
  console.log("tx — tmux utility toolkit\n");
  console.log("Usage: tx <command>\n");
  console.log("Commands:");
  for (const [name, cmd] of Object.entries(COMMANDS)) {
    console.log(`  ${name.padEnd(12)} ${cmd.desc}`);
  }
}

export function run(args: string[]): void {
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

  cmd.fn();
}

import input from "@inquirer/input";
import search from "@inquirer/search";
import { newSession, sessionExists, TmuxError } from "../tmux.ts";
import { loadTemplates, loadTemplate, Template } from "../templates.ts";
import { BACK, withBack } from "../prompts.ts";
import { promptForDir } from "../dirpicker.ts";
import { expandPath } from "../paths.ts";
import { runTemplate } from "../templateflow.ts";
import { pickerPageSize } from "../layout.ts";

const CUSTOM_CHOICE = "__custom__";

interface NewOptions {
  /** Explicit start directory (--dir=PATH); skips the picker. */
  dir?: string;
  /** Force the directory picker even if the template doesn't opt in (--dir). */
  askDir: boolean;
  /** Explicit session name (--name=NAME); skips the name prompt. */
  name?: string;
  /** Force the name prompt even if the template doesn't opt in (--name). */
  askName: boolean;
  /** Apply this template directly (-t NAME / --template=NAME). */
  template?: string;
  positional: string[];
}

function parseOptions(args: string[]): NewOptions {
  const opts: NewOptions = { askDir: false, askName: false, positional: [] };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    let m: RegExpMatchArray | null;

    if ((m = arg.match(/^--dir=(.+)$/))) opts.dir = m[1];
    else if (arg === "--dir" || arg === "-d") opts.askDir = true;
    else if ((m = arg.match(/^--name=(.+)$/))) opts.name = m[1];
    else if (arg === "--name" || arg === "-n") opts.askName = true;
    else if ((m = arg.match(/^--template=(.+)$/))) opts.template = m[1];
    else if (arg === "--template" || arg === "-t") opts.template = args[++i];
    else if (!arg.startsWith("-")) opts.positional.push(arg);
  }

  return opts;
}

/**
 * For custom (template-less) sessions, --dir / -d opens the same picker.
 * Returns undefined when the flags weren't used, BACK on ESC.
 */
async function resolveCustomDir(opts: NewOptions): Promise<string | undefined | typeof BACK> {
  if (opts.dir) return expandPath(opts.dir);
  if (!opts.askDir) return undefined;

  const picked = await promptForDir("Start directory");
  if (picked === BACK) return BACK;
  return picked;
}

export async function newCmd(rawArgs: string[]): Promise<void> {
  const opts = parseOptions(rawArgs);

  // Direct template application: tx new -t dev [--dir=~/code/proj]
  if (opts.template) {
    const template = loadTemplate(opts.template);
    if (!template) {
      console.error(`Template "${opts.template}" not found`);
      process.exit(1);
    }
    if (!(await runTemplate(template, opts))) process.exit(0);
    return;
  }

  const args = opts.positional;

  // If a name is provided directly, create custom session with that name
  if (args[0]) {
    const name = args[0];
    if (sessionExists(name)) {
      console.error(`Session "${name}" already exists`);
      process.exit(1);
    }
    const dir = await resolveCustomDir(opts);
    if (dir === BACK) process.exit(0);

    try {
      newSession(name, dir);
    } catch (e) {
      if (e instanceof TmuxError) {
        console.error(`Error: ${e.message}`);
        process.exit(1);
      }
      throw e;
    }
    return;
  }

  // Load available templates
  const templates = loadTemplates();

  // If no templates exist, go straight to custom session creation
  if (templates.length === 0) {
    const name = await withBack((ctx) =>
      input({
        message: "Session name",
        required: true,
        validate: (value) => {
          if (sessionExists(value)) return `Session "${value}" already exists`;
          return true;
        },
      }, ctx),
    );
    if (name === BACK) {
      process.exit(0);
    }

    const dir = await resolveCustomDir(opts);
    if (dir === BACK) process.exit(0);

    try {
      newSession(name, dir);
    } catch (e) {
      if (e instanceof TmuxError) {
        console.error(`Error: ${e.message}`);
        process.exit(1);
      }
      throw e;
    }
    return;
  }

  // Build choices: Custom first, then templates
  interface Choice {
    value: string;
    name: string;
    description?: string;
  }

  const choices: Choice[] = [
    { value: CUSTOM_CHOICE, name: "Custom", description: "Create empty named session" },
    ...templates.map((t) => ({
      value: t.name,
      name: t.name,
      description: t.description ?? `${t.sessions.length} session(s)`,
    })),
  ];

  // Main loop: ESC at sub-steps goes back to template picker
  while (true) {
    const selected = await withBack((ctx) =>
      search({
        message: "Select template",
        source: (term) => {
          if (!term) return choices;
          const lower = term.toLowerCase();
          return choices.filter(
            (c) =>
              c.name.toLowerCase().includes(lower) ||
              (c.description?.toLowerCase().includes(lower) ?? false),
          );
        },
        pageSize: pickerPageSize(),
      }, ctx),
    );
    if (selected === BACK) {
      process.exit(0);
    }

    if (selected === CUSTOM_CHOICE) {
      const name = await withBack((ctx) =>
        input({
          message: "Session name",
          required: true,
          validate: (value) => {
            if (sessionExists(value)) return `Session "${value}" already exists`;
            return true;
          },
        }, ctx),
      );
      if (name === BACK) {
        continue;
      }

      const dir = await resolveCustomDir(opts);
      if (dir === BACK) continue;

      try {
        newSession(name, dir);
      } catch (e) {
        if (e instanceof TmuxError) {
          console.error(`Error: ${e.message}`);
          process.exit(1);
        }
        throw e;
      }
      return;
    }

    // Find and apply the selected template
    const template = templates.find((t) => t.name === selected);
    if (!template) {
      console.error(`Template "${selected}" not found`);
      process.exit(1);
    }

    // Opt-in steps: templates with promptDir / promptName ask where to start
    // and what to call the session. ESC returns to the template list.
    if (!(await runTemplate(template, opts))) continue;
    return;
  }
}

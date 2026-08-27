import input from "@inquirer/input";
import search from "@inquirer/search";
import { newSession, sessionExists, TmuxError } from "../tmux.ts";
import { loadTemplates, applyTemplate, Template } from "../templates.ts";
import { BACK, withBack } from "../prompts.ts";

const CUSTOM_CHOICE = "__custom__";

export async function newCmd(args: string[]): Promise<void> {
  // If a name is provided directly, create custom session with that name
  if (args[0]) {
    const name = args[0];
    if (sessionExists(name)) {
      console.error(`Session "${name}" already exists`);
      process.exit(1);
    }
    try {
      newSession(name);
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

    try {
      newSession(name);
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
        pageSize: process.stdout.rows,
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

      try {
        newSession(name);
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

    try {
      applyTemplate(template);
    } catch (e) {
      if (e instanceof TmuxError) {
        console.error(`Error: ${e.message}`);
        process.exit(1);
      }
      throw e;
    }
    return;
  }
}

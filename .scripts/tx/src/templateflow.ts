import input from "@inquirer/input";
import { applyTemplate, defaultSessionName, Template } from "./templates.ts";
import { promptForDir } from "./dirpicker.ts";
import { sessionExists, TmuxError } from "./tmux.ts";
import { BACK, withBack } from "./prompts.ts";

/**
 * Per-run answers a template can opt into asking for.
 * Shared by `tx new` and the "+ new session" flow in `tx attach`.
 */
export interface TemplateRunOptions {
  /** Explicit start directory; skips the picker. */
  dir?: string;
  /** Force the directory picker even if the template doesn't opt in. */
  askDir?: boolean;
  /** Explicit session name; skips the prompt. */
  name?: string;
  /** Force the name prompt even if the template doesn't opt in. */
  askName?: boolean;
  /** Rows available to the picker. */
  pageSize?: number;
}

export interface TemplateInputs {
  dir?: string;
  name?: string;
}

/**
 * Collect the answers a template opts into:
 *
 *   promptDir  -> "Where should it start?"    (fuzzy folder search)
 *   promptName -> "Session name"              (pre-filled from that folder)
 *
 * The directory is asked first so the name can default to its basename — just
 * press enter to accept. ESC on the name goes back to the folder picker; ESC on
 * the folder picker (or on the name when it's the only step) returns BACK so
 * the caller can return to its own picker.
 */
export async function promptTemplateInputs(
  template: Template,
  opts: TemplateRunOptions = {},
): Promise<TemplateInputs | typeof BACK> {
  const wantsDir = !opts.dir && (template.promptDir || opts.askDir);
  const wantsName = !opts.name && (template.promptName || opts.askName);

  let dir = opts.dir;

  while (true) {
    if (wantsDir) {
      const picked = await promptForDir(
        `Where should "${template.name}" start?`,
        opts.pageSize,
      );
      if (picked === BACK) return BACK;
      dir = picked;
    }

    if (!wantsName) return { dir, name: opts.name };

    const suggested = defaultSessionName(template, dir);
    const answer = await withBack((ctx) =>
      input(
        {
          message: "Session name",
          default: suggested,
          required: true,
          validate: (value) =>
            value.trim().length > 0 ? true : "Session name cannot be empty",
        },
        ctx,
      ),
    );

    // ESC on the name step re-opens the folder picker when there is one,
    // otherwise it bubbles back to the caller's picker.
    if (answer === BACK) {
      if (wantsDir) continue;
      return BACK;
    }

    if (sessionExists(answer.trim())) {
      console.log(`Note: session "${answer.trim()}" exists — it will be renamed aside.`);
    }

    return { dir, name: answer.trim() };
  }
}

/** Apply a template, reporting tmux errors as a clean exit. */
export function applyWithInputs(template: Template, inputs: TemplateInputs): void {
  try {
    applyTemplate(template, inputs.dir, inputs.name);
  } catch (e) {
    if (e instanceof TmuxError) {
      console.error(`Error: ${e.message}`);
      process.exit(1);
    }
    throw e;
  }
}

/**
 * Prompt for whatever the template asks for, then apply it.
 * Returns false if the user backed out, so callers can return to their picker.
 */
export async function runTemplate(
  template: Template,
  opts: TemplateRunOptions = {},
): Promise<boolean> {
  const inputs = await promptTemplateInputs(template, opts);
  if (inputs === BACK) return false;
  applyWithInputs(template, inputs);
  return true;
}

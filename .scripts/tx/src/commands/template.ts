import input from "@inquirer/input";
import search from "@inquirer/search";
import select from "@inquirer/select";
import confirm from "@inquirer/confirm";
import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { stringify } from "yaml";
import {
  loadTemplates,
  loadTemplate,
  saveTemplate,
  deleteTemplate,
  templateExists,
  getTemplatePath,
  getTemplatesDir,
  Template,
  TemplateSession,
  TemplateWindow,
} from "../templates.ts";
import { BACK, withBack } from "../prompts.ts";
import { pickerPageSize } from "../layout.ts";

function showHelp(): void {
  console.log(`tx template <subcommand>

Subcommands:
  list              List all available templates
  show <name>       Display template contents
  edit <name>       Open template in $EDITOR
  create            Interactive template creator
  delete <name>     Delete a template`);
}

async function listCmd(): Promise<void> {
  const templates = loadTemplates();
  if (templates.length === 0) {
    console.log("No templates found.");
    console.log(`Templates directory: ${getTemplatesDir()}`);
    return;
  }

  console.log("Available templates:\n");
  for (const t of templates) {
    const sessionCount = t.sessions.length;
    const desc = t.description ? ` - ${t.description}` : "";
    console.log(`  ${t.name}${desc} (${sessionCount} session${sessionCount !== 1 ? "s" : ""})`);
  }
}

async function showCmd(args: string[]): Promise<void> {
  let name = args[0];

  if (!name) {
    const templates = loadTemplates();
    if (templates.length === 0) {
      console.log("No templates found.");
      return;
    }

    const result = await withBack((ctx) =>
      search({
        message: "Select template to show",
        source: (term) => {
          const choices = templates.map((t) => ({
            value: t.name,
            name: t.name,
            description: t.description,
          }));
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
    if (result === BACK) {
      process.exit(0);
    }
    name = result;
  }

  const path = getTemplatePath(name);
  try {
    const content = readFileSync(path, "utf-8");
    console.log(content);
  } catch {
    console.error(`Template "${name}" not found`);
    process.exit(1);
  }
}

async function editCmd(args: string[]): Promise<void> {
  let name = args[0];

  if (!name) {
    const templates = loadTemplates();
    if (templates.length === 0) {
      console.log("No templates found. Use 'tx template create' to create one.");
      return;
    }

    const result = await withBack((ctx) =>
      search({
        message: "Select template to edit",
        source: (term) => {
          const choices = templates.map((t) => ({
            value: t.name,
            name: t.name,
            description: t.description,
          }));
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
    if (result === BACK) {
      process.exit(0);
    }
    name = result;
  }

  const path = getTemplatePath(name);
  if (!templateExists(name)) {
    console.error(`Template "${name}" not found`);
    process.exit(1);
  }

  const editor = process.env.EDITOR || "vim";
  spawnSync(editor, [path], { stdio: "inherit" });
}

async function createCmd(): Promise<void> {
  let name = "";
  let description = "";
  let promptDir = false;
  let promptName = false;
  const sessions: TemplateSession[] = [];

  type Step = "name" | "description" | "promptDir" | "promptName" | "sessionName" | "sessionDir" | "windowName" | "windowCmd" | "addWindow" | "addSession" | "done";
  let step: Step = "name";

  let sessionName = "";
  let sessionDir = "";
  let windows: TemplateWindow[] = [];
  let windowName = "";
  let windowCmd = "";

  while (step !== "done") {
    switch (step) {
      case "name": {
        const result = await withBack((ctx) =>
          input({
            message: "Template name",
            required: true,
            validate: (value) => {
              if (templateExists(value)) return `Template "${value}" already exists`;
              if (!/^[a-zA-Z0-9_-]+$/.test(value)) return "Name can only contain letters, numbers, dashes, and underscores";
              return true;
            },
          }, ctx),
        );
        if (result === BACK) process.exit(0);
        name = result;
        step = "description";
        break;
      }

      case "description": {
        const result = await withBack((ctx) =>
          input({ message: "Description (optional)" }, ctx),
        );
        if (result === BACK) { step = "name"; break; }
        description = result;
        step = "promptDir";
        break;
      }

      case "promptDir": {
        console.log("\n  Optional: ask for a start directory (fuzzy folder search) each time");
        console.log("  this template runs. Use {{dir}} and {{name}} below to reference it.\n");
        const result = await withBack((ctx) =>
          confirm({ message: "Ask for a start directory when running?", default: false }, ctx),
        );
        if (result === BACK) { step = "description"; break; }
        promptDir = result;
        step = "promptName";
        break;
      }

      case "promptName": {
        const result = await withBack((ctx) =>
          confirm({ message: "Ask what to call the session when running?", default: false }, ctx),
        );
        if (result === BACK) { step = "promptDir"; break; }
        promptName = result;
        // Reset for first session
        sessionName = "";
        sessionDir = "";
        windows = [];
        step = "sessionName";
        break;
      }

      case "sessionName": {
        const result = await withBack((ctx) =>
          input({
            message: `Session ${sessions.length + 1} name`,
            required: true,
            default:
              (promptDir || promptName) && sessions.length === 0 ? "{{name}}" : undefined,
          }, ctx),
        );
        if (result === BACK) {
          if (sessions.length === 0) { step = "promptName"; break; }
          step = "done";
          break;
        }
        sessionName = result;
        step = "sessionDir";
        break;
      }

      case "sessionDir": {
        const result = await withBack((ctx) =>
          input({
            message: promptDir
              ? "Working directory (optional, blank = the directory you pick)"
              : "Working directory (optional, e.g. ~/code/project)",
          }, ctx),
        );
        if (result === BACK) { step = "sessionName"; break; }
        sessionDir = result;
        windows = [];
        windowName = "";
        windowCmd = "";
        step = "windowName";
        break;
      }

      case "windowName": {
        const result = await withBack((ctx) =>
          input({ message: `  Window ${windows.length + 1} name (optional)` }, ctx),
        );
        if (result === BACK) {
          if (windows.length === 0) { step = "sessionDir"; break; }
          // Done adding windows — push session
          const session: TemplateSession = { name: sessionName, windows };
          if (sessionDir) session.dir = sessionDir;
          sessions.push(session);
          step = "addSession";
          break;
        }
        windowName = result;
        step = "windowCmd";
        break;
      }

      case "windowCmd": {
        const result = await withBack((ctx) =>
          input({ message: `  Window ${windows.length + 1} command (optional)` }, ctx),
        );
        if (result === BACK) { step = "windowName"; break; }
        windowCmd = result;
        const win: TemplateWindow = {};
        if (windowName) win.name = windowName;
        if (windowCmd) win.cmd = windowCmd;
        windows.push(win);
        step = "addWindow";
        break;
      }

      case "addWindow": {
        const result = await withBack((ctx) =>
          confirm({ message: "Add another window?", default: false }, ctx),
        );
        if (result === BACK || !result) {
          // Done adding windows — push session
          const session: TemplateSession = { name: sessionName, windows };
          if (sessionDir) session.dir = sessionDir;
          sessions.push(session);
          step = "addSession";
          break;
        }
        windowName = "";
        windowCmd = "";
        step = "windowName";
        break;
      }

      case "addSession": {
        const result = await withBack((ctx) =>
          confirm({ message: "Add another session?", default: false }, ctx),
        );
        if (result === BACK || !result) {
          step = "done";
          break;
        }
        sessionName = "";
        sessionDir = "";
        windows = [];
        windowName = "";
        windowCmd = "";
        step = "sessionName";
        break;
      }
    }
  }

  if (sessions.length === 0) process.exit(0);

  // Phase 3: attach target
  let attachValue = sessions[0].name;

  if (sessions.length > 1) {
    const sessionChoice = await withBack((ctx) =>
      select({
        message: "Which session to attach to?",
        choices: sessions.map((s) => ({ value: s.name, name: s.name })),
      }, ctx),
    );
    if (sessionChoice !== BACK) attachValue = sessionChoice;
  }

  const chosenSession = sessions.find((s) => s.name === attachValue)!;
  if (chosenSession.windows.length > 1) {
    const windowChoices = [
      { value: "", name: "First window (default)" },
      ...chosenSession.windows.map((w, i) => ({
        value: w.name || String(i + 1),
        name: w.name || `Window ${i + 1}`,
      })),
    ];

    const windowChoice = await withBack((ctx) =>
      select({ message: "Which window to attach to?", choices: windowChoices }, ctx),
    );
    if (windowChoice !== BACK && windowChoice) {
      attachValue = `${attachValue}:${windowChoice}`;
    }
  }

  const template: Template = { name, sessions };
  if (description) template.description = description;
  if (promptDir) template.promptDir = true;
  if (promptName) template.promptName = true;
  if (attachValue) template.attach = attachValue;

  saveTemplate(template);
  console.log(`\nTemplate "${name}" created at ${getTemplatePath(name)}`);
}

async function deleteCmd(args: string[]): Promise<void> {
  let name = args[0];

  if (!name) {
    const templates = loadTemplates();
    if (templates.length === 0) {
      console.log("No templates found.");
      return;
    }

    // Main loop: ESC at confirm goes back to template picker
    while (true) {
      const result = await withBack((ctx) =>
        search({
          message: "Select template to delete",
          source: (term) => {
            const choices = templates.map((t) => ({
              value: t.name,
              name: t.name,
              description: t.description,
            }));
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
      if (result === BACK) {
        process.exit(0);
      }
      name = result;

      if (!templateExists(name)) {
        console.error(`Template "${name}" not found`);
        process.exit(1);
      }

      const confirmed = await withBack((ctx) =>
        confirm({
          message: `Delete template "${name}"?`,
          default: false,
        }, ctx),
      );
      if (confirmed === BACK) {
        continue;
      }

      if (!confirmed) continue;

      deleteTemplate(name);
      console.log(`Template "${name}" deleted`);
      return;
    }
  }

  // Direct name argument — no back navigation needed
  if (!templateExists(name)) {
    console.error(`Template "${name}" not found`);
    process.exit(1);
  }

  const confirmed = await withBack((ctx) =>
    confirm({
      message: `Delete template "${name}"?`,
      default: false,
    }, ctx),
  );
  if (confirmed === BACK) {
    process.exit(0);
  }

  if (!confirmed) {
    console.log("Cancelled");
    return;
  }

  deleteTemplate(name);
  console.log(`Template "${name}" deleted`);
}

export async function templateCmd(args: string[]): Promise<void> {
  const subcommand = args[0];
  const subArgs = args.slice(1);

  switch (subcommand) {
    case "list":
    case "ls":
      await listCmd();
      break;
    case "show":
      await showCmd(subArgs);
      break;
    case "edit":
      await editCmd(subArgs);
      break;
    case "create":
    case "new":
      await createCmd();
      break;
    case "delete":
    case "rm":
      await deleteCmd(subArgs);
      break;
    case undefined:
    case "help":
    case "--help":
    case "-h":
      showHelp();
      break;
    default:
      console.error(`Unknown subcommand: ${subcommand}`);
      showHelp();
      process.exit(1);
  }
}

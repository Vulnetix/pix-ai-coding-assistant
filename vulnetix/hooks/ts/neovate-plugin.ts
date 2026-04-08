import { runHook } from "./run-hook";

const BASH_TOOLS = ["bash", "shell", "terminal", "execute_command"];
const WRITE_TOOLS = ["write_file", "edit_file", "replace_in_file"];

export default {
  name: "vulnetix",
  description: "Vulnetix security hooks for Neovate",

  activate(api: any) {
    // Pre-tool-call guard
    api.onBeforeToolCall?.((event: any) => {
      const tool = event.tool?.toLowerCase() ?? "";
      if (BASH_TOOLS.some((t) => tool.includes(t))) {
        const result = runHook("pre-commit-scan.sh", event, 30_000);
        if (result.exitCode === 2) return { block: true, message: result.output };
      }
      if (WRITE_TOOLS.some((t) => tool.includes(t))) {
        const result = runHook("manifest-edit-scan.sh", event, 30_000);
        if (result.exitCode === 2) return { block: true, message: result.output };
      }
    });

    // Post-tool-call scan
    api.onAfterToolCall?.((event: any) => {
      const tool = event.tool?.toLowerCase() ?? "";
      if (BASH_TOOLS.some((t) => tool.includes(t))) {
        runHook("post-install-scan.sh", event);
      }
    });

    // Session summary on start
    api.onSessionStart?.(() => {
      runHook("session-summary.sh", {}, 10_000);
    });

    // Vuln context injection
    api.onBeforePrompt?.((event: any) => {
      const result = runHook("vuln-context-inject.sh", event, 15_000);
      if (result.output) return { contextAddition: result.output };
    });

    // Stop reminder
    api.onSessionEnd?.(() => {
      runHook("stop-reminder.sh", {}, 10_000);
    });
  },
};

import { runHook } from "./run-hook";

const BASH_TOOLS = ["bash", "shell", "terminal", "execute_command"];
const WRITE_TOOLS = ["write_file", "edit_file", "replace_in_file"];

export default function activate(api: any) {
  api.on("beforeToolCall", (event: any) => {
    const tool = event.tool?.toLowerCase() ?? "";
    if (BASH_TOOLS.some((t) => tool.includes(t))) {
      const result = runHook("pre-commit-scan.sh", event, 30_000);
      if (result.exitCode === 2) return { cancel: true, reason: result.output };
    }
    if (WRITE_TOOLS.some((t) => tool.includes(t))) {
      const result = runHook("manifest-edit-scan.sh", event, 30_000);
      if (result.exitCode === 2) return { cancel: true, reason: result.output };
    }
  });

  api.on("afterToolCall", (event: any) => {
    const tool = event.tool?.toLowerCase() ?? "";
    if (BASH_TOOLS.some((t) => tool.includes(t))) {
      runHook("post-install-scan.sh", event);
    }
  });
}

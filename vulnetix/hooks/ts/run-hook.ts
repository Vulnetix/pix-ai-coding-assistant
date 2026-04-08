import { execSync } from "child_process";
import { resolve, dirname } from "path";

export function runHook(
  scriptName: string,
  context: Record<string, unknown>,
  timeoutMs = 120_000,
): { exitCode: number; output: string } {
  const hookDir = resolve(dirname(__filename), "..");
  const scriptPath = resolve(hookDir, scriptName);
  try {
    const output = execSync(`bash "${scriptPath}"`, {
      input: JSON.stringify(context),
      timeout: timeoutMs,
      encoding: "utf-8",
    });
    return { exitCode: 0, output };
  } catch (err: any) {
    return { exitCode: err.status ?? 1, output: err.stdout ?? "" };
  }
}

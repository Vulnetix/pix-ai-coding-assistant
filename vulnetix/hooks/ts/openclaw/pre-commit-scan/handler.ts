import { runHook } from "../../run-hook";

export default async function handler(event: any) {
  const result = runHook("pre-commit-scan.sh", event, 30_000);
  if (result.exitCode === 2) return { block: true, message: result.output };
}

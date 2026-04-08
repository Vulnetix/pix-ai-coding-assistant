import { runHook } from "../../run-hook";

export default async function handler(event: any) {
  const result = runHook("manifest-edit-scan.sh", event, 30_000);
  if (result.exitCode === 2) return { block: true, message: result.output };
}

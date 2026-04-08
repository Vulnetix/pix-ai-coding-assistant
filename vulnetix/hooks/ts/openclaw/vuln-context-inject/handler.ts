import { runHook } from "../../run-hook";

export default async function handler(event: any) {
  const result = runHook("vuln-context-inject.sh", event, 15_000);
  if (result.output) return { contextAddition: result.output };
}

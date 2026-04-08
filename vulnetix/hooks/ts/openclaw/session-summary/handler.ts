import { runHook } from "../../run-hook";

export default async function handler(event: any) {
  runHook("session-summary.sh", event, 10_000);
}

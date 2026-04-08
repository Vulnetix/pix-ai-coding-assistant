import { runHook } from "../../run-hook";

export default async function handler(event: any) {
  runHook("post-install-scan.sh", event);
}

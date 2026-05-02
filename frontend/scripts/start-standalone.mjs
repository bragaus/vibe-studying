import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { prepareStandaloneArtifacts } from "./prepare-standalone.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");
const standaloneRoot = path.join(projectRoot, ".next", "standalone");
const standaloneServerPath = path.join(standaloneRoot, "server.js");

async function main() {
  await prepareStandaloneArtifacts();

  const child = spawn(process.execPath, [standaloneServerPath], {
    cwd: standaloneRoot,
    stdio: "inherit",
    env: process.env,
  });

  child.on("exit", (code, signal) => {
    if (signal) {
      process.kill(process.pid, signal);
      return;
    }

    process.exit(code ?? 0);
  });
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});

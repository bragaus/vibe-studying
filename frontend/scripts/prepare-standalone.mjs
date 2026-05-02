import { access, cp, mkdir, rm } from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");
const standaloneRoot = path.join(projectRoot, ".next", "standalone");
const standaloneServerPath = path.join(standaloneRoot, "server.js");
const sourceStaticDir = path.join(projectRoot, ".next", "static");
const targetStaticDir = path.join(standaloneRoot, ".next", "static");
const sourcePublicDir = path.join(projectRoot, "public");
const targetPublicDir = path.join(standaloneRoot, "public");

async function ensurePathExists(targetPath, message) {
  try {
    await access(targetPath, fsConstants.F_OK);
  } catch {
    throw new Error(message);
  }
}

async function copyDirectory(sourceDir, targetDir) {
  await rm(targetDir, { recursive: true, force: true });
  await mkdir(path.dirname(targetDir), { recursive: true });
  await cp(sourceDir, targetDir, { recursive: true });
}

export async function prepareStandaloneArtifacts() {
  await ensurePathExists(standaloneServerPath, "Standalone build not found. Run `npm run build` first.");
  await ensurePathExists(sourceStaticDir, "Build static assets not found. Run `npm run build` first.");

  await copyDirectory(sourceStaticDir, targetStaticDir);

  try {
    await access(sourcePublicDir, fsConstants.F_OK);
    await copyDirectory(sourcePublicDir, targetPublicDir);
  } catch {
    await rm(targetPublicDir, { recursive: true, force: true });
  }
}

const isDirectExecution = process.argv[1] && path.resolve(process.argv[1]) === __filename;

if (isDirectExecution) {
  prepareStandaloneArtifacts().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
  });
}

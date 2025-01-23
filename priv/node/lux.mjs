import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { ensureDependencyInstalled } from "nypm";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const importPackage = async (packageName) => {
  try {
    await ensureDependencyInstalled(packageName, {
      cwd: __dirname,
      silent: true
    });
    await import(packageName);
    return {success: true};
  } catch (error) {
    return {success: false, error: error.code};
  }
};
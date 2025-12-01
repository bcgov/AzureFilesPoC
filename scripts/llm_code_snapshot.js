// llm_code_snapshot.js
// Generates a single text file with all .md, .txt, .tf, .json files (not .gitignore'd) for LLM sharing.

const fs = require('fs');
const path = require('path');
const ignore = require('ignore');

// --- Config ---
const exts = ['.md', '.txt', '.tf', '.json'];
const outputFile = 'llm_code_snapshot.txt';
const gitignoreFile = '.gitignore';
const rootDir = process.cwd();

// --- Load .gitignore rules ---
let ig = ignore();
const gitignorePath = path.join(rootDir, gitignoreFile);
if (fs.existsSync(gitignorePath)) {
  const gitignoreContent = fs.readFileSync(gitignorePath, 'utf8');
  ig = ig.add(gitignoreContent);
}

// --- Additional exclusions (security and clutter) ---
ig.add([
  'node_modules/',
  'ARCHIVE/',
  'azure.env',
  'azure.env.old',
  '.git/',
  '.vscode/',
  '*.log',
  'llm_code_snapshot.txt'
]);

// --- Recursively collect files ---
function collectFiles(dir) {
  let files = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    const relPath = path.relative(rootDir, fullPath);
    if (ig.ignores(relPath)) continue;
    if (entry.isDirectory()) {
      files = files.concat(collectFiles(fullPath));
    } else if (exts.includes(path.extname(entry.name).toLowerCase())) {
      files.push(relPath);
    }
  }
  return files;
}

// --- Main ---
const allFiles = collectFiles(rootDir);
let output = `# LLM Code Snapshot\nGenerated: ${new Date().toISOString()}\n\n`;

for (const file of allFiles) {
  output += `--- START OF FILE: ${file} ---\n`;
  try {
    output += fs.readFileSync(path.join(rootDir, file), 'utf8');
  } catch (e) {
    output += `[Error reading file: ${e.message}]\n`;
  }
  output += `\n--- END OF FILE: ${file} ---\n\n`;
}

fs.writeFileSync(outputFile, output, 'utf8');
console.log(`Snapshot written to ${outputFile}`);
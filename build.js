#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const SCRIPTS_DIR = path.join(__dirname, 'scripts');
const METADATA_FILE = path.join(__dirname, 'metadata.json');
const OUTPUT_FILE = path.join(__dirname, 'search-index.json');

const TEXT_EXTENSIONS = new Set([
  'cls', 'trigger', 'apex', 'soql', 'sosl', 'page', 'component',
  'js', 'ts', 'json', 'xml', 'html', 'htm', 'css',
  'py', 'rb', 'sh', 'bash', 'sql', 'md', 'txt', 'csv', 'yaml', 'yml',
  'env', 'cfg', 'conf', 'ini', 'toml', 'properties', 'java',
  'c', 'cpp', 'h', 'cs', 'go', 'rs', 'swift', 'kt', 'php',
]);

function readText(fullPath, ext) {
  if (TEXT_EXTENSIONS.has(ext) || !ext) {
    try { return fs.readFileSync(fullPath, 'utf8'); } catch { return '[Could not read file]'; }
  }
  return '[Binary file — not indexed]';
}

// Returns a Map of relPath -> fullPath for every directory containing steps.json.
// Does not recurse into bundle directories.
function findBundleDirs(baseDir) {
  const bundleDirs = new Map();
  function walk(dir, relBase) {
    let names;
    try { names = fs.readdirSync(dir).sort(); } catch { return; }
    if (names.includes('steps.json')) {
      bundleDirs.set(relBase, dir);
      return;
    }
    for (const name of names) {
      if (name.startsWith('.')) continue;
      const fullPath = path.join(dir, name);
      const relPath = relBase ? `${relBase}/${name}` : name;
      try { if (fs.statSync(fullPath).isDirectory()) walk(fullPath, relPath); } catch {}
    }
  }
  walk(baseDir, '');
  return bundleDirs;
}

function buildBundleEntry(bundleRelPath, bundleDir, metadata) {
  const stepsFile = path.join(bundleDir, 'steps.json');
  let config;
  try {
    config = JSON.parse(fs.readFileSync(stepsFile, 'utf8'));
  } catch (e) {
    console.warn(`Warning: skipping bundle ${bundleRelPath} — could not parse steps.json: ${e.message}`);
    return null;
  }

  const indexPath = `scripts/${bundleRelPath}`;
  const meta = metadata[indexPath] || {};

  const steps = [];
  for (const step of (config.steps || [])) {
    const filePath = path.join(bundleDir, step.file);
    const ext = path.extname(step.file).toLowerCase().slice(1);
    let content = '', size = 0, modified = new Date().toISOString();
    try {
      const stat = fs.statSync(filePath);
      size = stat.size;
      modified = stat.mtime.toISOString();
      content = readText(filePath, ext);
    } catch {
      content = `[File not found: ${step.file}]`;
    }
    steps.push({
      file: step.file,
      label: step.label || step.file,
      note: step.note || '',
      extension: ext,
      content,
      size,
      modified,
    });
  }

  const latestModified = steps.reduce(
    (latest, s) => (s.modified > latest ? s.modified : latest),
    new Date(0).toISOString()
  );

  return {
    type: 'bundle',
    name: config.title || path.basename(bundleRelPath),
    path: indexPath,
    description: config.description || meta.description || '',
    tags: config.tags || meta.tags || [],
    modified: latestModified,
    steps,
  };
}

// Walk directory for individual files, skipping any bundle directories.
function walkFiles(dir, baseRelative, bundleRelPaths) {
  const entries = [];
  let names;
  try { names = fs.readdirSync(dir).sort(); } catch { return entries; }
  for (const name of names) {
    if (name.startsWith('.') || name === 'steps.json') continue;
    const fullPath = path.join(dir, name);
    const relPath = baseRelative ? `${baseRelative}/${name}` : name;
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      if (!bundleRelPaths.has(relPath)) {
        entries.push(...walkFiles(fullPath, relPath, bundleRelPaths));
      }
    } else {
      entries.push({ fullPath, relPath, stat });
    }
  }
  return entries;
}

// --- Main ---

let metadata = {};
if (fs.existsSync(METADATA_FILE)) {
  try { metadata = JSON.parse(fs.readFileSync(METADATA_FILE, 'utf8')); }
  catch (e) { console.warn('Warning: could not parse metadata.json:', e.message); }
}

if (!fs.existsSync(SCRIPTS_DIR)) fs.mkdirSync(SCRIPTS_DIR, { recursive: true });

const bundleDirs = findBundleDirs(SCRIPTS_DIR);
const index = [];

for (const [relPath, fullPath] of bundleDirs) {
  const entry = buildBundleEntry(relPath, fullPath, metadata);
  if (entry) index.push(entry);
}

const files = walkFiles(SCRIPTS_DIR, '', bundleDirs);
for (const { fullPath, relPath, stat } of files) {
  const ext = path.extname(relPath).toLowerCase().slice(1);
  const name = path.basename(relPath);
  const indexPath = `scripts/${relPath}`;
  const meta = metadata[indexPath] || {};
  index.push({
    type: 'file',
    name,
    path: indexPath,
    extension: ext,
    content: readText(fullPath, ext),
    size: stat.size,
    modified: stat.mtime.toISOString(),
    tags: meta.tags || [],
    description: meta.description || '',
  });
}

fs.writeFileSync(OUTPUT_FILE, JSON.stringify(index, null, 2));
const bundles = index.filter(e => e.type === 'bundle').length;
const fileCount = index.filter(e => e.type === 'file').length;
console.log(`Built search-index.json: ${bundles} bundle${bundles !== 1 ? 's' : ''}, ${fileCount} individual file${fileCount !== 1 ? 's' : ''}.`);

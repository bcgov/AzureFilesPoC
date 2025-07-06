const fs = require('fs');
const path = require('path');

// Input files
const tfvarsPath = path.resolve(__dirname, '../terraform/environments/cicd/terraform.tfvars');
const diagramPath = path.resolve(__dirname, 'azure_files_poc_architecture_diagram.drawio');
const outputPath = path.resolve(__dirname, 'azure_files_poc_architecture_diagram_sanitized.drawio');

// Helper: parse tfvars file into a mapping of real values to placeholders
function parseTfvars(tfvarsContent) {
  const mapping = {};
  const lines = tfvarsContent.split(/\r?\n/);
  const legendStart = lines.findIndex(l => l.includes('PLACEHOLDER MAPPING LEGEND'));
  if (legendStart !== -1) {
    for (let i = legendStart + 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('# <') && line.includes('=')) {
        const [placeholder, real] = line.replace('#', '').split('=');
        const tag = placeholder.trim();
        const value = real.replace(/"/g, '').trim();
        mapping[value] = tag;
      }
      if (line.startsWith('# ===')) break;
    }
  }
  // Also parse actual tfvars assignments
  for (const line of lines) {
    const match = line.match(/^\s*(\w+)\s*=\s*"?([^"\n]+)"?/);
    if (match) {
      const key = match[1];
      let value = match[2];
      // If value is an array, extract each item
      if (value.startsWith('[') && value.endsWith(']')) {
        value = value.slice(1, -1).split(',').map(v => v.trim().replace(/^"|"$/g, ''));
        value.forEach(val => {
          if (val && !val.startsWith('<') && !val.startsWith('&lt;') && !mapping[val]) {
            mapping[val] = key;
          }
        });
      } else {
        if (value && !value.startsWith('<') && !value.startsWith('&lt;') && !mapping[value]) {
          mapping[value] = key;
        }
      }
    }
  }
  return mapping;
}

function xmlEscape(str) {
  // No longer needed, but kept for compatibility
  return str;
}

// Extract CIDR and IP mappings from tfvars content
function extractCidrAndIpMappings(tfvarsContent) {
  const mapping = {};
  const lines = tfvarsContent.split(/\r?\n/);
  const cidrRegex = /([0-9]{1,3}(?:\.[0-9]{1,3}){3}\/[0-9]{1,2})/g;
  const ipRegex = /([0-9]{1,3}(?:\.[0-9]{1,3}){3})(?!\/[0-9]{1,2})/g;
  for (const line of lines) {
    const match = line.match(/^\s*(\w+)\s*=\s*(\[.*\]|"[^"]+"|[^#\s]+)/);
    if (match) {
      const key = match[1];
      let value = match[2];
      // Remove quotes and brackets
      value = value.replace(/\[|\]|"/g, '');
      // Check for CIDR blocks
      let cidrs = value.match(cidrRegex);
      if (cidrs) {
        cidrs.forEach(cidr => {
          if (!mapping[cidr]) mapping[cidr] = key;
        });
      }
      // Check for IP addresses
      let ips = value.match(ipRegex);
      if (ips) {
        ips.forEach(ip => {
          if (!mapping[ip]) mapping[ip] = key;
        });
      }
    }
  }
  return mapping;
}

// Helper: replace all occurrences of real values with placeholders
function sanitizeDiagram(diagramContent, mapping) {
  let sanitized = diagramContent;
  // Sort by length descending to avoid partial replacements
  const keys = Object.keys(mapping).sort((a, b) => b.length - a.length);
  for (const real of keys) {
    if (real && real.length > 2) {
      const safeReal = real.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      // Replace value even if surrounded by non-word characters (e.g., in parentheses, after e.g., etc.)
      sanitized = sanitized.replace(new RegExp(`([\(\[\{\s'\"=,:;>])${safeReal}([\)\]\}\s'\"=,<:;])`, 'g'), `$1${mapping[real]}$2`);
      // Also replace any remaining standalone occurrences
      sanitized = sanitized.replace(new RegExp(safeReal, 'g'), mapping[real]);
    }
  }
  return sanitized;
}

function main() {
  if (!fs.existsSync(tfvarsPath) || !fs.existsSync(diagramPath)) {
    console.error('Input files not found.');
    process.exit(1);
  }
  const tfvarsContent = fs.readFileSync(tfvarsPath, 'utf8');
  const diagramContent = fs.readFileSync(diagramPath, 'utf8');
  // First pass: resource name mapping
  const mapping = parseTfvars(tfvarsContent);
  // Second pass: CIDR/IP mapping
  const cidrIpMapping = extractCidrAndIpMappings(tfvarsContent);
  // Merge mappings, CIDR/IP mapping takes precedence
  Object.assign(mapping, cidrIpMapping);
  const sanitized = sanitizeDiagram(diagramContent, mapping);
  fs.writeFileSync(outputPath, sanitized, 'utf8');
  console.log('Sanitized diagram written to', outputPath);
}

if (require.main === module) {
  main();
}

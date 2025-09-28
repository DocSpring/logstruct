/* eslint-disable no-console */
// Simple internal link checker for the built Next.js docs.
// Scans .next/server/app HTML files, collects available routes,
// then verifies that internal hrefs (starting with "/") resolve to an existing route
// or an allowed static asset.

const fs = require('fs');
const path = require('path');

const OUT_DIR = path.join(process.cwd(), 'out');
const ALLOWED_STATIC = new Set([
  '/yard/index.html',
  '/coverage/index.html',
  '/favicon.ico',
  '/favicon.png',
]);

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.isFile() && entry.name.endsWith('.html')) out.push(full);
  }
  return out;
}

function routeForFile(file) {
  const rel = path.relative(OUT_DIR, file).replace(/\\/g, '/');
  if (rel === 'index.html') return '/';
  if (rel.endsWith('/index.html')) return `/${rel.slice(0, -11)}`; // drop '/index.html'
  if (rel.endsWith('.html')) return `/${rel.slice(0, -5)}`; // drop '.html'
  return null;
}

function collectRouteAnchors() {
  const files = walk(OUT_DIR);
  const anchors = new Map(); // route -> Set(ids)
  const routeToFile = new Map();
  const idRe = /id=\"([a-zA-Z0-9_-]+)\"/g;

  for (const file of files) {
    const route = routeForFile(file);
    if (!route) continue;
    routeToFile.set(route, file);
    const html = fs.readFileSync(file, 'utf8');
    const set = new Set();
    let m;
    while ((m = idRe.exec(html)) !== null) {
      set.add(m[1]);
    }
    anchors.set(route, set);
  }
  return { routeToFile, anchors };
}

function targetExistsForHref(href) {
  // Strip hash/query
  const pathOnly = href.split('#')[0].split('?')[0];

  // Absolute path in out dir
  const asFile = path.join(OUT_DIR, pathOnly);

  // Direct asset file (e.g., /_next/static/..., /favicon.ico)
  if (fs.existsSync(asFile)) return true;

  // Allow known static pages
  if (ALLOWED_STATIC.has(pathOnly))
    return fs.existsSync(path.join(OUT_DIR, pathOnly));

  // Map route paths to HTML files: /docs -> /docs/index.html or /docs.html
  const htmlIndex = path.join(OUT_DIR, pathOnly, 'index.html');
  const htmlFlat = path.join(OUT_DIR, `${pathOnly}.html`);
  if (fs.existsSync(htmlIndex) || fs.existsSync(htmlFlat)) return true;

  // Normalize trailing slash variants
  if (pathOnly.endsWith('/') && pathOnly !== '/') {
    const trimmed = pathOnly.slice(0, -1);
    const htmlIndex2 = path.join(OUT_DIR, trimmed, 'index.html');
    const htmlFlat2 = path.join(OUT_DIR, `${trimmed}.html`);
    if (fs.existsSync(htmlIndex2) || fs.existsSync(htmlFlat2)) return true;
  }

  return false;
}

function extractHrefs(html) {
  const hrefs = [];
  const re = /href=\"([^\"]+)\"/g;
  let m;
  while ((m = re.exec(html)) !== null) {
    hrefs.push(m[1]);
  }
  return hrefs;
}

function main() {
  if (!fs.existsSync(OUT_DIR)) {
    console.warn('[check-internal-links] No docs/out directory; skipping');
    return;
  }
  const htmlFiles = walk(OUT_DIR);
  const { routeToFile, anchors } = collectRouteAnchors();
  const errors = [];
  const anchorErrors = [];

  for (const file of htmlFiles) {
    const rel = path.relative(process.cwd(), file);
    const html = fs.readFileSync(file, 'utf8');
    const hrefs = extractHrefs(html);
    for (const href of hrefs) {
      // Ignore external and fragment links
      if (
        /^(https?:)?\/\//.test(href) ||
        href.startsWith('mailto:') ||
        href.startsWith('tel:') ||
        href.startsWith('#')
      )
        continue;
      // Only validate internal absolute paths
      if (!href.startsWith('/')) continue;

      const [pathOnly, hash] = href.split('#');

      if (!targetExistsForHref(href)) {
        errors.push({ file: rel, href });
        continue;
      }

      // If an anchor/hash is present, ensure it exists in the target route
      if (hash && pathOnly.startsWith('/')) {
        // Normalize route like in routeForFile
        let route = pathOnly;
        if (route !== '/' && route.endsWith('/')) route = route.slice(0, -1);
        // If direct file asset, skip anchor check
        if (route.startsWith('/_next/') || ALLOWED_STATIC.has(pathOnly)) {
          continue;
        }
        const targetFile =
          routeToFile.get(route) || routeToFile.get(`${route}`);
        if (!targetFile) {
          // Route not mapped; already counted as errors above
          continue;
        }
        const ids = anchors.get(route) || new Set();
        if (!ids.has(hash)) {
          anchorErrors.push({ file: rel, href, route, missing: hash });
        }
      }
    }
  }

  if (errors.length || anchorErrors.length) {
    if (errors.length)
      console.error('[check-internal-links] Broken internal links found:');
    for (const e of errors) {
      console.error(`  ${e.file} -> ${e.href}`);
    }
    if (anchorErrors.length)
      console.error('[check-internal-links] Missing anchors:');
    for (const a of anchorErrors) {
      console.error(
        `  ${a.file} -> ${a.href} (no #${a.missing} in ${a.route})`,
      );
    }
    process.exit(1);
  } else {
    console.log('[check-internal-links] All internal links OK');
  }
}

main();

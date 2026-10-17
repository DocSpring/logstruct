// Serves the exported site (out/) for the Playwright tests, on 127.0.0.1 only
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const PORT = process.env.PORT ? Number(process.env.PORT) : 3011;
const HOST = '127.0.0.1';
const ROOT = path.join(__dirname, '..', 'out');

// The file to serve for a request URL, or null. Only regular files inside root: the path is decoded, `..` can't go
// above root, and a symlink that leads outside root isn't followed.
function resolveFile(root, requestUrl) {
  let pathname;
  try {
    pathname = decodeURIComponent((requestUrl || '/').split(/[?#]/)[0] || '/');
  } catch {
    return null;
  }
  if (pathname.includes('\0')) return null;

  const realRoot = fs.realpathSync(root);
  const normalized = path.posix.normalize(`/${pathname}`);
  const candidates = [normalized, path.posix.join(normalized, 'index.html'), `${normalized.replace(/\/$/, '')}.html`];
  for (const candidate of candidates) {
    let real;
    try {
      real = fs.realpathSync(path.join(realRoot, candidate));
    } catch {
      continue;
    }
    if (!real.startsWith(realRoot + path.sep)) continue;
    if (fs.statSync(real).isFile()) return real;
  }
  return null;
}

function createServer(root) {
  return http.createServer((req, res) => {
    const filePath = resolveFile(root, req.url);
    const notFoundPage = resolveFile(root, '/404.html');
    if (!filePath) res.statusCode = 404;
    if (!filePath && !notFoundPage) {
      res.end('Not found');
      return;
    }
    const stream = fs.createReadStream(filePath || notFoundPage);
    stream.on('error', () => {
      res.statusCode = 500;
      res.end('Server error');
    });
    stream.pipe(res);
  });
}

if (require.main === module) {
  createServer(ROOT).listen(PORT, HOST, () => {
    console.log(`Static server running at http://${HOST}:${PORT}`);
  });
}

module.exports = { createServer, resolveFile };

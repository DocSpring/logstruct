/* eslint-disable @typescript-eslint/no-explicit-any */

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';

const PORT = process.env.PORT ? Number(process.env.PORT) : 3010;
const BASE = `http://localhost:${PORT}`;

async function _waitForServer(url: string, timeoutMs = 120000): Promise<void> {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    const check = () => {
      http
        .get(url, (res) => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 500) {
            resolve();
          } else {
            retry();
          }
        })
        .on('error', retry);

      function retry() {
        if (Date.now() - start > timeoutMs) {
          reject(new Error(`Server did not start within ${timeoutMs}ms`));
          return;
        }
        setTimeout(check, 300);
      }
    };
    check();
  });
}

let server: http.Server | null = null;

beforeAll(async () => {
  // Serve the static export from the "out" directory
  const outDir = path.resolve(__dirname, '..', 'out');
  server = http.createServer((req, res) => {
    try {
      const url = req.url || '/';
      const filePath = (() => {
        const clean = url.split('?')[0] || '/';
        const full = path.join(outDir, clean);
        if (fs.existsSync(full) && fs.statSync(full).isFile()) return full;
        // Try index.html in a directory
        const withIndex = path.join(outDir, clean.replace(/\/?$/, '/'), 'index.html');
        if (fs.existsSync(withIndex)) return withIndex;
        // Try appending .html
        const withHtml = path.join(outDir, `${clean}.html`);
        if (fs.existsSync(withHtml)) return withHtml;
        return path.join(outDir, '404.html');
      })();
      const stream = fs.createReadStream(filePath);
      stream.on('error', () => {
        res.statusCode = 404;
        res.end('Not found');
      });
      stream.pipe(res);
    } catch (_e) {
      res.statusCode = 500;
      res.end('Server error');
    }
  });
  await new Promise<void>((resolve) => server?.listen(PORT, resolve));
});

afterAll(() => {
  if (server) server.close();
});

async function get(path: string): Promise<string> {
  const res = await fetch(`${BASE}${path}`);
  if (!res.ok) throw new Error(`GET ${path} failed: ${res.status} ${res.statusText}`);
  return await res.text();
}

describe('Site integration pages', () => {
  test('home page renders', async () => {
    const html = await get('/');
    expect(html).toContain('Zero-config JSON logging for Ruby on Rails');
    expect(html).toContain('Get Started');
  });

  test('/docs renders', async () => {
    const html = await get('/docs');
    expect(html).toContain('Introduction');
    expect(html).toContain('Features');
  });

  test('integrations page renders examples', async () => {
    const html = await get('/docs/integrations');
    expect(html).toContain('Integrations');
    expect(html).toContain('Example Logs');
  });

  test('sorbet types page lists types', async () => {
    const html = await get('/docs/sorbet-types');
    expect(html).toContain('What is Sorbet?');
    expect(html).toContain('Built-In Log Classes');
    expect(html).toContain('Built-In Enums');
  });

  test('logging docs page renders custom content', async () => {
    const html = await get('/docs/logging');
    expect(html).toContain('Logging to STDOUT');
    expect(html).toContain('Rails Defaults vs. LogStruct');
  });
});

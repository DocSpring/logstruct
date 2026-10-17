const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { resolveFile } = require('../serve-static');

describe('resolveFile', () => {
  let dir;
  let root;

  beforeEach(() => {
    dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'serve-static-')));
    root = path.join(dir, 'out');
    fs.mkdirSync(path.join(root, 'docs'), { recursive: true });
    fs.writeFileSync(path.join(root, 'index.html'), 'home');
    fs.writeFileSync(path.join(root, 'docs', 'index.html'), 'docs');
    fs.writeFileSync(path.join(root, 'about.html'), 'about');
    fs.writeFileSync(path.join(dir, 'secret.txt'), 'outside');
    fs.symlinkSync(dir, path.join(root, 'link'));
  });

  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('serves the exported pages', () => {
    expect(resolveFile(root, '/')).toBe(path.join(root, 'index.html'));
    expect(resolveFile(root, '/docs/?q=1')).toBe(path.join(root, 'docs', 'index.html'));
    expect(resolveFile(root, '/about')).toBe(path.join(root, 'about.html'));
    expect(resolveFile(root, '/about.html')).toBe(path.join(root, 'about.html'));
  });

  it("doesn't serve files outside the root", () => {
    for (const url of [
      '/../secret.txt',
      '/docs/../../secret.txt',
      '/%2e%2e/secret.txt',
      '/%2E%2E%2Fsecret.txt', // cspell:disable-line
      '/link/secret.txt',
      '/link',
      '/%00',
      '/%E0%A4%A',
      '/missing',
    ]) {
      expect(resolveFile(root, url)).toBeNull();
    }
  });
});

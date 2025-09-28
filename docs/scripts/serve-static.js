const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT ? Number(process.env.PORT) : 3011;
const ROOT = path.join(__dirname, '..', 'out');

const server = http.createServer((req, res) => {
  try {
    const url = req.url || '/';
    const clean = url.split('?')[0] || '/';
    const tryPaths = [];
    tryPaths.push(path.join(ROOT, clean));
    tryPaths.push(path.join(ROOT, clean.replace(/\/?$/, '/'), 'index.html'));
    tryPaths.push(path.join(ROOT, `${clean}.html`));

    let filePath = tryPaths.find(
      (p) => fs.existsSync(p) && fs.statSync(p).isFile(),
    );
    if (!filePath) {
      filePath = path.join(ROOT, '404.html');
    }

    const stream = fs.createReadStream(filePath);
    stream.on('error', () => {
      res.statusCode = 404;
      res.end('Not found');
    });
    stream.pipe(res);
  } catch (e) {
    res.statusCode = 500;
    res.end('Server error');
  }
});

server.listen(PORT, () => {
  console.log(`Static server running at http://localhost:${PORT}`);
});

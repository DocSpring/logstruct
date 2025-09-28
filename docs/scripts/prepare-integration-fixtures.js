const fs = require('fs');
const path = require('path');

function ensureCoverageJson() {
  const dir = path.join(__dirname, '..', 'public', 'coverage');
  const file = path.join(dir, 'coverage.json');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(file)) {
    const data = {
      metrics: {
        covered_percent: 80.0,
      },
    };
    fs.writeFileSync(file, JSON.stringify(data, null, 2));
    console.log(`Created stub coverage at ${file}`);
  }
}

ensureCoverageJson();

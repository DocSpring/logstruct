const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

async function generateFavicons() {
  const svgPath = path.join(process.cwd(), 'public/icons/logstruct.svg');
  const pngOutputPath = path.join(process.cwd(), 'public/favicon.png');

  try {
    // Generate PNG for both directories
    await sharp(svgPath).resize(32, 32).png().toFile(pngOutputPath);
    console.log(`Generated favicon.png in public directory: ${pngOutputPath}`);

    console.log('You will need to convert this to ICO manually.');
  } catch (error) {
    console.error('Error generating favicons:', error);
  }
}

generateFavicons().catch(console.error);

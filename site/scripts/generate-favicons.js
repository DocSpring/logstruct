const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

async function generateFavicons() {
  const svgPath = path.join(process.cwd(), 'public/icons/logstruct.svg');
  const pngOutputPath = path.join(process.cwd(), 'public/favicon.png');
  const pngOutputPathApp = path.join(process.cwd(), 'app/favicon.png');
  const icoOutputPath = path.join(process.cwd(), 'public/favicon.ico');
  const icoOutputPathApp = path.join(process.cwd(), 'app/favicon.ico');
  
  try {
    // Generate PNG for both directories
    await sharp(svgPath)
      .resize(32, 32)
      .png()
      .toFile(pngOutputPath);
    
    console.log('Generated favicon.png in public directory');
    
    await sharp(svgPath)
      .resize(32, 32)
      .png()
      .toFile(pngOutputPathApp);
    
    console.log('Generated favicon.png in app directory');
    
    // Generate another PNG but at 16x16 for the ICO format
    const png16x16Path = path.join(process.cwd(), 'public/favicon-16x16.png');
    
    await sharp(svgPath)
      .resize(16, 16)
      .png()
      .toFile(png16x16Path);
    
    console.log('Generated favicon-16x16.png');
    
    // Since Sharp doesn't support ICO format directly, we'll just create symlinks to the PNG
    // For a real production site, you would want to use a dedicated package to create proper ICO files
    fs.copyFileSync(pngOutputPath, icoOutputPath);
    fs.copyFileSync(pngOutputPath, icoOutputPathApp);
    
    console.log('Created favicon.ico files (actually PNG files)');
    
  } catch (error) {
    console.error('Error generating favicons:', error);
  }
}

generateFavicons().catch(console.error);
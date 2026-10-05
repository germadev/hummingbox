// Genera los PNG de los iconos de la app a partir de docs/icon.svg.
//
// Uso (desde la raíz del repositorio):
//   NODE_PATH="$(npm root -g)" node tool/icons.cjs
//
// Necesita Node y Playwright con Chromium:
//   npm install -g playwright && npx playwright install chromium
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const res = path.join(root, 'android/app/src/main/res');
const appIcon = path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
const source = fs.readFileSync(path.join(root, 'docs/icon.svg'), 'utf8');

/// [svg] con el recuadro ocupando la fracción [scale] del lienzo.
function scaled(svg, scale) {
  const size = 1024 / scale;
  const offset = (1024 - size) / 2;
  return svg.replace(
    'viewBox="0 0 1024 1024"',
    `viewBox="${offset} ${offset} ${size} ${size}"`,
  );
}

const withoutTile = (svg) => svg.replace(/<rect id="tile"[^>]*\/>/, '');

const variants = {
  // iOS redondea las esquinas: el recuadro llega a los bordes.
  full: source.replace(/(<rect id="tile"[^>]*?) rx="[^"]*"/, '$1'),
  // Android 7: el recuadro redondeado, a 44 de 48 dp.
  legacy: scaled(source, 44 / 48),
  // Primer plano del icono adaptable (Android 8+): solo el dibujo, que
  // tiene que caber en el círculo de 66 dp de las capas de 108 dp. El
  // fondo es drawable/ic_launcher_background.xml.
  foreground: scaled(withoutTile(source), 0.76),
  // Iconos temáticos de Android 13+: el sistema solo usa la opacidad.
  monochrome: scaled(
    withoutTile(source)
      .replaceAll('url(#orange)', '#FFFFFF')
      .replace(' filter="url(#relief)"', ''),
    0.76,
  ),
};

const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

/// PNG en RGB, sin canal alfa (el App Store no admite iconos con alfa).
function withoutAlpha(png) {
  const chunks = [];
  for (let i = 8; i < png.length; ) {
    const length = png.readUInt32BE(i);
    chunks.push({
      type: png.toString('ascii', i + 4, i + 8),
      data: png.subarray(i + 8, i + 8 + length),
    });
    i += 12 + length;
  }
  const header = chunks.find((c) => c.type === 'IHDR').data;
  const width = header.readUInt32BE(0);
  const height = header.readUInt32BE(4);
  if (header[8] !== 8 || header[9] !== 6) return png;
  const raw = zlib.inflateSync(
    Buffer.concat(chunks.filter((c) => c.type === 'IDAT').map((c) => c.data)),
  );
  const stride = width * 4;
  const pixels = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    for (let x = 0; x < stride; x++) {
      const value = raw[y * (stride + 1) + 1 + x];
      const a = x >= 4 ? pixels[y * stride + x - 4] : 0;
      const b = y > 0 ? pixels[(y - 1) * stride + x] : 0;
      const c = x >= 4 && y > 0 ? pixels[(y - 1) * stride + x - 4] : 0;
      let predictor = 0;
      if (filter === 1) predictor = a;
      if (filter === 2) predictor = b;
      if (filter === 3) predictor = (a + b) >> 1;
      if (filter === 4) {
        const p = a + b - c;
        const pa = Math.abs(p - a);
        const pb = Math.abs(p - b);
        const pc = Math.abs(p - c);
        predictor = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      pixels[y * stride + x] = (value + predictor) & 0xff;
    }
  }
  const rgb = Buffer.alloc(height * (width * 3 + 1));
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      pixels.copy(rgb, y * (width * 3 + 1) + 1 + x * 3, y * stride + x * 4, y * stride + x * 4 + 3);
    }
  }
  const chunk = (type, data) => {
    const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(zlib.crc32(body));
    return Buffer.concat([length, body, crc]);
  };
  const ihdr = Buffer.from(header);
  ihdr[9] = 2;
  return Buffer.concat([
    png.subarray(0, 8),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(rgb, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  async function render(variant, size, file, { opaque = false } = {}) {
    const svg = variants[variant].replace(
      'width="1024" height="1024"',
      `width="${size}" height="${size}"`,
    );
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(
      `<body style="margin:0;background:transparent">${svg}</body>`,
    );
    const png = await page.screenshot({
      omitBackground: true,
      clip: { x: 0, y: 0, width: size, height: size },
    });
    fs.writeFileSync(file, opaque ? withoutAlpha(png) : png);
    console.log(path.relative(root, file));
  }

  for (const [density, factor] of Object.entries(densities)) {
    const dir = path.join(res, `mipmap-${density}`);
    await render('legacy', 48 * factor, path.join(dir, 'ic_launcher.png'));
    for (const layer of ['foreground', 'monochrome']) {
      await render(layer, 108 * factor, path.join(dir, `ic_launcher_${layer}.png`));
    }
  }

  const contents = JSON.parse(
    fs.readFileSync(path.join(appIcon, 'Contents.json'), 'utf8'),
  );
  for (const image of contents.images) {
    const size = parseFloat(image.size) * parseInt(image.scale);
    await render('full', size, path.join(appIcon, image.filename), {
      opaque: true,
    });
  }

  await browser.close();
})();

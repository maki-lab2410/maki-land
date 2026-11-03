import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const outDir = path.resolve(process.cwd(), 'assets');
fs.mkdirSync(outDir, { recursive: true });

// CRC32 helper for pure-Node PNG encoding
const crcTable = new Uint32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) {
    c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
  }
  crcTable[n] = c >>> 0;
}

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const typeBuf = Buffer.from(type, 'ascii');
  const lenBuf = Buffer.alloc(4);
  lenBuf.writeUInt32BE(data.length, 0);
  const crcInput = Buffer.concat([typeBuf, data]);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(crcInput), 0);
  return Buffer.concat([lenBuf, typeBuf, data, crcBuf]);
}

function encodePNG(width, height, rgba) {
  const raw = Buffer.alloc(height * (1 + width * 4));
  for (let y = 0; y < height; y++) {
    const rowStart = y * (1 + width * 4);
    raw[rowStart] = 0; // filter none
    rgba.copy(raw, rowStart + 1, y * width * 4, (y + 1) * width * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const idat = zlib.deflateSync(raw, { level: 9 });
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  return Buffer.concat([
    sig,
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', idat),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

function blend(rgba, w, h, x, y, r, g, b, a) {
  if (x < 0 || x >= w || y < 0 || y >= h || a <= 0) return;
  const idx = (y * w + x) * 4;
  const srcA = Math.min(1, Math.max(0, a));
  const dstA = rgba[idx + 3] / 255;
  const outA = srcA + dstA * (1 - srcA);
  if (outA <= 0) return;
  rgba[idx] = Math.round((r * srcA + rgba[idx] * dstA * (1 - srcA)) / outA);
  rgba[idx + 1] = Math.round((g * srcA + rgba[idx + 1] * dstA * (1 - srcA)) / outA);
  rgba[idx + 2] = Math.round((b * srcA + rgba[idx + 2] * dstA * (1 - srcA)) / outA);
  rgba[idx + 3] = Math.round(outA * 255);
}

function fillEllipse(rgba, size, cx, cy, rx, ry, r, g, b, a = 1) {
  const minX = Math.max(0, Math.floor(cx - rx - 1));
  const maxX = Math.min(size - 1, Math.ceil(cx + rx + 1));
  const minY = Math.max(0, Math.floor(cy - ry - 1));
  const maxY = Math.min(size - 1, Math.ceil(cy + ry + 1));
  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const dx = (x + 0.5 - cx) / rx;
      const dy = (y + 0.5 - cy) / ry;
      const d = Math.hypot(dx, dy);
      if (d <= 1.04) {
        const edge = Math.min(1, Math.max(0, (1.04 - d) * Math.min(rx, ry)));
        blend(rgba, size, size, x, y, r, g, b, a * edge);
      }
    }
  }
}

function fillRoundRect(rgba, size, x0, y0, rw, rh, rad, r, g, b, a = 1) {
  const minX = Math.max(0, Math.floor(x0 - 1));
  const maxX = Math.min(size - 1, Math.ceil(x0 + rw + 1));
  const minY = Math.max(0, Math.floor(y0 - 1));
  const maxY = Math.min(size - 1, Math.ceil(y0 + rh + 1));
  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const px = x + 0.5;
      const py = y + 0.5;
      const qx = Math.max(x0 + rad, Math.min(x0 + rw - rad, px));
      const qy = Math.max(y0 + rad, Math.min(y0 + rh - rad, py));
      const dist = Math.hypot(px - qx, py - qy);
      if (dist <= rad + 0.8) {
        const edge = Math.min(1, Math.max(0, rad + 0.8 - dist));
        blend(rgba, size, size, x, y, r, g, b, a * edge);
      }
    }
  }
}

function renderMakiIcon(size, withSquircleBg = true) {
  const rgba = Buffer.alloc(size * size * 4, 0);
  const s = size;

  if (withSquircleBg) {
    // Cozy dark espresso-slate rounded badge so icon pops on both light & dark Windows 10/11 taskbars
    fillRoundRect(rgba, s, s * 0.05, s * 0.05, s * 0.90, s * 0.90, s * 0.22, 24, 22, 28, 1);
    fillRoundRect(rgba, s, s * 0.075, s * 0.075, s * 0.85, s * 0.85, s * 0.20, 38, 32, 36, 1);
  }

  // Cute ears (outline + fill)
  fillEllipse(rgba, s, s * 0.30, s * 0.37, s * 0.095, s * 0.11, 58, 33, 15, 1);
  fillEllipse(rgba, s, s * 0.70, s * 0.37, s * 0.095, s * 0.11, 58, 33, 15, 1);
  fillEllipse(rgba, s, s * 0.30, s * 0.37, s * 0.072, s * 0.085, 102, 60, 34, 1);
  fillEllipse(rgba, s, s * 0.70, s * 0.37, s * 0.072, s * 0.085, 102, 60, 34, 1);
  fillEllipse(rgba, s, s * 0.30, s * 0.38, s * 0.042, s * 0.05, 255, 130, 145, 0.7);
  fillEllipse(rgba, s, s * 0.70, s * 0.38, s * 0.042, s * 0.05, 255, 130, 145, 0.7);

  // Chubby capybara head/body loaf
  fillRoundRect(rgba, s, s * 0.21, s * 0.30, s * 0.58, s * 0.56, s * 0.25, 58, 33, 15, 1);
  fillRoundRect(rgba, s, s * 0.235, s * 0.325, s * 0.53, s * 0.51, s * 0.23, 198, 128, 74, 1);

  // Belly cream
  fillEllipse(rgba, s, s * 0.50, s * 0.73, s * 0.16, s * 0.11, 236, 198, 156, 0.9);

  // Rosy cheeks
  fillEllipse(rgba, s, s * 0.31, s * 0.56, s * 0.06, s * 0.036, 255, 118, 138, 0.75);
  fillEllipse(rgba, s, s * 0.69, s * 0.56, s * 0.06, s * 0.036, 255, 118, 138, 0.75);

  // Glossy eyes
  fillEllipse(rgba, s, s * 0.36, s * 0.49, s * 0.045, s * 0.05, 34, 18, 10, 1);
  fillEllipse(rgba, s, s * 0.64, s * 0.49, s * 0.045, s * 0.05, 34, 18, 10, 1);
  fillEllipse(rgba, s, s * 0.348, s * 0.475, s * 0.017, s * 0.017, 255, 255, 255, 1);
  fillEllipse(rgba, s, s * 0.628, s * 0.475, s * 0.017, s * 0.017, 255, 255, 255, 1);

  // Snout pad
  fillRoundRect(rgba, s, s * 0.39, s * 0.48, s * 0.22, s * 0.19, s * 0.09, 58, 33, 15, 1);
  fillRoundRect(rgba, s, s * 0.405, s * 0.495, s * 0.19, s * 0.16, s * 0.078, 105, 62, 36, 1);
  fillEllipse(rgba, s, s * 0.46, s * 0.535, s * 0.016, s * 0.014, 42, 22, 10, 1);
  fillEllipse(rgba, s, s * 0.54, s * 0.535, s * 0.016, s * 0.014, 42, 22, 10, 1);

  // Signature Yuzu Orange on Maki's head!
  fillEllipse(rgba, s, s * 0.50, s * 0.245, s * 0.125, s * 0.098, 58, 33, 15, 1);
  fillEllipse(rgba, s, s * 0.50, s * 0.245, s * 0.105, s * 0.080, 255, 146, 22, 1);
  fillEllipse(rgba, s, s * 0.47, s * 0.225, s * 0.032, s * 0.022, 255, 235, 180, 0.9);
  // Green yuzu leaf
  fillEllipse(rgba, s, s * 0.56, s * 0.155, s * 0.052, s * 0.026, 62, 205, 84, 1);

  return encodePNG(s, s, rgba);
}

function buildICO(pngBuffersWithSizes) {
  const count = pngBuffersWithSizes.length;
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // ICO type
  header.writeUInt16LE(count, 4);

  const dirEntries = [];
  let offset = 6 + count * 16;
  for (const { size, png } of pngBuffersWithSizes) {
    const entry = Buffer.alloc(16);
    entry[0] = size >= 256 ? 0 : size;
    entry[1] = size >= 256 ? 0 : size;
    entry[2] = 0;
    entry[3] = 0;
    entry.writeUInt16LE(1, 4); // planes
    entry.writeUInt16LE(32, 6); // bpp
    entry.writeUInt32LE(png.length, 8);
    entry.writeUInt32LE(offset, 12);
    dirEntries.push(entry);
    offset += png.length;
  }

  return Buffer.concat([header, ...dirEntries, ...pngBuffersWithSizes.map((x) => x.png)]);
}

const sizes = [16, 32, 48, 256];
const entries = sizes.map((sz) => ({ size: sz, png: renderMakiIcon(sz, true) }));
const icoBuf = buildICO(entries);

fs.writeFileSync(path.join(outDir, 'icon.ico'), icoBuf);
fs.writeFileSync(path.join(outDir, 'icon.png'), entries[3].png);
fs.writeFileSync(path.join(outDir, 'tray.png'), renderMakiIcon(32, false));

console.log('Generated assets/icon.ico, assets/icon.png, and assets/tray.png');

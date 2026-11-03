import React, { useEffect, useRef, useState } from 'react';
import {
  CapyActionType,
  CapyMascotModel,
  CapyRole,
  isIdleShowActivity,
} from '../../shared/types';

export interface Capybara2DProps {
  width: number;
  height: number;
  role?: CapyRole;
  action?: CapyActionType;
  eatingEmoji?: string;
  orangesOnHead?: number;
  isOnsen?: boolean;
  isListeningMusic?: boolean;
  isFocusing?: boolean;
  isDangling?: boolean;
  isMouthOpenForDrop?: boolean;
  lookVector?: { x: number; y: number };
  lastSquishTime?: number;
  facingRight?: boolean;
  mascotModel?: CapyMascotModel;
  nameBadge?: string;
  onClick?: (e: React.MouseEvent) => void;
  style?: React.CSSProperties;
}

function roundRectPath(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number
) {
  const rad = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, rad);
}

function ellipsePath(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number
) {
  ctx.beginPath();
  ctx.ellipse(x + w / 2, y + h / 2, Math.max(0.1, w / 2), Math.max(0.1, h / 2), 0, 0, Math.PI * 2);
}

export const Capybara2DCanvas: React.FC<Capybara2DProps> = ({
  width,
  height,
  role = 'habitat',
  action = 'chill',
  eatingEmoji = '🍊',
  orangesOnHead = 1,
  isOnsen = false,
  isListeningMusic = false,
  isDangling = false,
  isMouthOpenForDrop = false,
  lookVector = { x: 0, y: 0 },
  lastSquishTime = 0,
  facingRight = false,
  mascotModel = 'classic',
  nameBadge = 'maki',
  onClick,
  style,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [hovering, setHovering] = useState(false);

  const propsRef = useRef({
    width,
    height,
    role,
    action,
    eatingEmoji,
    orangesOnHead,
    isOnsen,
    isListeningMusic,
    isDangling,
    isMouthOpenForDrop,
    lookVector,
    lastSquishTime,
    facingRight,
    mascotModel,
    nameBadge,
    hovering,
  });
  propsRef.current = {
    width,
    height,
    role,
    action,
    eatingEmoji,
    orangesOnHead,
    isOnsen,
    isListeningMusic,
    isDangling,
    isMouthOpenForDrop,
    lookVector,
    lastSquishTime,
    facingRight,
    mascotModel,
    nameBadge,
    hovering,
  };

  useEffect(() => {
    let rafId = 0;
    let lastDrawMs = 0;

    const loop = (nowMs: number) => {
      rafId = requestAnimationFrame(loop);
      const p = propsRef.current;
      const calm =
        (p.action === 'chill' || p.action === 'sleeping') &&
        !p.isMouthOpenForDrop &&
        !p.hovering &&
        !p.isDangling &&
        !p.isListeningMusic;
      const minInterval = calm ? 1000 / 15 : 1000 / 30;
      if (nowMs - lastDrawMs < minInterval) return;
      lastDrawMs = nowMs;

      const canvas = canvasRef.current;
      if (!canvas) return;
      const dpr = window.devicePixelRatio || 1;
      const targetW = Math.round(p.width * dpr);
      const targetH = Math.round(p.height * dpr);
      if (canvas.width !== targetW || canvas.height !== targetH) {
        canvas.width = targetW;
        canvas.height = targetH;
      }

      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      ctx.save();
      ctx.scale(dpr, dpr);
      ctx.clearRect(0, 0, p.width, p.height);
      drawMaki(ctx, p, Date.now() / 1000);
      ctx.restore();
    };

    rafId = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafId);
  }, []);

  return (
    <canvas
      ref={canvasRef}
      style={{ width, height, display: 'block', ...style }}
      onMouseEnter={() => setHovering(true)}
      onMouseLeave={() => setHovering(false)}
      onClick={onClick}
    />
  );
};

function drawMaki(
  ctx: CanvasRenderingContext2D,
  p: {
    width: number;
    height: number;
    role: CapyRole;
    action: CapyActionType;
    eatingEmoji: string;
    orangesOnHead: number;
    isOnsen: boolean;
    isListeningMusic: boolean;
    isDangling: boolean;
    isMouthOpenForDrop: boolean;
    lookVector: { x: number; y: number };
    lastSquishTime: number;
    facingRight: boolean;
    mascotModel: CapyMascotModel;
    nameBadge?: string;
    hovering: boolean;
  },
  t: number
) {
  const w = p.width;
  const h = p.height;
  const s = Math.min(w * 0.88, h * 0.74);
  if (s <= 8) return;

  const strokeW = Math.max(1.1, s * 0.025);
  const isPlushie = p.mascotModel === 'plushie';
  const outlineColor = isPlushie ? 'rgb(97, 66, 46)' : 'rgb(59, 33, 15)';
  const furTop = isPlushie ? 'rgb(250, 245, 232)' : 'rgb(204, 133, 77)';
  const furBottom = isPlushie ? 'rgb(237, 222, 199)' : 'rgb(166, 99, 51)';
  const bellyCream = 'rgba(235, 196, 156, 0.84)';
  const snoutDark = isPlushie ? 'rgb(250, 133, 26)' : 'rgb(99, 59, 33)';
  const snoutHighlight = isPlushie ? 'rgba(255, 173, 71, 0.65)' : 'rgba(125, 79, 48, 0.65)';
  const pawColor = isPlushie ? 'rgb(240, 224, 204)' : snoutDark;
  const footColor = isPlushie ? 'rgb(237, 219, 196)' : snoutDark;

  const cx = w * 0.5;
  const groundY = h * 0.92;

  const dt = t - p.lastSquishTime;
  const squishWave = dt >= 0 && dt < 0.52 ? Math.exp(-dt * 7.8) * Math.sin(dt * 25.0) : 0;

  let breathScaleX = 1.0;
  let breathScaleY = 1.0;
  let swayDeg = 0;

  if (p.isDangling) {
    swayDeg = Math.sin(t * 9.0) * 5.5;
    breathScaleX = 0.96;
    breathScaleY = 1.04;
  } else if (p.action === 'brushed') {
    breathScaleX = 1.14 + Math.sin(t * 10.0) * 0.02;
    breathScaleY = 0.87 - Math.sin(t * 10.0) * 0.015;
    swayDeg = Math.sin(t * 8.0) * 2.5;
  } else if (p.action === 'stretching') {
    const st = Math.sin(t * 5.2);
    swayDeg = st * 10.5;
    breathScaleX = 0.96 + Math.abs(st) * 0.04;
    breathScaleY = 1.04 - Math.abs(st) * 0.02;
  } else if (p.action === 'dizzy') {
    swayDeg = Math.sin(t * 14.0) * 6.0;
  } else if (p.action === 'ticklish') {
    swayDeg = Math.sin(t * 20.0) * 4.5;
    breathScaleX = 1.03;
    breathScaleY = 0.97;
  } else if (p.isListeningMusic && (p.role === 'djMusic' || p.role === 'habitat')) {
    const beat = Math.abs(Math.sin(t * 5.6));
    breathScaleX = 1.0 + (1.0 - beat) * 0.035;
    breathScaleY = 0.965 + beat * 0.04;
    swayDeg = Math.sin(t * 2.8) * 3.5;
  } else if (p.action === 'walking') {
    const step = Math.abs(Math.sin(t * 11.0));
    breathScaleX = 1.01;
    breathScaleY = 0.975 + step * 0.04;
    swayDeg = Math.sin(t * 11.0) * 4.2;
  } else {
    const b = Math.sin(t * 2.3);
    breathScaleX = 1.0 + b * 0.016;
    breathScaleY = 1.0 - b * 0.016;
    if (p.hovering) swayDeg = Math.sin(t * 4.0) * 1.6;
  }

  const totalSX = breathScaleX + squishWave * 0.14;
  const totalSY = breathScaleY - squishWave * 0.12;

  const butterflyPos = {
    x: Math.sin(t * 2.3) * s * 0.36,
    y: -s * 0.56 + Math.sin(t * 4.6) * s * 0.12,
  };

  const dirSign = p.facingRight ? 1.0 : -1.0;
  let gx = 0;
  let gy = 0;
  if (p.action === 'butterflyChase') {
    gx = Math.max(-1, Math.min(1, butterflyPos.x / (s * 0.36)));
    gy = Math.max(-1, Math.min(1, (butterflyPos.y + s * 0.45) / (s * 0.25)));
  } else if (p.action === 'readingBook') {
    gx = Math.sin(t * 2.4) * 0.55;
    gy = 0.55;
  } else if (p.action === 'typingLaptop') {
    gx = Math.sin(t * 4.5) * 0.28;
    gy = 0.5;
  } else if (p.action === 'jugglingOranges') {
    gx = -Math.sin(t * 3.4) * 0.55;
    gy = -0.68;
  } else if (p.action === 'walking') {
    gx = dirSign * 0.65;
    gy = 0;
  } else {
    const noLook = p.lookVector.x === 0 && p.lookVector.y === 0;
    gx = Math.max(-1, Math.min(1, p.lookVector.x + (noLook ? dirSign * 0.25 : 0)));
    gy = Math.max(-1, Math.min(1, p.lookVector.y));
  }

  // 1. Soft 3-Layer Ambient Contact Shadow + Walking Dust Puffs
  if (!p.isDangling) {
    const baseW = s * (p.isOnsen ? 0.78 : 0.58) * totalSX;
    const baseH = s * 0.082;
    const shadowCenterY = groundY - baseH * 0.45;

    ellipsePath(ctx, cx - baseW * 0.59, shadowCenterY - baseH * 0.21, baseW * 1.18, baseH * 1.4);
    ctx.fillStyle = 'rgba(45, 28, 16, 0.035)';
    ctx.fill();

    ellipsePath(ctx, cx - baseW * 0.44, shadowCenterY, baseW * 0.88, baseH * 0.92);
    ctx.fillStyle = 'rgba(38, 24, 14, 0.055)';
    ctx.fill();

    ellipsePath(ctx, cx - baseW * 0.29, shadowCenterY + baseH * 0.12, baseW * 0.58, baseH * 0.55);
    ctx.fillStyle = 'rgba(30, 18, 10, 0.075)';
    ctx.fill();

    if (p.action === 'walking' && s > 40) {
      for (let i = 0; i < 2; i++) {
        const phase = (t * 2.8 + i * 0.5) % 1.0;
        const trailDir = p.facingRight ? -1.0 : 1.0;
        const px = cx + trailDir * (s * 0.22 + phase * s * 0.16);
        const py = groundY - phase * s * 0.08;
        const pr = s * (0.045 - phase * 0.03);
        if (pr > 0.5) {
          ellipsePath(ctx, px - pr, py - pr, pr * 2, pr * 2);
          ctx.fillStyle = `rgba(255, 255, 255, ${(1 - phase) * 0.45})`;
          ctx.fill();
        }
      }
    }
  }

  // Grounded Transform
  ctx.save();
  ctx.translate(cx, groundY);
  ctx.rotate((swayDeg * Math.PI) / 180);
  ctx.scale(totalSX, totalSY);

  const bodyW = s * 0.58;
  const bodyH = s * 0.64;
  const headCenterY = -bodyH * 0.66;
  const faceShiftX = gx * s * 0.048;
  const faceShiftY = gy * s * 0.032;

  // 2. Back Onsen Water
  if (p.isOnsen) {
    const tubW = s * 0.78;
    const tubH = s * 0.34;
    ellipsePath(ctx, -tubW * 0.46, -tubH * 0.98, tubW * 0.92, tubH * 0.36);
    ctx.fillStyle = 'rgb(71, 217, 230)';
    ctx.fill();
  }

  // 3. Cute Rounded Capybara Ears
  const earTwitch = Math.sin(t * 1.9) > 0.93 ? Math.sin(t * 28.0) * 8.0 : 0.0;
  const earY = headCenterY - s * 0.17 - faceShiftY * 0.35;
  const earSpread = bodyW * 0.35;
  for (const side of [-1, 1]) {
    ctx.save();
    ctx.translate(side * earSpread - faceShiftX * 0.35, earY);
    ctx.rotate(((side * (22.0 + (side > 0 ? earTwitch : 0))) * Math.PI) / 180);
    const ew = s * 0.13;
    const eh = s * 0.16;

    if (isPlushie) {
      roundRectPath(ctx, -ew * 0.5, -eh * 0.6, ew, eh, ew * 0.48);
      ctx.fillStyle = furTop;
      ctx.fill();
      ctx.lineWidth = strokeW;
      ctx.strokeStyle = outlineColor;
      ctx.stroke();

      roundRectPath(ctx, -ew * 0.5, -eh * 0.6, ew, eh * 0.44, ew * 0.48);
      ctx.fillStyle = 'rgb(133, 77, 41)';
      ctx.fill();

      roundRectPath(ctx, -ew * 0.28, -eh * 0.38, ew * 0.56, eh * 0.56, ew * 0.28);
      ctx.fillStyle = 'rgba(255, 122, 140, 0.55)';
      ctx.fill();
    } else {
      roundRectPath(ctx, -ew * 0.5, -eh * 0.6, ew, eh, ew * 0.48);
      ctx.fillStyle = snoutDark;
      ctx.fill();
      ctx.lineWidth = strokeW;
      ctx.strokeStyle = outlineColor;
      ctx.stroke();

      roundRectPath(ctx, -ew * 0.26, -eh * 0.36, ew * 0.52, eh * 0.52, ew * 0.25);
      ctx.fillStyle = 'rgba(255, 122, 140, 0.42)';
      ctx.fill();
    }
    ctx.restore();
  }

  // Scholar Notes Pencil on Ear
  if (p.role === 'scholarNotes' && s > 30) {
    ctx.save();
    ctx.translate(earSpread + s * 0.04, earY + s * 0.02);
    ctx.rotate((32 * Math.PI) / 180);
    const pw = s * 0.2;
    const ph = s * 0.048;
    roundRectPath(ctx, -pw * 0.5, -ph * 0.5, pw * 0.75, ph, 2);
    ctx.fillStyle = '#ffd43b';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.7;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo(pw * 0.25, -ph * 0.5);
    ctx.lineTo(pw * 0.46, 0);
    ctx.lineTo(pw * 0.25, ph * 0.5);
    ctx.closePath();
    ctx.fillStyle = 'rgb(235, 196, 156)';
    ctx.fill();
    ctx.restore();
  }

  // 4. Chubby Mochi-Loaf Capybara Body
  const topY = -bodyH - s * 0.05;
  const botY = -s * 0.02;
  ctx.beginPath();
  ctx.moveTo(0, topY);
  ctx.bezierCurveTo(bodyW * 0.44, topY, bodyW * 0.54, -bodyH * 0.65, bodyW * 0.52, -bodyH * 0.3);
  ctx.bezierCurveTo(bodyW * 0.52, -bodyH * 0.06, bodyW * 0.44, botY, bodyW * 0.3, botY);
  ctx.lineTo(-bodyW * 0.3, botY);
  ctx.bezierCurveTo(-bodyW * 0.44, botY, -bodyW * 0.52, -bodyH * 0.06, -bodyW * 0.52, -bodyH * 0.3);
  ctx.bezierCurveTo(-bodyW * 0.54, -bodyH * 0.65, -bodyW * 0.44, topY, 0, topY);
  ctx.closePath();

  const bodyGrad = ctx.createLinearGradient(0, topY, 0, botY);
  bodyGrad.addColorStop(0, furTop);
  bodyGrad.addColorStop(1, furBottom);
  ctx.fillStyle = bodyGrad;
  ctx.fill();

  if (isPlushie) {
    // White cotton T-shirt with embroidered royal-blue "maki" lettering
    const shirtW = bodyW * 0.74;
    const shirtH = bodyH * 0.38;
    const shirtY = -bodyH * 0.43;
    const shirtX = -shirtW * 0.5 + faceShiftX * 0.2;
    roundRectPath(ctx, shirtX, shirtY, shirtW, shirtH, s * 0.055);
    ctx.fillStyle = '#ffffff';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.8;
    ctx.strokeStyle = 'rgba(97, 66, 46, 0.52)';
    ctx.stroke();

    // Crew-neck collar seam
    ctx.beginPath();
    ctx.moveTo(-shirtW * 0.26 + faceShiftX * 0.2, shirtY);
    ctx.quadraticCurveTo(
      faceShiftX * 0.2,
      shirtY + shirtH * 0.24,
      shirtW * 0.26 + faceShiftX * 0.2,
      shirtY
    );
    ctx.lineWidth = strokeW * 0.7;
    ctx.strokeStyle = 'rgba(97, 66, 46, 0.48)';
    ctx.stroke();

    const isMokoPlush = p.nameBadge === 'moko';
    ctx.fillStyle = isMokoPlush ? 'rgb(12, 150, 105)' : 'rgb(20, 92, 224)';
    ctx.font = `800 ${Math.max(6, s * 0.105)}px "Segoe UI Rounded", "Arial Rounded MT Bold", "Segoe UI", sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(p.nameBadge || 'maki', faceShiftX * 0.2, shirtY + shirtH * 0.6);
  } else {
    // Natural belly cream patch underneath
    const bellyW = bodyW * 0.54;
    const bellyH = bodyH * 0.42;
    ellipsePath(ctx, -bellyW * 0.5 + faceShiftX * 0.25, -bellyH - s * 0.03, bellyW, bellyH);
    ctx.fillStyle = bellyCream;
    ctx.fill();

    // Classic Maki's signature cozy coffee-latte cotton tee with espresso trim & warm amber "maki" embroidery!
    const shirtW = bodyW * 0.74;
    const shirtH = bodyH * 0.38;
    const shirtY = -bodyH * 0.43;
    const shirtX = -shirtW * 0.5 + faceShiftX * 0.2;
    roundRectPath(ctx, shirtX, shirtY, shirtW, shirtH, s * 0.055);
    ctx.fillStyle = 'rgb(250, 243, 230)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.8;
    ctx.strokeStyle = 'rgba(59, 33, 15, 0.58)';
    ctx.stroke();

    // Crew-neck collar seam
    ctx.beginPath();
    ctx.moveTo(-shirtW * 0.26 + faceShiftX * 0.2, shirtY);
    ctx.quadraticCurveTo(
      faceShiftX * 0.2,
      shirtY + shirtH * 0.24,
      shirtW * 0.26 + faceShiftX * 0.2,
      shirtY
    );
    ctx.lineWidth = strokeW * 0.7;
    ctx.strokeStyle = 'rgba(59, 33, 15, 0.55)';
    ctx.stroke();

    const isMokoClassic = p.nameBadge === 'moko';
    ctx.fillStyle = isMokoClassic ? 'rgb(34, 139, 94)' : 'rgb(199, 97, 31)';
    ctx.font = `800 ${Math.max(6, s * 0.105)}px "Segoe UI Rounded", "Arial Rounded MT Bold", "Segoe UI", sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(p.nameBadge || 'maki', faceShiftX * 0.2, shirtY + shirtH * 0.6);
  }

  // Re-stroke body outline cleanly
  ctx.beginPath();
  ctx.moveTo(0, topY);
  ctx.bezierCurveTo(bodyW * 0.44, topY, bodyW * 0.54, -bodyH * 0.65, bodyW * 0.52, -bodyH * 0.3);
  ctx.bezierCurveTo(bodyW * 0.52, -bodyH * 0.06, bodyW * 0.44, botY, bodyW * 0.3, botY);
  ctx.lineTo(-bodyW * 0.3, botY);
  ctx.bezierCurveTo(-bodyW * 0.44, botY, -bodyW * 0.52, -bodyH * 0.06, -bodyW * 0.52, -bodyH * 0.3);
  ctx.bezierCurveTo(-bodyW * 0.54, -bodyH * 0.65, -bodyW * 0.44, topY, 0, topY);
  ctx.closePath();
  ctx.lineWidth = strokeW;
  ctx.strokeStyle = outlineColor;
  ctx.stroke();

  // 5. Lower Feet
  if (!p.isOnsen) {
    const footW = s * 0.14;
    const footH = s * 0.085;
    for (const side of [-1, 1]) {
      let liftY = 0;
      if (p.isDangling) {
        liftY = Math.sin(t * 16.0 + side * 1.5) * s * 0.045 + s * 0.03;
      } else if (p.action === 'walking') {
        liftY = -Math.max(0, Math.sin(t * 11.0 + (side > 0 ? Math.PI : 0))) * s * 0.045;
      }
      const fx = side * bodyW * 0.26;
      const fy = -footH * 0.65 + liftY;
      roundRectPath(ctx, fx - footW * 0.5, fy, footW, footH, footH * 0.48);
      ctx.fillStyle = footColor;
      ctx.fill();
      ctx.lineWidth = strokeW * 0.85;
      ctx.strokeStyle = outlineColor;
      ctx.stroke();
    }
  }

  // 6. Pilot Red Scarf
  if (p.role === 'pilotLauncher') {
    const scarfY = -bodyH * 0.43;
    roundRectPath(ctx, -bodyW * 0.44, scarfY, bodyW * 0.88, s * 0.085, s * 0.04);
    ctx.fillStyle = 'rgb(235, 56, 56)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    const flutter = Math.sin(t * 7.5) * s * 0.025;
    ctx.beginPath();
    ctx.moveTo(bodyW * 0.34, scarfY + s * 0.02);
    ctx.quadraticCurveTo(bodyW * 0.48, scarfY - s * 0.02, bodyW * 0.6, scarfY + s * 0.03 + flutter);
    ctx.lineTo(bodyW * 0.56, scarfY + s * 0.11 + flutter);
    ctx.lineTo(bodyW * 0.32, scarfY + s * 0.07);
    ctx.closePath();
    ctx.fillStyle = 'rgb(219, 46, 46)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.75;
    ctx.stroke();
  }

  // 7. Rosy Kawaii Cheeks
  const strongBlush =
    p.action === 'happyPet' ||
    p.action === 'brushed' ||
    p.action === 'sippingTea' ||
    p.action === 'ticklish' ||
    p.action === 'dizzy' ||
    p.isOnsen ||
    p.hovering;
  const cheekAlpha = strongBlush ? 0.64 : 0.28;
  const cheekY = headCenterY + s * 0.05 + faceShiftY;
  const cheekSpread = bodyW * 0.34;
  for (const side of [-1, 1]) {
    ellipsePath(
      ctx,
      faceShiftX + side * cheekSpread - s * 0.055,
      cheekY - s * 0.032,
      s * 0.11,
      s * 0.064
    );
    ctx.fillStyle = `rgba(255, 122, 140, ${cheekAlpha})`;
    ctx.fill();
  }

  // 8. Expressive 2D Eyes
  const eyeY = headCenterY - s * 0.035 + faceShiftY * 0.85;
  const eyeSpread = bodyW * 0.255;
  const blinkCycle = t % 3.9;
  const isBlinking = blinkCycle > 3.74 && blinkCycle < 3.88;

  for (const side of [-1, 1]) {
    const ex = faceShiftX * 0.85 + side * eyeSpread;
    drawEye(ctx, ex, eyeY, side, s, strokeW, outlineColor, gx, gy, isBlinking, p.action, p.isOnsen, p.isMouthOpenForDrop, p.isDangling, p.hovering, t);
  }

  // Coding glasses
  if (p.action === 'typingLaptop' && p.role !== 'scholarNotes' && s > 34) {
    const gxCenter = faceShiftX * 0.85;
    const gr = s * 0.068;
    for (const side of [-1, 1]) {
      ellipsePath(ctx, gxCenter + side * eyeSpread - gr, eyeY - gr, gr * 2, gr * 2);
      ctx.lineWidth = strokeW * 0.8;
      ctx.strokeStyle = 'rgba(34, 211, 238, 0.85)';
      ctx.stroke();
    }
  }

  // 9. Snout Pad + Nostrils + Mouth
  let snoutW = s * (isPlushie ? 0.24 : 0.22);
  let snoutH = s * (isPlushie ? 0.22 : 0.19);
  if (p.action === 'eating') {
    const chew = Math.sin(t * 15.0);
    snoutW += chew * s * 0.018;
    snoutH -= chew * s * 0.014;
  }
  const snoutX = faceShiftX * 1.15;
  const snoutY = headCenterY + s * (isPlushie ? 0.04 : 0.045) + faceShiftY * 1.05;
  const snoutCorner = isPlushie ? snoutW * 0.48 : snoutW * 0.42;

  roundRectPath(ctx, snoutX - snoutW * 0.5, snoutY - snoutH * 0.42, snoutW, snoutH, snoutCorner);
  ctx.fillStyle = snoutDark;
  ctx.fill();

  if (!isPlushie) {
    roundRectPath(
      ctx,
      snoutX - snoutW * 0.3,
      snoutY - snoutH * 0.33,
      snoutW * 0.6,
      snoutH * 0.22,
      snoutW * 0.2
    );
    ctx.fillStyle = snoutHighlight;
    ctx.fill();

    roundRectPath(ctx, snoutX - snoutW * 0.5, snoutY - snoutH * 0.42, snoutW, snoutH, snoutCorner);
    ctx.lineWidth = strokeW * 0.9;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    const nostrilR = Math.max(1.2, s * 0.017);
    for (const side of [-1, 1]) {
      ellipsePath(
        ctx,
        snoutX + side * snoutW * 0.21 - nostrilR,
        snoutY - snoutH * 0.16 - nostrilR,
        nostrilR * 2,
        nostrilR * 1.6
      );
      ctx.fillStyle = outlineColor;
      ctx.fill();
    }
  } else {
    roundRectPath(ctx, snoutX - snoutW * 0.5, snoutY - snoutH * 0.42, snoutW, snoutH, snoutCorner);
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = 'rgba(97, 66, 46, 0.70)';
    ctx.stroke();
  }

  drawMouth(
    ctx,
    snoutX,
    snoutY,
    snoutW,
    snoutH,
    s,
    strokeW,
    outlineColor,
    isPlushie,
    p.action,
    p.isMouthOpenForDrop,
    p.isDangling
  );

  // Poppable Sleep Bubble
  if (p.action === 'sleeping' && s > 34) {
    const bubR = s * (0.065 + (Math.sin(t * 1.8) + 1.0) * 0.032);
    const bx = snoutX + snoutW * 0.55;
    const by = snoutY - snoutH * 0.22 - bubR * 0.3;
    ellipsePath(ctx, bx - bubR, by - bubR, bubR * 2, bubR * 2);
    ctx.fillStyle = 'rgba(34, 211, 238, 0.32)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.65;
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.78)';
    ctx.stroke();

    ellipsePath(ctx, bx - bubR * 0.45, by - bubR * 0.45, bubR * 0.4, bubR * 0.4);
    ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
    ctx.fill();
  }

  // 10. Front Paws & Props
  drawFrontPawsAndProps(
    ctx,
    bodyW,
    bodyH,
    s,
    strokeW,
    pawColor,
    outlineColor,
    p.action,
    p.eatingEmoji,
    p.role,
    p.isMouthOpenForDrop,
    p.isDangling,
    p.isListeningMusic,
    t
  );

  // 11. Front Wooden Hinoki Onsen Tub
  if (p.isOnsen) {
    drawOnsenTubFront(ctx, s, strokeW, outlineColor, t);
  }

  // 12. Costumes, Matte Black DJ Headphones & Stacked Oranges
  drawCostumeHeadgear(
    ctx,
    headCenterY,
    topY,
    bodyW,
    eyeY,
    eyeSpread,
    faceShiftX,
    faceShiftY,
    s,
    strokeW,
    outlineColor,
    p.role,
    p.isListeningMusic,
    p.isOnsen,
    p.orangesOnHead,
    p.action,
    t
  );

  // 13. Fur Brush Comb
  if (p.action === 'brushed' && s > 34) {
    const bx = Math.sin(t * 11.0) * bodyW * 0.26;
    const by = topY - s * 0.03;
    roundRectPath(ctx, bx - s * 0.11, by - s * 0.04, s * 0.22, s * 0.065, 5);
    ctx.fillStyle = '#f472b6';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.75;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
  }

  // 14. Dizzy Stars
  if (p.action === 'dizzy' && s > 28) {
    for (let i = 0; i < 3; i++) {
      const ang = t * 5.2 + i * ((Math.PI * 2) / 3);
      const sx = Math.cos(ang) * bodyW * 0.42;
      const sy = topY - s * 0.06 + Math.sin(ang) * s * 0.045;
      ellipsePath(ctx, sx - s * 0.035, sy - s * 0.035, s * 0.07, s * 0.07);
      ctx.fillStyle = '#ffd43b';
      ctx.fill();
      ctx.lineWidth = strokeW * 0.6;
      ctx.strokeStyle = outlineColor;
      ctx.stroke();
    }
  }

  // 15. Foreground Aerial Props (Juggling 3 Oranges, Butterfly, Bubbles)
  if (s > 30) {
    drawForegroundAerialProps(ctx, bodyH, snoutX, snoutY, s, strokeW, outlineColor, butterflyPos, p.action, t);
  }

  ctx.restore();
}

function drawEye(
  ctx: CanvasRenderingContext2D,
  cx: number,
  cy: number,
  side: number,
  s: number,
  strokeW: number,
  outlineColor: string,
  gx: number,
  gy: number,
  isBlinking: boolean,
  action: CapyActionType,
  isOnsen: boolean,
  isMouthOpenForDrop: boolean,
  isDangling: boolean,
  hovering: boolean,
  t: number
) {
  const r = s * 0.046;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';

  if (action === 'dizzy') {
    ctx.beginPath();
    const turns = 12;
    for (let step = 0; step <= turns; step++) {
      const prog = step / turns;
      const ang = prog * Math.PI * 3.5 + t * 10.0 * side;
      const rad = prog * r * 1.15;
      const px = cx + Math.cos(ang) * rad;
      const py = cy + Math.sin(ang) * rad;
      if (step === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    }
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
    return;
  }

  if (action === 'ticklish') {
    const dx = r * 1.05 * side;
    ctx.beginPath();
    ctx.moveTo(cx + dx, cy - r * 0.75);
    ctx.lineTo(cx - dx * 0.55, cy);
    ctx.lineTo(cx + dx, cy + r * 0.75);
    ctx.lineWidth = strokeW * 1.05;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
    return;
  }

  const isHappyArc =
    action === 'happyPet' ||
    action === 'brushed' ||
    action === 'swallowing' ||
    action === 'eating' ||
    isOnsen ||
    (action === 'sippingTea' && Math.sin(t * 2.2) > 0.15);

  if (isHappyArc) {
    ctx.beginPath();
    ctx.moveTo(cx - r, cy + r * 0.25);
    ctx.quadraticCurveTo(cx, cy - r * 1.05, cx + r, cy + r * 0.25);
    ctx.lineWidth = strokeW * 1.1;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
    return;
  }

  if (action === 'sleeping' || isBlinking) {
    ctx.beginPath();
    ctx.moveTo(cx - r, cy);
    ctx.quadraticCurveTo(cx, cy + r * 0.75, cx + r, cy);
    ctx.lineWidth = strokeW;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
    return;
  }

  const scaleMul =
    isMouthOpenForDrop || isDangling || action === 'butterflyChase'
      ? 1.16
      : hovering
      ? 1.08
      : 1.0;
  const er = r * scaleMul;
  ellipsePath(ctx, cx - er, cy - er * 1.08, er * 2, er * 2.16);
  ctx.fillStyle = 'rgb(36, 18, 10)';
  ctx.fill();

  const shineX = cx - er * 0.28 + gx * er * 0.34;
  const shineY = cy - er * 0.34 + gy * er * 0.28;
  ellipsePath(ctx, shineX - er * 0.34, shineY - er * 0.34, er * 0.68, er * 0.68);
  ctx.fillStyle = '#ffffff';
  ctx.fill();

  ellipsePath(ctx, cx + er * 0.22, cy + er * 0.24, er * 0.3, er * 0.3);
  ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
  ctx.fill();
}

function drawMouth(
  ctx: CanvasRenderingContext2D,
  mx: number,
  snoutY: number,
  snoutW: number,
  snoutH: number,
  s: number,
  strokeW: number,
  outlineColor: string,
  isPlushie: boolean,
  action: CapyActionType,
  isMouthOpenForDrop: boolean,
  isDangling: boolean
) {
  const philTop = snoutY - snoutH * (isPlushie ? 0.16 : 0.02);
  const mouthY = snoutY + snoutH * (isPlushie ? 0.2 : 0.24);
  ctx.lineCap = 'round';

  if (isPlushie) {
    const stitchW = snoutW * 0.32;
    ctx.beginPath();
    ctx.moveTo(mx - stitchW * 0.5, philTop);
    ctx.lineTo(mx + stitchW * 0.5, philTop);
    ctx.moveTo(mx, philTop);
    ctx.lineTo(mx, mouthY);
    ctx.lineWidth = strokeW * 1.15;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    if (isMouthOpenForDrop || isDangling || action === 'blowingBubbles') {
      const mw = snoutW * 0.28;
      const mh = snoutH * 0.26;
      ellipsePath(ctx, mx - mw * 0.5, mouthY - mh * 0.1, mw, mh);
      ctx.fillStyle = 'rgb(140, 41, 51)';
      ctx.fill();
      ctx.lineWidth = strokeW * 0.8;
      ctx.strokeStyle = outlineColor;
      ctx.stroke();
    }
    return;
  }

  ctx.beginPath();
  ctx.moveTo(mx, philTop);
  ctx.lineTo(mx, mouthY);
  ctx.lineWidth = strokeW * 0.85;
  ctx.strokeStyle = outlineColor;
  ctx.stroke();

  if (isMouthOpenForDrop || isDangling || action === 'blowingBubbles') {
    const mul = action === 'blowingBubbles' ? 0.26 : isMouthOpenForDrop ? 0.48 : 0.34;
    const mw = snoutW * mul;
    const mh = snoutH * mul;
    ellipsePath(ctx, mx - mw * 0.5, mouthY - mh * 0.2, mw, mh);
    ctx.fillStyle = 'rgb(140, 41, 51)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
    return;
  }

  if (action === 'dizzy') {
    ctx.beginPath();
    ctx.moveTo(mx - snoutW * 0.24, mouthY + 1);
    ctx.bezierCurveTo(
      mx - snoutW * 0.08,
      mouthY - s * 0.025,
      mx + snoutW * 0.08,
      mouthY + s * 0.03,
      mx + snoutW * 0.24,
      mouthY + 1
    );
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
    return;
  }

  const bigSmile =
    action === 'happyPet' ||
    action === 'brushed' ||
    action === 'jugglingOranges' ||
    action === 'stretching';
  const span = snoutW * (bigSmile ? 0.3 : 0.24);
  const dip = snoutH * (bigSmile ? 0.2 : 0.13);
  ctx.beginPath();
  ctx.moveTo(mx - span, mouthY);
  ctx.quadraticCurveTo(mx - span * 0.5, mouthY + dip, mx, mouthY);
  ctx.quadraticCurveTo(mx + span * 0.5, mouthY + dip, mx + span, mouthY);
  ctx.lineWidth = strokeW * 0.9;
  ctx.strokeStyle = outlineColor;
  ctx.stroke();
}

function drawFrontPawsAndProps(
  ctx: CanvasRenderingContext2D,
  bodyW: number,
  bodyH: number,
  s: number,
  strokeW: number,
  pawColor: string,
  outlineColor: string,
  action: CapyActionType,
  eatingEmoji: string,
  role: CapyRole,
  isMouthOpenForDrop: boolean,
  isDangling: boolean,
  isListeningMusic: boolean,
  t: number
) {
  const pawW = s * 0.12;
  const pawH = s * 0.095;
  const baseY = -bodyH * 0.33;

  for (const side of [-1, 1]) {
    ctx.save();
    let px = side * bodyW * 0.22;
    let py = baseY;
    let angleDeg = side * -14.0;

    if (isMouthOpenForDrop || isDangling) {
      px = side * bodyW * 0.38;
      py = baseY - s * 0.07;
      angleDeg = side * 35.0 + Math.sin(t * 14.0) * 10.0;
    } else if (action === 'stretching') {
      px = side * bodyW * 0.38;
      py = baseY - s * 0.15 + Math.sin(t * 5.2) * s * 0.03 * side;
      angleDeg = side * 48.0;
    } else if (action === 'jugglingOranges') {
      px = side * s * 0.25;
      py = baseY - s * 0.02 + Math.sin(t * 6.8 + (side > 0 ? Math.PI : 0)) * s * 0.055;
      angleDeg = side * 28.0;
    } else if (action === 'typingLaptop') {
      px = side * bodyW * 0.18;
      py = baseY + s * 0.06 + Math.sin(t * 25.0 + (side > 0 ? Math.PI : 0)) * s * 0.024;
      angleDeg = side * -8.0;
    } else if (action === 'sippingTea') {
      const sipLift = Math.max(0, Math.sin(t * 2.2)) * s * 0.07;
      px = side * bodyW * 0.13;
      py = baseY - sipLift;
    } else if (action === 'readingBook') {
      px = side * bodyW * 0.21;
      py = baseY + s * 0.02;
    } else if (action === 'happyPet' || action === 'ticklish' || (isListeningMusic && side < 0)) {
      px = side * bodyW * 0.32;
      py = baseY - s * 0.05 + Math.sin(t * 12.0 + side) * s * 0.025;
      angleDeg = side * 28.0;
    }

    ctx.translate(px, py);
    ctx.rotate((angleDeg * Math.PI) / 180);
    roundRectPath(ctx, -pawW * 0.5, -pawH * 0.5, pawW, pawH, pawH * 0.48);
    ctx.fillStyle = pawColor;
    ctx.fill();
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
    ctx.restore();
  }

  if (s <= 34) return;

  if (action === 'eating') {
    const chewOff = Math.sin(t * 15.0) * s * 0.015;
    ctx.font = `${Math.round(s * 0.18)}px "Segoe UI Emoji", sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(eatingEmoji || '🍊', 0, baseY - s * 0.02 + chewOff);
  } else if (action === 'sippingTea') {
    const sipLift = Math.max(0, Math.sin(t * 2.2)) * s * 0.07;
    const cupW = s * 0.15;
    const cupH = s * 0.15;
    const cupY = baseY - cupH * 0.5 - sipLift;
    roundRectPath(ctx, -cupW * 0.5, cupY, cupW, cupH, cupW * 0.26);
    ctx.fillStyle = 'rgb(143, 199, 133)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    const stPhase = (t * 0.9) % 1.0;
    const stY = cupY - s * 0.03 - stPhase * s * 0.11;
    ctx.beginPath();
    ctx.moveTo(0, stY + s * 0.05);
    ctx.quadraticCurveTo(s * 0.04, stY + s * 0.025, 0, stY);
    ctx.lineWidth = strokeW * 0.7;
    ctx.strokeStyle = `rgba(255, 255, 255, ${(1 - stPhase) * 0.7})`;
    ctx.stroke();
  } else if (action === 'typingLaptop') {
    const lapW = s * 0.4;
    const lapH = s * 0.22;
    const lapY = -s * 0.2;
    roundRectPath(ctx, -lapW * 0.5, lapY, lapW, lapH, s * 0.028);
    ctx.fillStyle = 'rgb(214, 214, 218)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    roundRectPath(ctx, -lapW * 0.58, lapY + lapH - s * 0.02, lapW * 1.16, s * 0.038, 3);
    ctx.fillStyle = 'rgb(184, 184, 190)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.75;
    ctx.stroke();

    const glowR = s * 0.032;
    ellipsePath(ctx, -glowR, lapY + lapH * 0.5 - glowR, glowR * 2, glowR * 2);
    ctx.fillStyle = '#22d3ee';
    ctx.fill();

    const codePhase = (t * 0.85) % 1.0;
    const bx = bodyW * 0.44;
    const by = lapY - codePhase * s * 0.18;
    const alpha = 1.0 - codePhase;
    roundRectPath(ctx, bx - s * 0.11, by - s * 0.06, s * 0.22, s * 0.12, 4);
    ctx.fillStyle = `rgba(0, 0, 0, ${0.75 * alpha})`;
    ctx.fill();
    ctx.fillStyle = `rgba(74, 222, 128, ${alpha})`;
    ctx.font = `800 ${Math.round(s * 0.082)}px Consolas, monospace`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('</>', bx, by);
  } else if (action === 'readingBook') {
    const bkW = s * 0.36;
    const bkH = s * 0.19;
    const bkY = baseY - s * 0.03;
    roundRectPath(ctx, -bkW * 0.5, bkY, bkW, bkH, 4);
    ctx.fillStyle = 'rgb(46, 148, 173)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    roundRectPath(ctx, -bkW * 0.44, bkY - s * 0.025, bkW * 0.88, s * 0.04, 2);
    ctx.fillStyle = 'rgb(250, 242, 219)';
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(0, bkY);
    ctx.lineTo(0, bkY + bkH);
    ctx.lineWidth = strokeW * 0.7;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
  } else if (role === 'mechanicSystem' && !isMouthOpenForDrop && !isIdleShowActivity(action)) {
    ctx.save();
    ctx.translate(s * 0.02, baseY - s * 0.01);
    ctx.rotate((-28 * Math.PI) / 180);
    roundRectPath(ctx, -s * 0.09, -s * 0.018, s * 0.18, s * 0.036, 2);
    ctx.fillStyle = 'rgb(209, 209, 214)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.65;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();
    ellipsePath(ctx, s * 0.06, -s * 0.04, s * 0.075, s * 0.08);
    ctx.fillStyle = 'rgb(219, 219, 224)';
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }
}

function drawOnsenTubFront(
  ctx: CanvasRenderingContext2D,
  s: number,
  strokeW: number,
  outlineColor: string,
  t: number
) {
  const tubW = s * 0.78;
  const tubH = s * 0.28;
  const tubTopY = -tubH;

  ellipsePath(ctx, -tubW * 0.46, tubTopY - s * 0.04, tubW * 0.92, s * 0.09);
  ctx.fillStyle = 'rgba(82, 224, 235, 0.88)';
  ctx.fill();

  const floatY = Math.sin(t * 3.0) * s * 0.01;
  ellipsePath(ctx, tubW * 0.2, tubTopY - s * 0.035 + floatY, s * 0.085, s * 0.07);
  ctx.fillStyle = '#ff922b';
  ctx.fill();
  ctx.lineWidth = strokeW * 0.65;
  ctx.strokeStyle = outlineColor;
  ctx.stroke();

  roundRectPath(ctx, -tubW * 0.5, tubTopY, tubW, tubH, s * 0.045);
  const grad = ctx.createLinearGradient(0, tubTopY, 0, 0);
  grad.addColorStop(0, 'rgb(224, 179, 122)');
  grad.addColorStop(1, 'rgb(189, 138, 87)');
  ctx.fillStyle = grad;
  ctx.fill();
  ctx.lineWidth = strokeW;
  ctx.strokeStyle = outlineColor;
  ctx.stroke();

  ctx.fillStyle = 'rgb(168, 102, 56)';
  ctx.fillRect(-tubW * 0.5, tubTopY + tubH * 0.48, tubW, s * 0.032);

  if (s > 40) {
    for (let i = 0; i < 2; i++) {
      const phase = (t * 0.55 + i * 0.5) % 1.0;
      const sy = tubTopY - s * 0.08 - phase * s * 0.22;
      const sx = (i === 0 ? -tubW * 0.34 : tubW * 0.34) + Math.sin(t * 2.5 + i) * s * 0.02;
      const alpha = Math.sin(phase * Math.PI) * 0.45;
      const sr = s * (0.045 + phase * 0.025);
      ellipsePath(ctx, sx - sr, sy - sr, sr * 2, sr * 2);
      ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
      ctx.fill();
    }
  }
}

function drawCostumeHeadgear(
  ctx: CanvasRenderingContext2D,
  headCenterY: number,
  topY: number,
  bodyW: number,
  eyeY: number,
  eyeSpread: number,
  faceShiftX: number,
  faceShiftY: number,
  s: number,
  strokeW: number,
  outlineColor: string,
  role: CapyRole,
  isListeningMusic: boolean,
  isOnsen: boolean,
  orangesOnHead: number,
  action: CapyActionType,
  t: number
) {
  const hx = faceShiftX * 0.55;
  const hy = topY + faceShiftY * 0.35;

  // 1. Sleek Matte Black DJ Headphones
  if ((role === 'djMusic' || isListeningMusic) && !isOnsen) {
    const span = bodyW * 0.49;
    const cupY = headCenterY - s * 0.01;
    ctx.beginPath();
    ctx.moveTo(hx - span, cupY);
    ctx.quadraticCurveTo(hx, hy - s * 0.14, hx + span, cupY);
    ctx.lineWidth = s * 0.045;
    ctx.lineCap = 'round';
    ctx.strokeStyle = 'rgb(30, 30, 34)';
    ctx.stroke();

    for (const side of [-1, 1]) {
      const cw = s * 0.095;
      const ch = s * 0.16;
      const cx = hx + side * span - cw * 0.5;
      const cy = cupY - ch * 0.5;
      roundRectPath(ctx, cx, cy, cw, ch, cw * 0.45);
      ctx.fillStyle = 'rgb(28, 28, 33)';
      ctx.fill();
      ctx.lineWidth = strokeW * 0.9;
      ctx.strokeStyle = 'rgb(72, 72, 80)';
      ctx.stroke();

      roundRectPath(ctx, cx + cw * 0.2, cy + ch * 0.2, cw * 0.6, ch * 0.6, cw * 0.25);
      ctx.lineWidth = strokeW * 0.6;
      ctx.strokeStyle = 'rgb(52, 52, 58)';
      ctx.stroke();
    }
  }

  // 2. Role Headgear
  if (role === 'scholarNotes') {
    const gxCenter = faceShiftX * 0.85;
    const gr = s * 0.072;
    const gold = 'rgb(245, 199, 66)';
    for (const side of [-1, 1]) {
      ellipsePath(ctx, gxCenter + side * eyeSpread - gr, eyeY - gr, gr * 2, gr * 2);
      ctx.fillStyle = 'rgba(255, 255, 255, 0.14)';
      ctx.fill();
      ctx.lineWidth = Math.max(1.2, strokeW * 0.95);
      ctx.strokeStyle = gold;
      ctx.stroke();
    }
    ctx.beginPath();
    ctx.moveTo(gxCenter - eyeSpread + gr, eyeY - gr * 0.1);
    ctx.quadraticCurveTo(gxCenter, eyeY - gr * 0.45, gxCenter + eyeSpread - gr, eyeY - gr * 0.1);
    ctx.lineWidth = Math.max(1.1, strokeW * 0.85);
    ctx.strokeStyle = gold;
    ctx.stroke();
  } else if (role === 'pilotLauncher') {
    const gyBand = hy + s * 0.075;
    roundRectPath(ctx, hx - bodyW * 0.42, gyBand - s * 0.02, bodyW * 0.84, s * 0.04, 3);
    ctx.fillStyle = 'rgb(89, 56, 36)';
    ctx.fill();
    for (const side of [-1, 1]) {
      const lw = s * 0.13;
      const lh = s * 0.095;
      roundRectPath(ctx, hx + side * s * 0.08 - lw * 0.5, gyBand - lh * 0.5, lw, lh, lh * 0.4);
      ctx.fillStyle = 'rgb(89, 219, 245)';
      ctx.fill();
      ctx.lineWidth = strokeW * 1.05;
      ctx.strokeStyle = 'rgb(219, 219, 219)';
      ctx.stroke();
    }
  } else if (role === 'builderTray') {
    const hw = bodyW * 0.78;
    const hh = s * 0.18;
    ctx.beginPath();
    ctx.arc(hx, hy + s * 0.07, hw * 0.46, Math.PI, 0, false);
    ctx.closePath();
    ctx.fillStyle = 'rgb(255, 209, 31)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.9;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    roundRectPath(ctx, hx - hw * 0.54, hy + s * 0.055, hw * 1.08, hh * 0.24, 4);
    ctx.fillStyle = 'rgb(245, 189, 15)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.85;
    ctx.stroke();
  } else if (role === 'mechanicSystem') {
    const vw = bodyW * 0.76;
    const vh = s * 0.068;
    roundRectPath(ctx, hx - vw * 0.5, hy + s * 0.055, vw, vh, vh * 0.5);
    ctx.fillStyle = 'rgb(31, 51, 71)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.8;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    const pulse = 0.75 + 0.25 * Math.sin(t * 5.0);
    roundRectPath(
      ctx,
      hx - vw * 0.38,
      hy + s * 0.055 + vh * 0.24,
      vw * 0.76,
      vh * 0.52,
      vh * 0.3
    );
    ctx.fillStyle = `rgba(34, 211, 238, ${pulse})`;
    ctx.fill();
  } else if (role === 'detectiveClipboard') {
    const cw = bodyW * 0.78;
    ctx.beginPath();
    ctx.arc(hx, hy + s * 0.065, cw * 0.45, Math.PI, 0, false);
    ctx.closePath();
    ctx.fillStyle = 'rgb(133, 102, 74)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.85;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    roundRectPath(ctx, hx - cw * 0.56, hy + s * 0.05, cw * 1.12, s * 0.036, 3);
    ctx.fillStyle = 'rgba(133, 102, 74, 0.92)';
    ctx.fill();
    ctx.stroke();

    const mr = s * 0.072;
    const mx = faceShiftX * 0.85 + eyeSpread;
    ellipsePath(ctx, mx - mr, eyeY - mr, mr * 2, mr * 2);
    ctx.fillStyle = 'rgba(34, 211, 238, 0.14)';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.9;
    ctx.strokeStyle = '#ffd43b';
    ctx.stroke();
  } else if (role === 'senseiTimer') {
    const bw = bodyW * 0.82;
    const bh = s * 0.064;
    roundRectPath(ctx, hx - bw * 0.5, hy + s * 0.055, bw, bh, bh * 0.4);
    ctx.fillStyle = '#ffffff';
    ctx.fill();
    ctx.lineWidth = strokeW * 0.8;
    ctx.strokeStyle = outlineColor;
    ctx.stroke();

    const sunR = bh * 0.36;
    ellipsePath(ctx, hx - sunR, hy + s * 0.055 + bh * 0.5 - sunR, sunR * 2, sunR * 2);
    ctx.fillStyle = '#ef4444';
    ctx.fill();
  }

  // 3. Stacked Yuzu Oranges on Head (1-3 oranges + stem + green leaf!)
  if (orangesOnHead > 0 && action !== 'jugglingOranges' && action !== 'brushed') {
    const count = Math.min(3, orangesOnHead);
    let curY = hy + s * 0.018;
    for (let i = 0; i < count; i++) {
      const sc = 1.0 - i * 0.13;
      const ow = s * 0.185 * sc;
      const oh = s * 0.145 * sc;
      const wobble = Math.sin(t * 3.0 + i) * s * 0.007 * (i + 1);
      const ox = hx + wobble;
      const ox0 = ox - ow * 0.5;
      const oy0 = curY - oh;

      if (i > 0) {
        ellipsePath(ctx, ox - ow * 0.44, curY - oh * 0.28, ow * 0.88, oh * 0.32);
        ctx.fillStyle = 'rgba(0, 0, 0, 0.32)';
        ctx.fill();
      }

      ellipsePath(ctx, ox0, oy0, ow, oh);
      const oGrad = ctx.createLinearGradient(ox0 + ow * 0.25, oy0, ox0 + ow * 0.8, oy0 + oh);
      oGrad.addColorStop(0, 'rgb(255, 204, 56)');
      oGrad.addColorStop(0.55, 'rgb(255, 133, 15)');
      oGrad.addColorStop(1, 'rgb(224, 87, 5)');
      ctx.fillStyle = oGrad;
      ctx.fill();
      ctx.lineWidth = strokeW * 0.85;
      ctx.strokeStyle = outlineColor;
      ctx.stroke();

      ellipsePath(ctx, ox0 + ow * 0.2, oy0 + oh * 0.16, ow * 0.24, oh * 0.2);
      ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
      ctx.fill();

      ellipsePath(ctx, ox0 + ow * 0.68, oy0 + oh * 0.62, ow * 0.09, oh * 0.09);
      ctx.fillStyle = 'rgba(184, 56, 5, 0.48)';
      ctx.fill();

      if (i === count - 1) {
        ctx.beginPath();
        ctx.moveTo(ox, oy0);
        ctx.quadraticCurveTo(ox, oy0 - oh * 0.14, ox + ow * 0.08, oy0 - oh * 0.24);
        ctx.lineWidth = Math.max(1.1, strokeW * 0.75);
        ctx.lineCap = 'round';
        ctx.strokeStyle = outlineColor;
        ctx.stroke();

        const lx = ox + ow * 0.06;
        const ly = oy0 - oh * 0.16;
        ctx.beginPath();
        ctx.moveTo(lx, ly);
        ctx.quadraticCurveTo(lx + ow * 0.16, ly - oh * 0.46, lx + ow * 0.44, ly - oh * 0.26);
        ctx.quadraticCurveTo(lx + ow * 0.26, ly + oh * 0.04, lx, ly);
        ctx.closePath();
        ctx.fillStyle = 'rgb(74, 204, 82)';
        ctx.fill();
        ctx.lineWidth = strokeW * 0.65;
        ctx.strokeStyle = outlineColor;
        ctx.stroke();
      }

      curY -= oh * 0.82;
    }
  }
}

function drawForegroundAerialProps(
  ctx: CanvasRenderingContext2D,
  bodyH: number,
  snoutX: number,
  snoutY: number,
  s: number,
  strokeW: number,
  outlineColor: string,
  butterflyPos: { x: number; y: number },
  action: CapyActionType,
  t: number
) {
  if (action === 'jugglingOranges') {
    const pawSpanX = s * 0.34;
    const pawCatchY = -bodyH * 0.35;
    const highPeakY = -s * 0.72;
    const lowPassY = -bodyH * 0.22;

    ctx.save();
    ctx.setLineDash([3, 4]);
    ctx.beginPath();
    ctx.moveTo(-pawSpanX, pawCatchY);
    ctx.quadraticCurveTo(0, highPeakY - s * 0.16, pawSpanX, pawCatchY);
    ctx.quadraticCurveTo(0, lowPassY + s * 0.05, -pawSpanX, pawCatchY);
    ctx.lineWidth = Math.max(1.0, strokeW * 0.58);
    ctx.strokeStyle = 'rgba(255, 199, 46, 0.48)';
    ctx.stroke();
    ctx.restore();

    const ow = s * 0.19;
    const oh = s * 0.164;
    for (let i = 0; i < 3; i++) {
      const ph = t * 3.4 + i * ((Math.PI * 2) / 3);
      const ox = Math.cos(ph) * pawSpanX;
      const sVal = Math.sin(ph);
      const oy =
        sVal >= 0
          ? pawCatchY + (highPeakY - pawCatchY) * sVal
          : pawCatchY + (lowPassY - pawCatchY) * -sVal;

      ctx.save();
      ctx.translate(ox, oy);
      ctx.rotate(((Math.cos(ph) * 20) * Math.PI) / 180);

      ellipsePath(ctx, -ow * 0.62, -oh * 0.62, ow * 1.24, oh * 1.24);
      ctx.fillStyle = 'rgba(255, 146, 43, 0.24)';
      ctx.fill();

      ellipsePath(ctx, -ow * 0.52, -oh * 0.44, ow * 1.04, oh * 1.04);
      ctx.fillStyle = 'rgba(0, 0, 0, 0.36)';
      ctx.fill();

      ellipsePath(ctx, -ow * 0.5, -oh * 0.5, ow, oh);
      const grad = ctx.createLinearGradient(-ow * 0.25, -oh * 0.5, ow * 0.25, oh * 0.5);
      grad.addColorStop(0, 'rgb(255, 204, 51)');
      grad.addColorStop(0.55, 'rgb(255, 128, 10)');
      grad.addColorStop(1, 'rgb(230, 87, 5)');
      ctx.fillStyle = grad;
      ctx.fill();
      ctx.lineWidth = strokeW * 0.95;
      ctx.strokeStyle = outlineColor;
      ctx.stroke();

      ellipsePath(ctx, -ow * 0.27, -oh * 0.29, ow * 0.25, oh * 0.21);
      ctx.fillStyle = 'rgba(255, 255, 255, 0.88)';
      ctx.fill();

      ctx.beginPath();
      ctx.moveTo(0, -oh * 0.45);
      ctx.lineTo(0, -oh * 0.68);
      ctx.lineWidth = strokeW * 0.85;
      ctx.strokeStyle = outlineColor;
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(0, -oh * 0.52);
      ctx.quadraticCurveTo(ow * 0.16, -oh * 0.92, ow * 0.46, -oh * 0.74);
      ctx.quadraticCurveTo(ow * 0.32, -oh * 0.4, 0, -oh * 0.52);
      ctx.fillStyle = 'rgb(46, 214, 77)';
      ctx.fill();
      ctx.lineWidth = strokeW * 0.68;
      ctx.stroke();

      ctx.restore();
    }
  } else if (action === 'butterflyChase') {
    ctx.save();
    ctx.translate(butterflyPos.x, butterflyPos.y);
    const flap = Math.max(0.25, Math.abs(Math.sin(t * 16.0)));
    ctx.scale(flap, 1);
    const wr = s * 0.068;
    for (const side of [-1, 1]) {
      ellipsePath(ctx, side < 0 ? -wr * 1.1 : 0, -wr, wr * 1.1, wr);
      ctx.fillStyle = '#ffd43b';
      ctx.fill();
      ctx.lineWidth = strokeW * 0.6;
      ctx.strokeStyle = outlineColor;
      ctx.stroke();

      ellipsePath(ctx, side < 0 ? -wr * 0.85 : 0, -wr * 0.1, wr * 0.85, wr * 0.8);
      ctx.fillStyle = '#22d3ee';
      ctx.fill();
      ctx.stroke();
    }
    ctx.restore();
  } else if (action === 'blowingBubbles') {
    for (let i = 0; i < 4; i++) {
      const ph = (t * 0.65 + i * 0.25) % 1.0;
      const bx = snoutX - s * 0.08 - ph * s * 0.2 + Math.sin(t * 4.0 + i) * s * 0.04;
      const by = snoutY - ph * s * 0.34;
      const br = s * (0.032 + ph * 0.044);
      ellipsePath(ctx, bx - br, by - br, br * 2, br * 2);
      ctx.fillStyle =
        i % 2 === 0
          ? `rgba(34, 211, 238, ${(1 - ph) * 0.38})`
          : `rgba(244, 114, 182, ${(1 - ph) * 0.38})`;
      ctx.fill();
      ctx.lineWidth = strokeW * 0.7;
      ctx.strokeStyle = `rgba(255, 255, 255, ${(1 - ph) * 0.9})`;
      ctx.stroke();
    }
  }
}

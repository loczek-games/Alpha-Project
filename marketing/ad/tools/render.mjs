// Renders ad.html frame by frame into video.
//   node tools/render.mjs                -> out/ad_silent.mp4
//   node tools/render.mjs --stills 3,9.5 -> out/still_3.jpg, out/still_9.5.jpg
import { createRequire } from "node:module";
import { spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const { chromium } = createRequire(import.meta.url)("playwright");
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const out = resolve(root, "out");
mkdirSync(out, { recursive: true });

const args = process.argv.slice(2);
const stillsArg = args.indexOf("--stills");

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
page.on("pageerror", e => { console.error("page error:", e.message); process.exitCode = 1; });
await page.goto(pathToFileURL(resolve(root, "ad.html")).href + "?render=1");
await page.evaluate(() => window.adReady);

const grab = t => page.evaluate(t => {
  window.renderFrame(t);
  return document.getElementById("c").toDataURL("image/jpeg", 0.95).split(",")[1];
}, t);

if (stillsArg >= 0) {
  for (const t of args[stillsArg + 1].split(",").map(Number)) {
    writeFileSync(resolve(out, `still_${t}.jpg`), Buffer.from(await grab(t), "base64"));
  }
} else {
  const { DURATION, FPS } = await page.evaluate(() => ({ DURATION: window.DURATION, FPS: window.FPS }));
  const frames = Math.round(DURATION * FPS);
  const ff = spawn("ffmpeg", ["-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", String(FPS), "-c:v", "mjpeg", "-i", "-",
    "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", resolve(out, "ad_silent.mp4")], { stdio: ["pipe", "inherit", "inherit"] });
  for (let f = 0; f < frames; f++) {
    const buf = Buffer.from(await grab(f / FPS), "base64");
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once("drain", r));
    if (f % 60 === 0) console.log(`frame ${f}/${frames}`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on("close", r));
}
await browser.close();

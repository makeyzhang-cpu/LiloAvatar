#!/usr/bin/env node
/**
 * apply.mjs — 确定性品牌应用引擎（单一信源 → 全量覆盖）
 *
 * 这是「升级安全」的核心：所有图标从 branding/icon-source.png 一张图生成，
 * 软件名集中在 branding/branding.json。本脚本把品牌 100% 重写进仓库，
 * 因此每次从上游 rebase/merge 后，只要重跑本脚本，品牌就会被确定性地覆盖回去，
 * 不需要手工逐个文件解决冲突。
 *
 * 用法:
 *   node branding/apply.mjs            # 应用 branding.json 中的所有品牌
 *   BRANDING_PYTHON=python3 node ...   # 指定带 Pillow 的 python
 */
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, copyFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");

const log = (m) => console.log(m);
const fail = (m) => { console.error("✗ " + m); process.exit(1); };

function readJSON(p) {
  return JSON.parse(readFileSync(p, "utf8"));
}
function writeJSON(p, obj) {
  writeFileSync(p, JSON.stringify(obj, null, 2) + "\n", "utf8");
}
function readText(p) {
  return readFileSync(p, "utf8");
}
function writeText(p, s) {
  writeFileSync(p, s, "utf8");
}

// ---- 1. 载入品牌配置 ----------------------------------------------------
const brand = readJSON(resolve(__dirname, "branding.json"));
const appName = (brand.appName || "").trim();
const appId = (brand.appId || "").trim();
const assistantName = (brand.assistantName || "").trim();
// 占位名（未提供真实名时）=> 跳过"软件名"改写，但仍生成图标
const nameActive = appName !== "" && appName !== "TODO";

// ---- 2. 生成图标（单一信源） -------------------------------------------
function resolvePython() {
  if (process.env.BRANDING_PYTHON) return process.env.BRANDING_PYTHON;
  for (const c of ["python3", "python", "py"]) {
    try { execFileSync(c, ["--version"], { stdio: "ignore" }); return c; }
    catch { /* try next */ }
  }
  fail("找不到 python（需要 Pillow）。请先 `python -m pip install Pillow`，或设置 BRANDING_PYTHON。");
}
const py = resolvePython();
log(`· python: ${py}`);
try {
  execFileSync(py, [resolve(__dirname, "make-icons.py")], { stdio: "inherit", cwd: ROOT });
} catch (e) {
  fail("图标生成失败：" + e.message);
}

// ---- 3. 复制 UI logo ----------------------------------------------------
const logoSrc = resolve(ROOT, brand.logoSource || "branding/logo-source.png");
if (existsSync(logoSrc)) {
  for (const dest of ["images/logo.png", "images/bailongma-logo.png"]) {
    copyFileSync(logoSrc, resolve(ROOT, dest));
    log(`· copied logo → ${dest}`);
  }
}

if (!nameActive) {
  log(`\n⚠  branding.json 的 appName 还是占位值「${appName || "(空)"}」，已跳过软件名改写。`);
  log("   设置真实软件名后重跑 `node branding/apply.mjs` 即可完成改名。");
  writeJSON(resolve(__dirname, "branding.json"), { ...brand, appliedAt: new Date().toISOString() });
  log("\n✓ 图标 / logo 已生成（软件名待定）。");
  process.exit(0);
}

// ---- 4. 改写软件名 ------------------------------------------------------
// 只替换「显示名」Bailongma（首字母大写），不动内部标识符 bailongma / BAILONGMA。
// 同时替换上一次 apply 可能写入的占位名（保证幂等/可重复跑）。
const DISPLAY_RE = /\bBailongma\b/g;
const LONGMA_RE = /\bLongma\b/g;
const PLACEHOLDER_RE = /待命名App/g;

// 4a. package.json
const pkgPath = resolve(ROOT, "package.json");
const pkg = readJSON(pkgPath);
pkg.productName = appName;
if (pkg.build) {
  pkg.build.productName = appName;
  if (pkg.build.nsis) pkg.build.nsis.shortcutName = appName;
  if (pkg.build.mac) {
    if (pkg.build.mac.extendInfo) {
      for (const k of Object.keys(pkg.build.mac.extendInfo)) {
        pkg.build.mac.extendInfo[k] = pkg.build.mac.extendInfo[k].replace(DISPLAY_RE, appName);
      }
    }
  }
  if (appId) pkg.build.appId = appId;
}
writeJSON(pkgPath, pkg);
log(`· package.json productName/appId → ${appName} / ${appId || "(未改)"}`);

// 4b. electron/main.cjs（显示名 + appId 字符串）
const mainPath = resolve(ROOT, "electron/main.cjs");
let main = readText(mainPath);
const before = (main.match(DISPLAY_RE) || []).length + (main.match(PLACEHOLDER_RE) || []).length;
main = main.replace(DISPLAY_RE, appName).replace(PLACEHOLDER_RE, appName);
if (appId) {
  main = main.replace(/com\.xiaoyuanda\.bailongma/g, appId);
}
writeText(mainPath, main);
log(`· electron/main.cjs 替换 ${before} 处显示名 + appId`);

// 4c. 各 UI 窗口 HTML 标题
const titleFiles = [
  "activation.html",
  "architecture-comparison.html",
  "brain-ui.html",
  "index.html",
  "website.html",
  "electron/startup.html",
  "electron/wake-probe.html",
  "src/ui/brain-ui/voice-orb.html",
  "src/ui/terminal-stream/index.html",
];
let titleCount = 0;
for (const f of titleFiles) {
  const p = resolve(ROOT, f);
  if (!existsSync(p)) continue;
  let s = readText(p);
  const n = (s.match(DISPLAY_RE) || []).length + (s.match(LONGMA_RE) || []).length + (s.match(PLACEHOLDER_RE) || []).length;
  s = s.replace(DISPLAY_RE, appName).replace(LONGMA_RE, appName).replace(PLACEHOLDER_RE, appName);
  writeText(p, s);
  if (n) { titleCount += n; log(`· ${f} 替换 ${n} 处`); }
}
log(`· HTML 标题共改写 ${titleCount} 处`);

// 4d. AI 人格名（可选，默认不改）
if (assistantName) {
  const personaFiles = [
    "src/prompt.js",
    "src/docs/self-knowledge.js",
    "systemPrompt.html",
  ];
  let pc = 0;
  for (const f of personaFiles) {
    const p = resolve(ROOT, f);
    if (!existsSync(p)) continue;
    let s = readText(p);
    const n = (s.match(DISPLAY_RE) || []).length;
    s = s.replace(DISPLAY_RE, assistantName);
    writeText(p, s);
    pc += n;
  }
  log(`· AI 人格名 → ${assistantName}（改写 ${pc} 处，仅 prompt 层）`);
}

writeJSON(resolve(__dirname, "branding.json"), { ...brand, appliedAt: new Date().toISOString() });
log(`\n✓ 品牌已应用：软件名「${appName}」、appId「${appId}」、图标来自 ${brand.iconSource}`);
log("  升级上游后：git fetch upstream && git rebase upstream/main && node branding/apply.mjs");

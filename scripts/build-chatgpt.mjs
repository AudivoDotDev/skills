#!/usr/bin/env node
/**
 * Checks the ChatGPT plugin package in `chatgpt/` against OpenAI's
 * submission rules, then zips it for upload at platform.openai.com/plugins.
 *
 *   node scripts/build-chatgpt.mjs           check, then write dist/audivo-chatgpt-<version>.zip
 *   node scripts/build-chatgpt.mjs --check   check only (CI)
 *
 * The rules are the ones OpenAI documents for a final directory submission
 * (developers.openai.com/plugins/deploy/submission and submission-errors):
 * listing limits, the four URLs, icons, colors, exactly five positive and
 * three negative review cases, and no credentials in the package. Catching
 * them here is cheaper than a rejected upload.
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PACKAGE = process.env.CHATGPT_PACKAGE ?? path.join(ROOT, 'chatgpt');
const CHECK_ONLY = process.argv.includes('--check');

/** The hosted server's tools, which review cases may name (`@audivo/mcp`'s TOOLS). */
const HOSTED_TOOLS = new Set([
  'transcribe',
  'search_shows',
  'chart_shows',
  'list_episodes',
  'quote',
  'confirm',
  'group_status',
  'list_groups',
  'cancel_group',
  'read_transcript',
  'list_transcripts',
]);

const CATEGORIES = new Set([
  'Productivity',
  'Creativity',
  'Developer Tools',
  'Business & Operations',
  'Data & Analytics',
  'Communication',
  'Education & Research',
  'Security',
  'Finance',
  'Healthcare',
  'Travel',
  'Entertainment',
  'Other',
]);

const problems = [];
const fail = (message) => problems.push(message);
/**
 * What final submission needs but an upload does not, and that can only
 * exist once the plugin has been tried in ChatGPT: screenshots and the demo
 * video. Listed, not failed, so the draft can be uploaded early (domain
 * verification and the tool scan run on the draft) and CI stays green.
 */
const todo = [];

function readJson(file) {
  return JSON.parse(fs.readFileSync(path.join(PACKAGE, file), 'utf8'));
}

function oneLine(value, max, field) {
  if (typeof value !== 'string' || value.trim() === '') return fail(`${field} is required`);
  if (/[\r\n\t]/.test(value)) fail(`${field} must be one line`);
  if (value.length > max) fail(`${field} is ${value.length} characters; the limit is ${max}`);
}

function httpsUrl(value, field) {
  if (typeof value !== 'string') return fail(`${field} is required`);
  let url;
  try {
    url = new URL(value);
  } catch {
    return fail(`${field} is not a URL`);
  }
  if (url.protocol !== 'https:') fail(`${field} must be https`);
  if (url.username !== '' || url.password !== '') fail(`${field} must not embed credentials`);
  if (value.length > 1024) fail(`${field} is over 1024 characters`);
}

/** WCAG relative luminance contrast, as OpenAI states its color rule. */
function contrast(hex, against) {
  const lum = (h) => {
    const channels = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255);
    const linear = channels.map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
  };
  const [hi, lo] = [lum(hex), lum(against)].sort((a, b) => b - a);
  return (hi + 0.05) / (lo + 0.05);
}

function pngSize(file) {
  const bytes = fs.readFileSync(file);
  if (bytes.toString('ascii', 1, 4) !== 'PNG') return undefined;
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20), size: bytes.length };
}

/** A JPEG's size, from its first start-of-frame marker. */
function jpegSize(file) {
  const bytes = fs.readFileSync(file);
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8) return undefined;
  for (let at = 2; at + 9 < bytes.length; ) {
    if (bytes[at] !== 0xff) return undefined;
    const marker = bytes[at + 1];
    const length = bytes.readUInt16BE(at + 2);
    if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
      return { width: bytes.readUInt16BE(at + 7), height: bytes.readUInt16BE(at + 5), size: bytes.length };
    }
    at += 2 + length;
  }
  return undefined;
}

function icon(relative, field) {
  if (typeof relative !== 'string' || !relative.startsWith('./')) {
    return fail(`${field} must be a ./-relative path`);
  }
  const file = path.join(PACKAGE, relative);
  if (!fs.existsSync(file)) return fail(`${field} names ${relative}, which is not in the package`);
  const png = pngSize(file);
  if (png === undefined) return fail(`${field} must be a PNG here`);
  if (png.width !== png.height) fail(`${field} must be square (${png.width}x${png.height})`);
  if (png.width < 48 || png.width > 4096) fail(`${field} must be 48 to 4096 pixels`);
  if (png.size > 5 * 1024 * 1024) fail(`${field} is over 5 MiB`);
}

function frontmatter(file) {
  const text = fs.readFileSync(file, 'utf8');
  const match = /^---\n([\s\S]*?)\n---\n/.exec(text);
  if (match === null) return {};
  return Object.fromEntries(
    match[1]
      .split('\n')
      .map((line) => /^([a-z]+):\s*(.*)$/.exec(line))
      .filter(Boolean)
      .map((m) => [m[1], m[2]]),
  );
}

// --- The manifest -----------------------------------------------------------------

const manifest = readJson('plugin.json');
if (manifest.$schema !== 'https://agent-plugins.org/schemas/1.0.0/plugin.schema.json') {
  fail('plugin.json needs the Agent Plugins $schema');
}
if (!/^[a-z0-9][a-z0-9-]{0,63}$/.test(manifest.name ?? '')) fail('name: lowercase, digits, hyphens; 64 at most');
if (!/^\d+\.\d+\.\d+$/.test(manifest.version ?? '')) fail('version must be a semantic version');
if (/test_credentials|reviewer_instructions/.test(JSON.stringify(manifest))) {
  fail('the package must not carry reviewer credentials or instructions; enter them in the dashboard');
}

const openai = manifest.extensions?.['com.openai'] ?? {};
const ui = openai.interface ?? {};
oneLine(ui.displayName, 30, 'displayName');
oneLine(ui.shortDescription, 30, 'shortDescription');
if (typeof ui.longDescription !== 'string' || ui.longDescription.trim() === '') fail('longDescription is required');
else if (ui.longDescription.length > 4000) fail('longDescription is over 4000 characters');
oneLine(ui.developerName, 80, 'developerName');
if (!CATEGORIES.has(ui.category)) fail(`category must be one of: ${[...CATEGORIES].join(', ')}`);
if (!Array.isArray(ui.capabilities) || ui.capabilities.length > 20) fail('capabilities: at most 20');
for (const [i, capability] of (ui.capabilities ?? []).entries()) oneLine(capability, 120, `capabilities[${i}]`);
for (const field of ['websiteURL', 'supportURL', 'privacyPolicyURL', 'termsOfServiceURL']) httpsUrl(ui[field], field);
const prompts = ui.defaultPrompt ?? [];
if (prompts.length > 3) fail('defaultPrompt: at most 3');
for (const [i, prompt] of prompts.entries()) {
  oneLine(prompt, 128, `defaultPrompt[${i}]`);
  if (/@\w/.test(prompt)) fail(`defaultPrompt[${i}] must not @mention a server`);
}
const normalized = prompts.map((p) => p.normalize('NFKC').replace(/\s+/g, ' ').trim().toLowerCase());
if (new Set(normalized).size !== normalized.length) fail('defaultPrompt entries must be unique');
if (!/^#[0-9A-Fa-f]{6}$/.test(ui.brandColor ?? '') || contrast(ui.brandColor, '#FFFFFF') < 2) {
  fail('brandColor needs at least 2:1 contrast against white');
}
if (ui.brandColorDark !== undefined && contrast(ui.brandColorDark, '#212121') < 2) {
  fail('brandColorDark needs at least 2:1 contrast against #212121');
}
icon(ui.logo, 'logo');
icon(ui.composerIcon, 'composerIcon');
// The server serves its own UI (the Audivo app), so final submission wants
// one screenshot per starter prompt, in the same order, 706 pixels wide and
// 400 to 860 tall, PNG or JPEG.
if (ui.screenshots === undefined) {
  todo.push(
    `screenshots: ${prompts.length} images, one per starter prompt in order, 706 px wide and 400-860 px tall ` +
      '(see chatgpt/REVIEW.md)',
  );
} else if (!Array.isArray(ui.screenshots) || ui.screenshots.length !== prompts.length) {
  fail(`screenshots: exactly one per starter prompt (${prompts.length})`);
} else {
  for (const [i, relative] of ui.screenshots.entries()) {
    const field = `screenshots[${i}]`;
    if (typeof relative !== 'string' || !relative.startsWith('./')) {
      fail(`${field} must be a ./-relative path`);
      continue;
    }
    const file = path.join(PACKAGE, relative);
    if (!fs.existsSync(file)) {
      fail(`${field} names ${relative}, which is not in the package`);
      continue;
    }
    const image = pngSize(file) ?? jpegSize(file);
    if (image === undefined) fail(`${field} must be a PNG or a JPEG`);
    else if (image.width !== 706 || image.height < 400 || image.height > 860) {
      fail(`${field} is ${image.width}x${image.height}; it must be 706 wide and 400 to 860 tall`);
    }
  }
}

// --- Skills ------------------------------------------------------------------------

const skillsDir = path.join(PACKAGE, 'skills');
const skills = fs.readdirSync(skillsDir).filter((entry) => fs.statSync(path.join(skillsDir, entry)).isDirectory());
for (const skill of skills) {
  const file = path.join(skillsDir, skill, 'SKILL.md');
  if (!fs.existsSync(file)) {
    fail(`skills/${skill} has no SKILL.md`);
    continue;
  }
  const meta = frontmatter(file);
  if (meta.name !== skill) fail(`skills/${skill}/SKILL.md: name must be ${skill}`);
  if (!meta.description) fail(`skills/${skill}/SKILL.md: description is required`);
}
if (openai.onboardingSkill !== undefined && !fs.existsSync(path.join(PACKAGE, openai.onboardingSkill))) {
  fail(`onboardingSkill names ${openai.onboardingSkill}, which is not in the package`);
}

// --- The MCP server and its review cases --------------------------------------------

const servers = Object.entries(readJson('mcp.json').mcpServers ?? {});
if (servers.length !== 1) fail('mcp.json must declare exactly one server');
for (const [name, server] of servers) httpsUrl(server.url, `mcp.json ${name}.url`);

const cases = openai.review?.test_cases ?? {};
if ((cases.positive ?? []).length !== 5) fail('review: exactly five positive test cases');
if ((cases.negative ?? []).length !== 3) fail('review: exactly three negative test cases');
for (const [i, c] of (cases.positive ?? []).entries()) {
  for (const field of ['description', 'prompt', 'tools_triggered', 'expected_behavior']) {
    if (typeof c[field] !== 'string' || c[field].trim() === '') fail(`positive[${i}].${field} is required`);
  }
  for (const tool of (c.tools_triggered ?? '').split(',').map((t) => t.trim())) {
    if (!HOSTED_TOOLS.has(tool)) fail(`positive[${i}] names ${tool}, which the hosted server does not serve`);
  }
}
for (const [i, c] of (cases.negative ?? []).entries()) {
  for (const field of ['description', 'prompt']) {
    if (typeof c[field] !== 'string' || c[field].trim() === '') fail(`negative[${i}].${field} is required`);
  }
}
if (typeof openai.publication?.release_notes !== 'string' || openai.publication.release_notes === '') {
  fail('publication.release_notes is required');
}
const demo = openai.review?.demo_recording_url;
if (demo === undefined) {
  todo.push('review.demo_recording_url: the walkthrough video (or enter it in the dashboard)');
} else {
  httpsUrl(demo, 'review.demo_recording_url');
}

if (problems.length > 0) {
  process.stderr.write(`chatgpt/ is not ready to submit:\n- ${problems.join('\n- ')}\n`);
  process.exit(1);
}
process.stderr.write(
  `chatgpt/ passes: ${manifest.name} ${manifest.version}, ${skills.length} skills, ` +
    `${cases.positive.length} positive and ${cases.negative.length} negative review cases\n`,
);
if (todo.length > 0) {
  process.stderr.write(
    `Uploadable as a draft. Before submitting for review, still add:\n- ${todo.join('\n- ')}\n`,
  );
}
if (CHECK_ONLY) process.exit(0);

// --- The ZIP --------------------------------------------------------------------------

const dist = path.join(ROOT, 'dist');
fs.mkdirSync(dist, { recursive: true });
const zip = path.join(dist, `audivo-chatgpt-${manifest.version}.zip`);
fs.rmSync(zip, { force: true });
// -X leaves out extended attributes; -D leaves out directory entries; .DS_Store never ships.
execFileSync('zip', ['-r', '-X', '-D', zip, 'plugin.json', 'mcp.json', 'assets', 'skills', '-x', '*.DS_Store'], {
  cwd: PACKAGE,
  stdio: 'ignore',
});
process.stderr.write(`wrote ${path.relative(ROOT, zip)}\n`);

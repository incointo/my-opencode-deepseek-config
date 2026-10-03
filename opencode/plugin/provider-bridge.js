// Keeps OpenCode's model routing in step with whichever provider is active in
// cc-switch, so switching providers there never means hand-editing
// opencode.json or the agent files.
//
// Why a plugin rather than plain config: `{env:...}` substitution is applied to
// opencode.json but NOT to agent markdown frontmatter, so an agent's `model:`
// cannot be parameterised through config alone. The `config` hook receives the
// fully merged config object and mutations to it are applied in place, which is
// the only place per-agent model routing can be rewritten at load time.
//
// Resolution order for the active provider:
//   1. $OC_PROVIDER                      explicit override, handy for testing
//   2. cc-switch DB  is_current = 1      authoritative if cc-switch ever sets it
//   3. cc-switch log last "written"      what actually fires today: cc-switch
//                                        records no current provider for opencode
//   4. nothing matched                   config is left exactly as it is
//
// Every step is best-effort: a failure here must never stop opencode starting,
// so all work is wrapped and the original config is used unchanged on error.

import {
  appendFileSync,
  closeSync,
  existsSync,
  openSync,
  readFileSync,
  readSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";

const HOME = homedir();
// Overridable so the bridge can be exercised against synthetic fixtures without
// touching the real cc-switch state.
const CC_DB = process.env.OC_CC_DB || join(HOME, ".cc-switch", "cc-switch.db");
const CC_LOG = process.env.OC_CC_LOG || join(HOME, ".cc-switch", "logs", "cc-switch.log");
const MAP_FILE = process.env.OC_PROVIDER_MAP || join(HOME, ".config", "opencode", "provider-models.json");
const BRIDGE_LOG = join(tmpdir(), "opencode-provider-bridge.log");
const LOG_MAX_BYTES = 64 * 1024;

function log(line) {
  try {
    if (existsSync(BRIDGE_LOG) && statSync(BRIDGE_LOG).size > LOG_MAX_BYTES) {
      writeFileSync(BRIDGE_LOG, "");
    }
    appendFileSync(BRIDGE_LOG, `${new Date().toISOString()} ${line}\n`);
  } catch {
    // Diagnostics are optional; never let logging break startup.
  }
}

// PowerShell's `Set-Content -Encoding UTF8` writes a BOM that JSON.parse rejects.
function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8").replace(/^\uFEFF/, ""));
}

function activeProviderFromDb() {
  return (async () => {
    const { Database } = await import("bun:sqlite");
    const db = new Database(CC_DB, { readonly: true });
    try {
      const row = db
        .query("SELECT id FROM providers WHERE app_type = 'opencode' AND is_current = 1 LIMIT 1")
        .get();
      return row ? row.id : null;
    } finally {
      db.close();
    }
  })();
}

// The log gains a line a minute from cc-switch's usage sync, so it must be read
// without loading the whole file. Scan backwards in bounded chunks and stop at
// the first (i.e. most recent) match; a small overlap is carried so a match
// straddling a chunk boundary is still found.
function activeProviderFromLog() {
  if (!existsSync(CC_LOG)) return null;
  const pattern = /OpenCode provider '([^']+)' written to live config/g;
  const CHUNK = 256 * 1024;
  const OVERLAP = 200;
  let fd;
  try {
    fd = openSync(CC_LOG, "r");
    let end = statSync(CC_LOG).size;
    let carry = "";
    while (end > 0) {
      const start = Math.max(0, end - CHUNK);
      const buf = Buffer.allocUnsafe(end - start);
      readSync(fd, buf, 0, buf.length, start);
      const text = buf.toString("utf8") + carry;
      pattern.lastIndex = 0;
      let match;
      let last = null;
      while ((match = pattern.exec(text)) !== null) last = match[1];
      if (last) return last;
      carry = text.slice(0, OVERLAP);
      end = start;
    }
    return null;
  } catch (e) {
    log(`log tail unreadable (${CC_LOG}): ${e.message}`);
    return null;
  } finally {
    if (fd !== undefined) closeSync(fd);
  }
}

function providerDefinition(id) {
  return (async () => {
    const { Database } = await import("bun:sqlite");
    const db = new Database(CC_DB, { readonly: true });
    try {
      const row = db
        .query("SELECT settings_config FROM providers WHERE app_type = 'opencode' AND id = ?")
        .get(id);
      return row ? JSON.parse(row.settings_config.replace(/^\uFEFF/, "")) : null;
    } finally {
      db.close();
    }
  })();
}

// Fallback for a provider with no entry in provider-models.json, so a newly
// added provider still routes sensibly instead of failing.
function deriveRoles(models) {
  const ids = Object.keys(models || {});
  if (ids.length === 0) return null;
  const agent = ids.find((id) => /flash/i.test(id)) || ids[0];
  const main = ids.find((id) => /(glm|code|latest)/i.test(id)) || agent;
  return { main, agent };
}

function resolveRoles(id, def) {
  let table = null;
  if (existsSync(MAP_FILE)) {
    try {
      table = readJson(MAP_FILE)[id] || null;
    } catch (e) {
      log(`role mapping unreadable (${MAP_FILE}): ${e.message}`);
    }
  }
  if (table && table.main && table.agent) return table;
  const derived = deriveRoles(def && def.models);
  if (derived) {
    log(`no role mapping for '${id}', derived ${JSON.stringify(derived)}`);
    return derived;
  }
  return null;
}

export const ProviderBridge = async () => ({
  config: async (config) => {
    try {
      const active =
        process.env.OC_PROVIDER || (await activeProviderFromDb()) || activeProviderFromLog();
      if (!active) {
        log("no active opencode provider found; leaving config untouched");
        return;
      }

      const def = await providerDefinition(active);
      config.provider = config.provider || {};
      const live = config.provider[active] || {};

      // Prefer live connection details (cc-switch already wrote the real
      // key/baseURL) and union the model maps so a model added on either side
      // is not silently dropped.
      config.provider[active] = {
        ...(def || {}),
        ...live,
        models: { ...((def && def.models) || {}), ...(live.models || {}) },
      };
      const models = config.provider[active].models;

      const roles = resolveRoles(active, def);
      if (!roles) {
        log(`provider '${active}' exposes no models; leaving config untouched`);
        return;
      }

      // Self-heal: any model the routing needs must exist on the provider, or
      // opencode raises ModelNotFoundError at first use (there is no fallback).
      const ensure = (modelID) => {
        if (modelID && !models[modelID]) {
          models[modelID] = { name: modelID };
          log(`injected missing model definition: ${active}/${modelID}`);
        }
      };
      ensure(roles.main);
      ensure(roles.agent);
      if (roles.vision) ensure(roles.vision);

      config.model = `${active}/${roles.main}`;
      config.small_model = `${active}/${roles.agent}`;

      const agentRole = roles.vision || roles.agent;
      const overrides = roles.agents || {};
      const remapped = [];
      for (const [name, agent] of Object.entries(config.agent || {})) {
        if (!agent || typeof agent !== "object" || Array.isArray(agent)) continue;
        const modelID = overrides[name] || (name === "vision" ? agentRole : roles.agent);
        ensure(modelID);
        agent.model = `${active}/${modelID}`;
        remapped.push(name);
      }

      log(
        `active='${active}' model=${config.model} small_model=${config.small_model} ` +
          `agents=${remapped.length} [${remapped.join(",")}]`,
      );
    } catch (e) {
      log(`ERROR (config left unchanged): ${(e && e.stack) || e}`);
    }
  },
});

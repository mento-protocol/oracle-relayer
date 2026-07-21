import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { URL } from "node:url";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("Polygon mainnet is wired through every relayer surface", async () => {
  const [
    mainTf,
    config,
    relay,
    refill,
    projectVars,
    packageJson,
    addressesJson,
  ] = await Promise.all([
    read("infra/main.tf"),
    read("src/config.ts"),
    read("src/relay.ts"),
    read("src/refill-relayers.ts"),
    read("bin/get-project-vars.sh"),
    read("package.json"),
    read("infra/relayer_addresses.json"),
  ]);
  const scripts = JSON.parse(packageJson).scripts;
  const addresses = JSON.parse(addressesJson);

  assert.match(mainTf, /"mainnet"\s*=\s*\[[^\]]*"polygon"/);
  assert.match(config, /"polygon"/);
  assert.match(relay, /polygon:\s*polygon/);
  assert.match(refill, /\n\s*polygon,\n/);
  assert.match(projectVars, /celo \| monad \| polygon/);
  assert.deepEqual(addresses.polygon, {
    eur_usd: "0xC5f7AcF94Fd76D2fD6c04ffC6C1D519cD16CE7dd",
    usdc_usd: "0x1C267bE736fB7B750243E41b1575Ab872Ae626bb",
  });

  for (const command of [
    "deploy:function:polygon",
    "logs:polygon",
    "logs:tail:polygon",
    "logs:url:polygon",
    "refill:polygon",
    "test:polygon",
  ]) {
    assert.equal(typeof scripts[command], "string", `${command} must exist`);
  }
});

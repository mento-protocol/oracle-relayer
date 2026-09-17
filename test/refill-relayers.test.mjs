import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { URL } from "node:url";

import { computeTopUp } from "../dist/refill-relayers.js";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("tops a standard feed up to 14 days once it drops below 7 days", () => {
  // 15 CELO/day: threshold 105, target 210
  assert.deepEqual(computeTopUp("celo", "eur_usd", 104), {
    costPerDay: 15,
    threshold: 105,
    transferAmount: 107, // ceil(210 - 104) + 1
  });
  assert.equal(computeTopUp("celo", "eur_usd", 105).transferAmount, null);
  assert.equal(computeTopUp("celo", "eur_usd", 400).transferAmount, null);
});

test("uses the per-feed daily cost where a feed burns differently", () => {
  // Composite Celo feeds: 26 CELO/day => threshold 182, target 364
  assert.deepEqual(computeTopUp("celo", "eur_xof", 167.15), {
    costPerDay: 26,
    threshold: 182,
    transferAmount: 198,
  });
  // Hourly Monad stablecoin feeds: 1.5 MON/day => threshold 10.5, target 21
  assert.equal(computeTopUp("monad", "usdc_usd", 10).transferAmount, 12);
  assert.equal(computeTopUp("monad", "eur_usd", 10).costPerDay, 22);
  assert.equal(computeTopUp("polygon", "usdc_usd", 5000).costPerDay, 135);
});

test("gas feeds use the 30/90 day horizon, on celo mainnet only", () => {
  // 0.05 CELO/day: threshold 1.5, target 4.5
  assert.deepEqual(computeTopUp("celo", "celo_php", 1.4), {
    costPerDay: 0.05,
    threshold: 1.5,
    transferAmount: 5, // ceil(4.5 - 1.4) + 1
  });
  assert.equal(computeTopUp("celo", "celo_php", 26).transferAmount, null);
  // CELO/USD relays every few minutes, so it is not a gas feed
  assert.equal(computeTopUp("celo", "celo_usd", 0).costPerDay, 15);
  // On testnets every feed relays once a day at a flat 0.01 tokens per relay
  assert.equal(computeTopUp("celo-sepolia", "celo_php", 0).costPerDay, 0.01);
  assert.equal(
    computeTopUp("monad-testnet", "eur_usd", 1).transferAmount,
    null,
  );
  // Below 7 days (0.07): top up to 14 days (0.14), rounded up plus one token
  assert.equal(
    computeTopUp("polygon-testnet", "eur_usd", 0.05).transferAmount,
    2,
  );
});

test("the automated refill is wired from scheduler to function", async () => {
  const [index, cloudFunction, scheduler] = await Promise.all([
    read("src/index.ts"),
    read("infra/cloud-function.tf"),
    read("infra/scheduler.tf"),
  ]);

  // The Terraform entry point has to match the registered cloud event
  assert.match(index, /cloudEvent\("refillRelayers"/);
  assert.match(cloudFunction, /entry_point\s*=\s*"refillRelayers"/);
  // The function cannot read relayer_addresses.json, so the scheduler message
  // has to carry the rate feed keys under the name index.ts reads
  assert.match(
    scheduler,
    /rate_feeds\s*=\s*keys\(each\.value\.relayer_addresses\)/,
  );
  assert.match(index, /rate_feeds: rateFeedKeys/);
  // A single wallet pays for every transfer, so runs must never overlap
  assert.match(cloudFunction, /max_instance_count\s*=\s*1/);
});

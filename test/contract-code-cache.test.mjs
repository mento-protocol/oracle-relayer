import assert from "node:assert/strict";
import test from "node:test";

import { isContractWithPositiveCache } from "../dist/contract-code-cache.js";

test("rechecks missing code and caches deployed code", async () => {
  const address = "0x0000000000000000000000000000000000000001";
  const positiveCache = new Set();
  let calls = 0;

  assert.equal(
    await isContractWithPositiveCache(
      address,
      async () => {
        calls += 1;
        return undefined;
      },
      positiveCache,
    ),
    false,
  );
  assert.equal(positiveCache.has(address), false);

  assert.equal(
    await isContractWithPositiveCache(
      address,
      async () => {
        calls += 1;
        return "0x6000";
      },
      positiveCache,
    ),
    true,
  );
  assert.equal(positiveCache.has(address), true);

  assert.equal(
    await isContractWithPositiveCache(
      address,
      async () => {
        throw new Error("cached positive should not query RPC");
      },
      positiveCache,
    ),
    true,
  );
  assert.equal(calls, 2);
});

test("treats an explicit empty bytecode response as non-contract code", async () => {
  assert.equal(
    await isContractWithPositiveCache(
      "0x0000000000000000000000000000000000000002",
      async () => "0x",
      new Set(),
    ),
    false,
  );
});

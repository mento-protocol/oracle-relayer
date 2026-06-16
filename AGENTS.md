# Oracle Relayer Instructions

For any protocol-level question that crosses beyond this relayer repo, first
read the private `mento-master-context` router when the checkout is available:

```text
../mento-master-context/.agents/mento-context/README.md
```

This applies before broad repo searches for contracts, deployments, addresses,
ABIs, live on-chain state, oracle state, stable supply, reserve data,
monitoring/data semantics, docs, the whitepaper, business model, or legal/risk
framing. Load only the relevant master-context card(s), then return to this repo
for relayer implementation details.

This repo is source of truth for relayer behavior, not for published contract
addresses or current oracle contract state. Resolve addresses through
`deployments-v2`; verify current values with live RPC at an explicit block. When
answering, mention which master-context card you used or state that the checkout
was unavailable.

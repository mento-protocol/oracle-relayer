export const relayerAbi = [
  {
    type: "constructor",
    inputs: [
      { name: "_rateFeedId", type: "address", internalType: "address" },
      { name: "_sortedOracles", type: "address", internalType: "address" },
      {
        name: "_chainlinkAggregator",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "FIXIDITY_DECIMALS",
    inputs: [],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getAggregators",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "tuple[]",
        internalType: "struct IChainlinkRelayer.ChainlinkAggregator[]",
        components: [
          { name: "aggregator", type: "address", internalType: "address" },
          { name: "invert", type: "bool", internalType: "bool" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "rateFeedId",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "maxTimestampSpread",
    inputs: [],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "relay",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "sortedOracles",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  { type: "error", name: "ExpiredTimestamp", inputs: [] },
  { type: "error", name: "InvalidPrice", inputs: [] },
  { type: "error", name: "NegativePrice", inputs: [] },
  { type: "error", name: "TimestampSpreadTooHigh", inputs: [] },
  { type: "error", name: "TimestampNotNew", inputs: [] },
];

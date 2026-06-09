export const mockAggregatorBatchReporterAbi = [
  {
    type: "function",
    name: "batchReport",
    inputs: [
      { name: "aggregators", type: "address[]", internalType: "address[]" },
      { name: "answers", type: "int256[]", internalType: "int256[]" },
      { name: "timestamps", type: "uint256[]", internalType: "uint256[]" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const;

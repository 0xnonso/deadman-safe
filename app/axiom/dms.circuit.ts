import {
  addToCallback,
  CircuitValue,
  CircuitValue256,
  getHeader,
  getReceipt
} from "@axiom-crypto/client";

// For type safety, define the input types to your circuit here.
// These should be the _variable_ inputs to your circuit. Constants can be hard-coded into the circuit itself.
export interface CircuitInputs {
  blockNumber: CircuitValue;
  txIdx: CircuitValue256;
  logIdx: CircuitValue256;
  safeAddress: CircuitValue;
  to: CircuitValue;
  value: CircuitValue256;
  data: CircuitValue256[];
  operation: CircuitValue;
  safeTxGas: CircuitValue256;
  baseGas: CircuitValue256;
  gasPrice: CircuitValue256;
  gasToken: CircuitValue;
  refundReceiver: CircuitValue;
  nonce: CircuitValue256;
}

// Default inputs to use for compiling the circuit. These values should be different than the inputs fed into
// the circuit at proving time.
export const defaultInputs = {
  "blockNumber": 19590789,
  "txIdx": 47,
  "logIdx": 15,
  "safeAddress": "0xdae8f99814CC3Aa541909cE07E59d0C208FEdbb7",
  "to": "0x40A2aCCbd92BCA938b02010E17A5b8929b49130D",
  "value": 0,
  "data": [
    "0x8d80ff0a",
    "0x0000000000000000000000000000000000000000000000000000000000000020",
    "0x0000000000000000000000000000000000000000000000000000000000000187",
    "0x00dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000",
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    "0x000000000000000000000000000000000000000044a9059cbb00000000000000",
    "0x00000000007566b8c9f2d17804ef21a9a8cca14d0de271e7bb00000000000000",
    "0x000000000000000000000000000000000000000033d00c5040000000000000ca",
    "0x73a6df4c58b84c5b4b847fe8ff39000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    "0x0000000000000000000000000044a9059cbb0000000000000000000000007566",
    "0xb8c9f2d17804ef21a9a8cca14d0de271e7bb0000000000000000000000000000",
    "0x00000000000000000000bb59a27953c60000007566b8c9f2d17804ef21a9a8cc",
    "0xa14d0de271e7bb00000000000000000000000000000000000000000000000004",
    "0x29d069189e000000000000000000000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000000000000000000000000000",
  ],
  "operation": 484,
  "safeTxGas": 1,
  "baseGas": 0,
  "gasPrice": 0,
  "gasToken": "0x0000000000000000000000000000000000000000",
  "refundReceiver": "0x0000000000000000000000000000000000000000",
  "nonce": 5,
};

// The function name `circuit` is searched for by default by our Axiom CLI; if you decide to 
// change the function name, you'll also need to ensure that you also pass the Axiom CLI flag 
// `-f <circuitFunctionName>` for it to work
export const circuit = async (inputs: CircuitInputs) => {
  const header = getHeader(inputs.blockNumber);
  const blockTimestamp: CircuitValue256 = await header.timestamp();

  const receipt = getReceipt(inputs.blockNumber, inputs.txIdx.toCircuitValue());
  const log = receipt.log(inputs.logIdx.toCircuitValue()); // log at index 0
  const txHashTopic: CircuitValue256 = await log.data(
    0,
    "0x442e715f626346e8c54381002da614f62bee8d27386535b2521ec8540898556e"
  );

  const logAddress = await log.address()
  
  if (logAddress.toCircuitValue().address() != inputs.safeAddress.address()) {
    throw new Error("Log not emitted from expected safe address");
  }

  addToCallback(inputs.safeAddress);
  addToCallback(inputs.to);
  addToCallback(inputs.value);
  addToCallback(inputs.operation);
  addToCallback(inputs.safeTxGas);
  addToCallback(inputs.baseGas);
  addToCallback(inputs.gasPrice);
  addToCallback(inputs.gasToken);
  addToCallback(inputs.refundReceiver);
  addToCallback(inputs.nonce);
  addToCallback(blockTimestamp);
  addToCallback(txHashTopic);

  for (const value of inputs.data) {
    addToCallback(value);
  }
};
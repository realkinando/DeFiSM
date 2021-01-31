const Web3 = require("web3");
const web3 = new Web3();
module.exports = {
  // 1Inch
  swapInch: (fromToken, destToken, amtSrc, minReturn, dist) =>
    web3.eth.abi.encodeFunctionCall(
      {
        name: "swap",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "fromToken",
          },
          {
            type: "address",
            name: "destToken",
          },
          {
            type: "uint256",
            name: "amtSrc",
          },
          {
            type: "uint256",
            name: "minReturn",
          },
          {
            type: "uint256[]",
            name: "dist",
          },
        ],
      },
      [fromToken, destToken, amtSrc, minReturn, dist]
    ),
  // Uniswap
  swap: (fromToken, destToken, amount) =>
    web3.eth.abi.encodeFunctionCall(
      {
        name: "swap",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "fromToken",
          },
          {
            type: "address",
            name: "destToken",
          },
          {
            type: "uint256",
            name: "amount",
          },
        ],
      },
      [fromToken, destToken, amount]
    ),
  // Aave
  deposit: (token, amount) =>
    web3.eth.abi.encodeFunctionCall(
      {
        name: "deposit",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "token",
          },
          {
            type: "uint256",
            name: "amount",
          },
        ],
      },
      [token, amount]
    ),
  borrow: (token, amount) =>
    web3.eth.abi.encodeFunctionCall(
      {
        name: "borrow",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "token",
          },
          {
            type: "uint256",
            name: "amount",
          },
        ],
      },
      [token, amount]
    ),
};

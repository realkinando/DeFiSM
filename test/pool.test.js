const { assert } = require("hardhat");
const hre = require("hardhat");
const { swap, deposit, borrow, swapInch } = require("./utils/actions");

// ARTIFACTS
const ETHDAI = artifacts.require("ETHDAI");
const UniswapLogic = artifacts.require("UniswapLogic");
const AaveLogic = artifacts.require("AaveLogic");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

// UNLOCKED ACCOUNT
const ACCOUNTS = ["0xdd79dc5b781b14ff091686961adc5d47e434f4b0"];

// CONTRACT ADDRESSES
const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const AETH_ADDRESS = "0x3a3a65aab0dd2a17e3f1947ba16138cd37d08c04";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const ADAI_ADDRESS = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d";
const ALL = String(
  web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1))
);

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

contract("Pool", () => {
  let pool, uniLogic, aaveLogic, ethdai;

  before(async function () {
    aaveLogic = await AaveLogic.new();
    uniLogic = await UniswapLogic.new();

    ethdai = await ETHDAI.new(aaveLogic.address, uniLogic.address);

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ACCOUNTS,
    });
  });

  it.skip("should send ETH to the Pool contract", async function () {
    await web3.eth.sendTransaction({
      from: ACCOUNTS[0],
      to: pool.address,
      value: toWei(2),
    });

    const balance = await web3.eth.getBalance(pool.address);
    assert.equal(balance, toWei(2));
  });

  it.skip("should swap ETH for DAI in uniswap", async function () {
    const action = swap(ETH_ADDRESS, DAI_ADDRESS, toWei(1));

    await pool.cast([uniLogic.address], [action], {
      from: ACCOUNTS[1],
    });

    const daiToken = await IERC20.at(DAI_ADDRESS);

    const balance = await daiToken.balanceOf(pool.address);
    assert(fromWei(balance) > 0);
  });

  it.skip("should swap ETH for DAI in 1Inch", async function () {
    // Gas expensive for onchain txs, fork takes very long
    // const oneInch = await IOneSplit.at(ONE_SPLIT);
    // const { returnAmount, distribution } = await oneInch.getExpectedReturn(
    //   ETH_ADDRESS,
    //   DAI_ADDRESS,
    //   toWei(1),
    //   2,
    //   0
    // );
    // console.log(distribution);

    await web3.eth.sendTransaction({
      from: ACCOUNTS[0],
      to: oneSplitLogic.address,
      value: toWei(2),
    });

    // prettier-ignore
    const distribution = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    const action = swapInch(
      ETH_ADDRESS,
      DAI_ADDRESS,
      toWei(1),
      0,
      distribution
    );

    console.log(oneSplitLogic.address);

    // await pool.cast([oneSplitLogic.address], [action], {
    //   from: ACCOUNTS[1],
    // });

    await oneSplitLogic.swap(
      ETH_ADDRESS,
      DAI_ADDRESS,
      toWei(1),
      0,
      distribution,
      {
        from: ACCOUNTS[1],
      }
    );

    const daiToken = await IERC20.at(DAI_ADDRESS);

    const balance = await daiToken.balanceOf(oneSplitLogic.address);
    console.log(fromWei(balance));
    // assert(fromWei(balance) > 0);
  });

  it.skip("should supply DAI to Aave", async function () {
    const action = deposit(DAI_ADDRESS, ALL);

    await pool.cast([aaveLogic.address], [action], {
      from: ACCOUNTS[1],
    });

    const adaiToken = await IERC20.at(ADAI_ADDRESS);

    const balance = await adaiToken.balanceOf(pool.address);
    assert(fromWei(balance) > 0);
  });

  it.skip("should create a leverage ETH position", async function () {
    const balance = await web3.eth.getBalance(pool.address);
    console.log("\nStarting ETH balance:", fromWei(balance));

    const actions = [];

    actions.push(deposit(ETH_ADDRESS, ALL));
    actions.push(borrow(DAI_ADDRESS, web3.utils.toWei("300")));
    actions.push(swap(DAI_ADDRESS, ETH_ADDRESS, ALL));
    actions.push(deposit(ETH_ADDRESS, ALL));

    const { receipt } = await pool.cast(
      [
        aaveLogic.address,
        aaveLogic.address,
        uniLogic.address,
        aaveLogic.address,
      ],
      actions,
      {
        from: ACCOUNTS[1],
        gas: 5e6,
      }
    );

    const aethToken = await IERC20.at(AETH_ADDRESS);

    const balance2 = await aethToken.balanceOf(pool.address);
    console.log("Final aETH balance:", fromWei(balance2));
    console.log("Gas Used:", receipt.gasUsed);
    assert(fromWei(balance2) > fromWei(balance));
  });

  it("should fund contract with ETH", async function () {
    await web3.eth.sendTransaction({
      from: ACCOUNTS[0],
      to: ethdai.address,
      value: toWei(2),
    });

    const balance = await web3.eth.getBalance(ethdai.address);
    console.log("\nStarting ETH balance:", fromWei(balance));
  });

  it("should open a Long ETH position", async function () {
    const { receipt } = await ethdai.longETH({
      from: ACCOUNTS[1],
      gas: 5e6,
    });
    console.log("Gas Used:", receipt.gasUsed);

    // const aethToken = await IERC20.at(AETH_ADDRESS);
    // const daiToken = await IERC20.at(DAI_ADDRESS);

    // const balance2 = await aethToken.balanceOf(ethdai.address);
    // console.log("Final aETH balance:", fromWei(balance2));
    // assert(fromWei(balance2) > fromWei(balance));
  });

  it("should close ETH Long Position and end with DAI", async function () {
    // const balance = await web3.eth.getBalance(ethdai.address);
    // console.log("\nStarting ETH balance:", fromWei(balance));

    const { receipt } = await ethdai.holdDAI({
      from: ACCOUNTS[1],
      gas: 5e6,
    });
    console.log("Gas Used:", receipt.gasUsed);

    // const aethToken = await IERC20.at(AETH_ADDRESS);
    // const daiToken = await IERC20.at(DAI_ADDRESS);

    // const balance2 = await aethToken.balanceOf(ethdai.address);
    // console.log("Final aETH balance:", fromWei(balance2));
    // assert(fromWei(balance2) > fromWei(balance));
  });

  it("should open ETH Short Position", async function () {
    // const balance = await web3.eth.getBalance(ethdai.address);
    // console.log("\nStarting ETH balance:", fromWei(balance));

    const { receipt } = await ethdai.shortETH({
      from: ACCOUNTS[1],
      gas: 5e6,
    });
    console.log("Gas Used:", receipt.gasUsed);

    // const aethToken = await IERC20.at(AETH_ADDRESS);
    // const daiToken = await IERC20.at(DAI_ADDRESS);

    // const balance2 = await aethToken.balanceOf(ethdai.address);
    // console.log("Final aETH balance:", fromWei(balance2));
    // assert(fromWei(balance2) > fromWei(balance));
  });
});

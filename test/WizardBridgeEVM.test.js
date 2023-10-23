const { deployments, web3, ethers, artifacts } = require("hardhat");

const helpers = require("./helpers");

const toWei = web3.utils.toWei;

describe("WizardBridgeEVM", async () => {
  beforeEach(async () => {
    await deployments.fixture();
  });

  it("mintToBridgeOut without calling bridgeOut", async () => {
    const { bridge, jfin, bob, signer, currentBlock } = await helpers.setup();

    let txHash = web3.eth.abi.encodeParameter('uint256', '2345675643');
    let txSigned = await web3.eth.sign(txHash, signer);

    await bridge.mintToBridgeOut({
      sourceChain: 2221,
      token: jfin.address,
      amount: toWei("1000"),
      receiver: bob,
      wrappedTokenName: "JFIN",
      wrappedTokenSymbol: "JFIN",
      txHash: txHash,
      txSigned: txSigned,
      timestamp: currentBlock.timestamp
    }, {from: bob}); 
  });

  it("unlockToBridgeIn with another person", async () => {
    const { bridge, jfin, bob, marry, signer, currentBlock } = await helpers.setup();
    await jfin.mint(bob, toWei("1000"));
    helpers.expectToBalanceOfEqual(jfin, bob, toWei("1000"));
    await jfin.approve(bridge.address, toWei("100"), {from: bob});

    // bob call bridgeOut
    await bridge.bridgeOut(1111, jfin.address, toWei("100"), {from: bob});
    let txHash = ethers.utils.solidityKeccak256(
      ['uint32', 'address', 'uint256', 'address', 'uint256'],
      [2223, jfin.address, toWei("100"), marry, currentBlock.timestamp]
    )
    let txSigned = await web3.eth.sign(txHash, signer);

    // marry call unlockToBridgeIn
    await bridge.unlockToBridgeIn({
      sourceChain: 1111,
      token: jfin.address,
      amount: toWei("100"),
      receiver: marry,
      txHash: txHash,
      txSigned: txSigned,
      timestamp: currentBlock.timestamp
    }, {from: marry});

    helpers.expectToBalanceOfEqual(jfin, marry, toWei("100"));

  });


});
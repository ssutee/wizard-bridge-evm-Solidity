const { expect } = require("./chai");

module.exports = async (token, address, value) => {
  let result = await token.balanceOf(address);
  expect(result.toString()).to.equal(value.toString());
};

// const Connect = "0xd486041794094A39965590A89BAe8aB0e29e0396"

module.exports = async function (deployer) {
  await deployer.deploy(Connect, web3.utils.toWei(process.env.INITIAL_SUPPLY));
  const connect = await Connect.deployed();
  }
var Registry = artifacts.require("./OptractRegistry.sol");
var Optract  = artifacts.require("./Optract.sol");
var ERC20 = artifacts.require("./ERC20.sol");
var StandardToken = artifacts.require("./StandardToken.sol");
var DAI = artifacts.require("./DAI.sol");
var SafeMath = artifacts.require("./SafeMath.sol");
var BlockRegistry = artifacts.require("./BlockRegistry.sol");
var MemberShip = artifacts.require("MemberShip.sol");

module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  deployer.link(SafeMath, [StandardToken, BlockRegistry]);
  deployer.deploy(StandardToken);
  deployer.deploy(BlockRegistry);
  deployer.deploy(MemberShip);
  deployer.deploy(DAI).then((iDAI) => {
	let DAIAddr = iDAI.address;
  	deployer.link(SafeMath, Optract);
	return deployer.deploy(Optract, "0", "0", "0", "0x0000000000000000000000000000000000000000"
					 , "0x0000000000000000000000000000000000000000"
					 , "0x0000000000000000000000000000000000000000", DAIAddr).then(() => 
	{
  		deployer.link(Optract, Registry);
		return deployer.deploy(Registry, DAIAddr, BlockRegistry.address).then((iReg) => {
			console.log(`ETH-DAI Registry Address: ${iReg.address}`);
			console.log(`Done!`);
		})
	})
	.catch((err) => { console.trace(err); throw err; });
  })
  .catch((err) => { console.trace(err); throw err; });
}

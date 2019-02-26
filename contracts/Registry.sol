pragma solidity ^0.5.2;

import "./ERC20.sol";
import "./Optract.sol";
//import "./SafeMath.sol";

contract OptractRegistry { // PoC ETH-DAI Optract
	address[3] public operators;
	address public currencyTokenAddr; // presumably 'DAI'
	address public blkAddr; // side-chain merkle records
	uint public initialPayment = 5000000000000000000; // 5 DAIs
	uint public totalOpts = 0;
	bool public paused = false;

	struct optractRecord {
		uint expiredTime; // timestamp
		uint since; // timestamp
	}

	mapping (uint => address) optractRecordsByIndex;
	mapping (address => optractRecord) optractRecordsByAddress;

	// Modifiers
	modifier operatorOnly() {
		require(msg.sender == operators[0] || msg.sender == operators[1] || msg.sender == operators[2]);
		_;
	}

	modifier notPaused() {
		require(paused == false);
		_;
	}

	// Constructor
	constructor(address _currencyTokenAddr) public {
		operators[0] = msg.sender;
		currencyTokenAddr = _currencyTokenAddr;
	}

	function createOptract(uint256 ETHAmount, uint256 totalPrice, uint period) external notPaused {
		require(ERC20(currencyTokenAddr).allowance(msg.sender, address(this)) >= initialPayment);
		require(period >= 30 days && period <= 365 days);
		require(ETHAmount >= 3);

		optractRecord memory optRcd;
		Optract opt = new Optract(ETHAmount, totalPrice, address(this), msg.sender, blkAddr, currencyTokenAddr);
		require(ERC20(currencyTokenAddr).transferFrom(msg.sender, address(opt), initialPayment));

		optRcd.expiredTime = block.timestamp + period;
		optRcd.since = block.timestamp;

		totalOpts = totalOpts + 1;
		optractRecordsByIndex[totalOpts] = address(opt); // mapping start from uint key = 1
		optractRecordsByAddress[address(opt)] = optRcd;
	}

	// Constant functions
	function queryInitPrice() public view returns (uint) { 
		return initialPayment; 
	}

	function isExpired(address optractAddress) public view returns (bool) {
		return block.timestamp > optractRecordsByAddress[optractAddress].expiredTime;
	}

	function getExpireTime() public view returns (uint) {
		require(optractRecordsByAddress[msg.sender].expiredTime >= block.timestamp);
		require(optractRecordsByAddress[msg.sender].since > 0);

		return optractRecordsByAddress[msg.sender].expiredTime;
	}

	function activeOptracts(uint start, uint length) public view returns (
		address[] memory addrlist, 
		   uint[] memory expTimeList, 
		   uint[] memory priceList, 
		   uint[] memory ETHList,
		   uint[] memory opriceList, 
		   bool[] memory filled	) 
	{
		require(start > 0 && length > 0);
		require(totalOpts > 0 && totalOpts >= start);

		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

		for (uint i = start; i <= start + length - 1; i++) {
			address optAddr = optractRecordsByIndex[i];
			if (Optract(optAddr).queryOnStock() == false || optractRecordsByAddress[optAddr].expiredTime - 8 hours <= block.timestamp) continue;

			if (optAddr.balance == Optract(optAddr).queryOrderSize()) {
				filled[i-start] = true;
			} else {
				filled[i-start] = false;
			}

			addrlist[i-start] = optAddr;
			expTimeList[i-start] = optractRecordsByAddress[optAddr].expiredTime;
			priceList[i-start] = Optract(optAddr).queryOrderPrice();
			ETHList[i-start] = Optract(optAddr).queryOrderSize();
			opriceList[i-start] = Optract(optAddr).queryOptionPrice();
		}
	}
}

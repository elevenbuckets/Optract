pragma solidity ^0.5.2;

import "./ERC20.sol";
import "./Optract.sol";
import "./SafeMath.sol";

contract OptractRegistry { // PoC ETH-DAI Optract
	address[3] public operators;
	address public currencyTokenAddr; // presumably 'DAI'
	address public blkAddr; // side-chain merkle records
	uint public initialPayment = 5000000000000000000; // 5 DAIs
	uint public totalOpts = 0;
	bool public paused = false;

	struct optractRecord {
		address optractAddress;
		uint expiredTime; // timestamp
		uint since; // timestamp
	}

	mapping (uint => optractRecord) optractRecords;

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
		require(ERC20(currencyTokenAddr).allowance(msg.sender, this) >= initialPayment);
		require(period >= 30 days && period <= 365 days);
		require(ETHAmount >= 3);

		optractRecord memory optRcd;
		Optract opt = new Optract(ETHAmount, totalPrice, address(this), msg.sender, blkAddr);
		require(ERC20(currencyTokenAddr).transferFrom(msg.sender, address(opt), initialPayment));

		optractRecord.optractAddress = address(opt);
		optractRecord.expiredTime = block.timestamp + period;
		optractRecord.since = block.timestamp;
		totalOpts = totalOpts + 1;
	}

	// Constant functions
	function activeOptracts(uint start, uint length) public view returns (
		address[] memory addrlist, 
		   uint[] memory expTimeList, 
		   uint[] memory priceList, 
		   uint[] memory ETHList ) 
		{
			require(start > 0 && length > 0);
			require(totalOpts > 0);

			if (start + length > totalOpts) {
				length = totalOpts - start + 1;
			}

			for (uint i = start; i <= start + length - 1; i++) {
				addrlist.push(optractRecords[i].optractAddress);
				expTimeList.push(optractRecords[i].expiredTime);
				priceList.push(Optract(optractRecords[i].optractAddress).queryOrderPrice());
				ETHList.push(Optract(optractRecords[i].optractAddress).queryOrderSize());
			}
		}
}

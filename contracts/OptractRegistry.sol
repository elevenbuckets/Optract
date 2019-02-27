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
		address initialOwner; 
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

        bool public debug1 = true;
        bool public debug2 = true;
        bool public debug3 = true;
        bool public debug4 = true;
        function setDebugParams(bool _debug1, bool _debug2, bool _debug3, bool _debug4) public {
                debug1 = _debug1;
                debug2 = _debug2;
                debug3 = _debug3;
                debug4 = _debug4;
        }

	function createOptract(uint256 ETHAmount, uint256 totalPrice, uint period) external notPaused {
	        if (debug1){
                    require(ERC20(currencyTokenAddr).allowance(msg.sender, address(this)) >= initialPayment);
                }
                if (debug2){
                    require(period * 1 days >= 30 days && period * 1 days <= 365 days);
                }
                if (debug3){
                    require(ETHAmount >= 3 ether);
                }

		optractRecord memory optRcd;
                Optract opt = new Optract(ETHAmount, totalPrice, address(this), msg.sender, blkAddr, currencyTokenAddr);

                if (debug4) {
                    require(ERC20(currencyTokenAddr).transferFrom(msg.sender, address(opt), initialPayment));
                }

                optRcd.expiredTime = block.timestamp + period * 1 days;
                optRcd.initialOwner = msg.sender;

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
		require(optractRecordsByAddress[msg.sender].initialOwner != address(0));

		return optractRecordsByAddress[msg.sender].expiredTime;
	}

	function activeOptracts(uint start, uint length, address owner) public view returns (
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

		if (owner == address(0)) { // list all orders
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
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				address optAddr = optractRecordsByIndex[i];
				if (optractRecordsByAddress[optAddr].initialOwner != owner) continue;
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
}

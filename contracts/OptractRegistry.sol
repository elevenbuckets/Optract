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
        bool public debug2 = false;
        bool public debug3 = false;
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

        function _getNumOfActiveOptracts(uint start, uint length, address owner) public view returns (uint) {
	        // will be internal function so don't check requirements
	        uint activeLength = 0;
		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}
		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false
				    || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp) continue;
				activeLength = activeLength + 1;
	
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				if (optractRecordsByAddress[optractRecordsByIndex[i]].initialOwner != owner) continue;
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false
				    || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp) continue;
				activeLength = activeLength + 1;
			}
		}
		return activeLength;
        }

	function activeOptractsExpiretime(uint start, uint length, address owner) public view returns (
	        address[] memory,
		   uint[] memory)
	{
	        // will be internal function so don't check requirements
		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

                uint activeLength = _getNumOfActiveOptracts(start, length, owner);
		address[] memory addrlist = new address[](activeLength);
		uint[] memory expTimeList= new uint[](activeLength);
		uint count = 0;
		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp) continue;
	
				addrlist[count] = optractRecordsByIndex[i];
				expTimeList[count] = optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime;
				count += 1;
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				if (optractRecordsByAddress[optractRecordsByIndex[i]].initialOwner != owner) continue;
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp) continue;
	
				addrlist[count] = optractRecordsByIndex[i];
				expTimeList[count] = optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime;
				count += 1;
			}
		}
		return (addrlist, expTimeList);
        }

	function activeOptractsPrices(uint start, uint length, address owner) public view returns (
		address[] memory,
		   uint[] memory,
		   uint[] memory,
		   uint[] memory )
	{
	        // will be internal function so don't check requirements

		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

                uint activeLength = _getNumOfActiveOptracts(start, length, owner);
		address[] memory addrlist = new address[](activeLength);
		uint[] memory priceList = new uint[](activeLength);
		uint[] memory ETHList = new uint[](activeLength);
		uint[] memory opriceList = new uint[](activeLength);
		uint count = 0;

		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp) continue;
	
				addrlist[count] = optractRecordsByIndex[i];
				priceList[count] = Optract(optractRecordsByIndex[i]).queryOrderPrice();
				ETHList[count] = Optract(optractRecordsByIndex[i]).queryOrderSize();
				opriceList[count] = Optract(optractRecordsByIndex[i]).queryOptionPrice();
				count += 1;
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				if (optractRecordsByAddress[optractRecordsByIndex[i]].initialOwner != owner) continue;
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp) continue;
	
				addrlist[count] = optractRecordsByIndex[i];
				priceList[count] = Optract(optractRecordsByIndex[i]).queryOrderPrice();
				ETHList[count] = Optract(optractRecordsByIndex[i]).queryOrderSize();
				opriceList[count] = Optract(optractRecordsByIndex[i]).queryOptionPrice();
				count += 1;
			}
		}
		return (addrlist, priceList, ETHList, opriceList);
	}

	function activeOptractsFilledStatus(uint start, uint length, address owner) public view returns (
	    address[] memory,
	    bool[] memory )
	{
	        // will be internal function so don't check requirements

		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

                uint activeLength = _getNumOfActiveOptracts(start, length, owner);
		address[] memory addrlist = new address[](activeLength);
		bool[] memory filled = new bool[](activeLength);
		uint count = 0;

		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				address optAddr = optractRecordsByIndex[i];
				if (Optract(optAddr).queryOnStock() == false || optractRecordsByAddress[optAddr].expiredTime - 8 hours <= block.timestamp) continue;
	
				if (optAddr.balance == Optract(optAddr).queryOrderSize()) {
					filled[count] = true;
				} else {
					filled[count] = false;
				}
				addrlist[count] = optAddr;
				count += 1;
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				address optAddr = optractRecordsByIndex[i];
				if (optractRecordsByAddress[optAddr].initialOwner != owner) continue;
				if (Optract(optAddr).queryOnStock() == false || optractRecordsByAddress[optAddr].expiredTime - 8 hours <= block.timestamp) continue;
	
				if (optAddr.balance == Optract(optAddr).queryOrderSize()) {
					filled[count] = true;
				} else {
					filled[count] = false;
				}
				addrlist[count] = optAddr;
				count += 1;
			}
		}
		return (addrlist, filled);
	}

	function activeOptracts(uint start, uint length, address owner) public view returns (
		address[] memory,
		   uint[] memory,
		   uint[] memory,
		   uint[] memory,
		   uint[] memory)
	           // bool[] memory )
	{
		require(start > 0 && length > 0);
		require(totalOpts > 0 && totalOpts >= start);

		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}
                uint activeLength = _getNumOfActiveOptracts(start, length, owner);

		address[] memory addrlist = new address[](activeLength);
		uint[] memory expTimeList= new uint[](activeLength);
		uint[] memory priceList = new uint[](activeLength);
		uint[] memory ETHList = new uint[](activeLength);
		uint[] memory opriceList = new uint[](activeLength);
		// bool[] memory filled = new bool[](activeLength);  // stack too deep if include this one

                // assume all the following function calls return same addrlist
		(addrlist, expTimeList) = activeOptractsExpiretime(start, length, owner);
		(addrlist, priceList, ETHList, opriceList) = activeOptractsPrices(start, length, owner);
		// (addrlist, filled) = activeOptractsFilledStatus(start, length, owner);
		// return (addrlist, expTimeList, priceList, ETHList, opriceList, filled);
		return (addrlist, expTimeList, priceList, ETHList, opriceList);
        }

	function inactiveOptractsFilledStatus(uint start, uint length, address owner) public view returns (
	    address[] memory,
	    bool[] memory )
	{
		require(start > 0 && length > 0);
		require(totalOpts > 0 && totalOpts >= start);

		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

                uint inactiveLength = length - _getNumOfActiveOptracts(start, length, owner);
		address[] memory addrlist = new address[](inactiveLength);
		bool[] memory filled = new bool[](inactiveLength);
		uint count = 0;
		if (inactiveLength == 0) return (addrlist, filled);

		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				address optAddr = optractRecordsByIndex[i];
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == true || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours > block.timestamp) continue;
	
				if (optAddr.balance == Optract(optAddr).queryOrderSize()) {
					filled[count] = true;
				} else {
					filled[count] = false;
				}
				addrlist[count] = optAddr;
				count += 1;
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				address optAddr = optractRecordsByIndex[i];
				if (optractRecordsByAddress[optAddr].initialOwner != owner) continue;
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == true || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours > block.timestamp) continue;
	
				if (optAddr.balance == Optract(optAddr).queryOrderSize()) {
					filled[count] = true;
				} else {
					filled[count] = false;
				}
				addrlist[count] = optAddr;
				count += 1;
			}
		}
		return (addrlist, filled);
	}

        function inactiveOptracts(uint start, uint length, address owner) public view returns (
		address[] memory,
		   uint[] memory,
		   uint[] memory,
		   uint[] memory)
        {
		require(start > 0 && length > 0);
		require(totalOpts > 0 && totalOpts >= start);

		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

                uint inactiveLength = length - _getNumOfActiveOptracts(start, length, owner);
		address[] memory addrlist = new address[](inactiveLength);
		uint[] memory priceList = new uint[](inactiveLength);
		uint[] memory ETHList = new uint[](inactiveLength);
		uint[] memory opriceList = new uint[](inactiveLength);
		uint count = 0;
		if (inactiveLength == 0) return (addrlist, priceList, ETHList, opriceList);

		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == true || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours > block.timestamp) continue;
	
				addrlist[count] = optractRecordsByIndex[i];
				priceList[count] = Optract(optractRecordsByIndex[i]).queryOrderPrice();
				ETHList[count] = Optract(optractRecordsByIndex[i]).queryOrderSize();
				opriceList[count] = Optract(optractRecordsByIndex[i]).queryOptionPrice();
				count += 1;
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				if (optractRecordsByAddress[optractRecordsByIndex[i]].initialOwner != owner) continue;
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == true || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours > block.timestamp) continue;
	
				addrlist[count] = optractRecordsByIndex[i];
				priceList[count] = Optract(optractRecordsByIndex[i]).queryOrderPrice();
				ETHList[count] = Optract(optractRecordsByIndex[i]).queryOrderSize();
				opriceList[count] = Optract(optractRecordsByIndex[i]).queryOptionPrice();
				count += 1;
			}
		}
		return (addrlist, priceList, ETHList, opriceList);
        }
}

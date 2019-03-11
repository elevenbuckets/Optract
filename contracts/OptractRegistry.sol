pragma solidity ^0.5.2;

import "./ERC20.sol";
import "./Optract.sol";
//import "./SafeMath.sol";

contract OptractRegistry { // PoC ETH-DAI Optract
	address[3] public operators;
	address public currencyTokenAddr; // presumably 'DAI'
	address public blkAddr; // side-chain merkle records
	uint public constant optionMinPrice = 5000000000000000000; // 5 DAIs
	uint public totalOpts = 0;
	bool public paused = false;

	struct optractRecord {
	        uint id;
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

	function createOptract(uint256 ETHAmount, uint256 totalPrice, uint period, uint optionPrice) external notPaused {
	        require(optionPrice >= optionMinPrice);
                require(ERC20(currencyTokenAddr).allowance(msg.sender, address(this)) >= optionPrice);
                // require(period * 1 days >= 30 days && period * 1 days <= 365 days);
                // require(ETHAmount >= 3 ether);
                // for debug purpose, use ridiculously small values:
                require(period * 1 days >= 1 days && period * 1 days <= 365 days);
                require(ETHAmount >= 3 wei);

		optractRecord memory optRcd;
                totalOpts = totalOpts + 1;
                Optract opt = new Optract(ETHAmount, totalPrice, optionPrice, address(this), msg.sender, blkAddr, currencyTokenAddr);

                require(ERC20(currencyTokenAddr).transferFrom(msg.sender, address(opt), optionPrice));

                optRcd.id = totalOpts;
                optRcd.expiredTime = block.timestamp + period * 1 days;
                optRcd.initialOwner = msg.sender;

                optractRecordsByIndex[totalOpts] = address(opt); // mapping start from uint key = 1
                optractRecordsByAddress[address(opt)] = optRcd;
	}

	function destructRecord() external {
                uint i = optractRecordsByAddress[msg.sender].id;
                delete optractRecordsByIndex[i];
                if (i != totalOpts){
                        optractRecordsByAddress[optractRecordsByIndex[totalOpts]].id = i;
                        optractRecordsByIndex[i] = optractRecordsByIndex[totalOpts];
                        delete optractRecordsByIndex[totalOpts];
                }
                delete optractRecordsByAddress[msg.sender];
                totalOpts -= 1;
        }

	// Constant functions
	function queryOptionMinPrice() public view returns (uint) {
	        return optionMinPrice;
        }

	function isExpired(address optractAddress) public view returns (bool) {
		return block.timestamp > optractRecordsByAddress[optractAddress].expiredTime;
	}

	function getExpireTime() public view returns (uint) {
		require(optractRecordsByAddress[msg.sender].expiredTime >= block.timestamp);
		require(optractRecordsByAddress[msg.sender].initialOwner != address(0));

		return optractRecordsByAddress[msg.sender].expiredTime;
	}

        function queryOptractRecords(address _addr) external view returns (uint, uint, address) {
                return (optractRecordsByAddress[_addr].id,
                        optractRecordsByAddress[_addr].expiredTime,
                        optractRecordsByAddress[_addr].initialOwner);
        }

        // Constant functions: list active and inactive optracts
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

        function activeOptractsLoop(uint start, uint length, address owner, uint8 _idx) public view returns (uint[] memory) {
                require(_idx >= 1 && _idx <= 4, "unknown optract characteristics");
                // _idx: {1: expTimeList, 2: priceList, 3:ETHList, 4: opriceList}
		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}
                uint activeLength = _getNumOfActiveOptracts(start, length, owner);
		uint[] memory returnList = new uint[](activeLength);
		uint count = 0;

		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp) continue;
	
	                        if (_idx == 1) {
                                        returnList[count] = optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime;
                                } else if (_idx == 2) {
                                        returnList[count] = Optract(optractRecordsByIndex[i]).queryOrderPrice();
                                } else if (_idx == 3) {
				        returnList[count] = Optract(optractRecordsByIndex[i]).queryOrderSize();
                                } else if (_idx == 4) {
                                        returnList[count] = Optract(optractRecordsByIndex[i]).queryOptionPrice();
                                }
				count += 1;
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				if (optractRecordsByAddress[optractRecordsByIndex[i]].initialOwner != owner) continue;
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp) continue;
	                        if (_idx == 1) {
                                        returnList[count] = optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime;
                                } else if (_idx == 2) {
                                        returnList[count] = Optract(optractRecordsByIndex[i]).queryOrderPrice();
                                } else if (_idx == 3) {
				        returnList[count] = Optract(optractRecordsByIndex[i]).queryOrderSize();
                                } else if (_idx == 4) {
                                        returnList[count] = Optract(optractRecordsByIndex[i]).queryOptionPrice();
                                }
				count += 1;
			}
		}
		return returnList;
        }

	function activeOptractsFilledStatus(uint start, uint length, address owner) public view returns (address[] memory, bool[] memory) {
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
	
				if (optAddr.balance == Optract(optAddr).queryOrderSize()) {  // or ">="?
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
		   uint[] memory,
	           bool[] memory)
	{
		require(start > 0 && length > 0);
		require(totalOpts > 0 && totalOpts >= start);
		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

		address[] memory addrlist = new address[](_getNumOfActiveOptracts(start, length, owner));
		uint[] memory expTimeList= new uint[](_getNumOfActiveOptracts(start, length, owner));
		uint[] memory priceList = new uint[](_getNumOfActiveOptracts(start, length, owner));
		uint[] memory ETHList = new uint[](_getNumOfActiveOptracts(start, length, owner));
		uint[] memory opriceList = new uint[](_getNumOfActiveOptracts(start, length, owner));
		bool[] memory filled = new bool[](_getNumOfActiveOptracts(start, length, owner));  // stack too deep if include this one

                // assume all the following function calls return same order
		expTimeList = activeOptractsLoop(start, length, owner, 1);
		priceList = activeOptractsLoop(start, length, owner, 2);
		ETHList = activeOptractsLoop(start, length, owner, 3);
		opriceList = activeOptractsLoop(start, length, owner, 4);
		(addrlist, filled) = activeOptractsFilledStatus(start, length, owner);
		return (addrlist, expTimeList, priceList, ETHList, opriceList, filled);
        }


        function _getNumOfInActiveOptracts(uint start, uint length, address owner) public view returns (uint) {
	        // will be internal function so don't check requirements
	        uint inactiveLength = 0;
		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false
				    || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp)
				{
				        inactiveLength +=1;
                                }
	
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				if (optractRecordsByAddress[optractRecordsByIndex[i]].initialOwner != owner) continue;
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false
				    || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp)
                                {
				        inactiveLength += 1;
                                }
			}
		}
		return inactiveLength;
        }

        function inactiveOptractsLoop(uint start, uint length, address owner, uint8 _idx) public view returns (uint[] memory) {
                require(_idx >= 1 && _idx <= 4, "unknow optract chracteristics");
                // _idx: {1: expTimeList, 2: priceList, 3:ETHList, 4: opriceList}
		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}
                uint inactiveLength = _getNumOfInActiveOptracts(start, length, owner);
		uint[] memory returnList = new uint[](inactiveLength);
		if (inactiveLength == 0) return (returnList);
		uint count = 0;

		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false
				    || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp)

				{
                                        if (_idx == 1) {
                                                returnList[count] = optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime;
                                        } else if (_idx == 2) {
                                                returnList[count] = Optract(optractRecordsByIndex[i]).queryOrderPrice();
                                        } else if (_idx == 3) {
                                                returnList[count] = Optract(optractRecordsByIndex[i]).queryOrderSize();
                                        } else if (_idx == 4) {
                                                returnList[count] = Optract(optractRecordsByIndex[i]).queryOptionPrice();
                                        }
                                        count += 1;
                                }
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				if (optractRecordsByAddress[optractRecordsByIndex[i]].initialOwner != owner) continue;
				if (Optract(optractRecordsByIndex[i]).queryOnStock() == false
				    || optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime - 8 hours <= block.timestamp)
                                {
                                        if (_idx == 1) {
                                                returnList[count] = optractRecordsByAddress[optractRecordsByIndex[i]].expiredTime;
                                        } else if (_idx == 2) {
                                                returnList[count] = Optract(optractRecordsByIndex[i]).queryOrderPrice();
                                        } else if (_idx == 3) {
                                                returnList[count] = Optract(optractRecordsByIndex[i]).queryOrderSize();
                                        } else if (_idx == 4) {
                                                returnList[count] = Optract(optractRecordsByIndex[i]).queryOptionPrice();
                                        }
                                        count += 1;
                                }
			}
		}
		return returnList;
        }

	function inactiveOptractsFilledStatus(uint start, uint length, address owner) public view returns (address[] memory, bool[] memory) {
	        // will be internal function so don't check requirements
		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

                uint inactiveLength = _getNumOfInActiveOptracts(start, length, owner);
		address[] memory addrlist = new address[](inactiveLength);
		bool[] memory filled = new bool[](inactiveLength);
		if (inactiveLength == 0) return (addrlist, filled);
		uint count = 0;

		if (owner == address(0)) { // list all orders
			for (uint i = start; i <= start + length - 1; i++) {
				address optAddr = optractRecordsByIndex[i];
				if (Optract(optAddr).queryOnStock() == false
				    || optractRecordsByAddress[optAddr].expiredTime - 8 hours <= block.timestamp)
                                {
                                        if (optAddr.balance == Optract(optAddr).queryOrderSize()) {
                                                filled[count] = true;
                                        } else {
                                                filled[count] = false;
                                        }
                                        addrlist[count] = optAddr;
                                        count += 1;
                                }
			}
		} else { // list only those initialized by owner
			for (uint i = start; i <= start + length - 1; i++) {
				address optAddr = optractRecordsByIndex[i];
				if (optractRecordsByAddress[optAddr].initialOwner != owner) continue;
				if (Optract(optAddr).queryOnStock() == false
				    || optractRecordsByAddress[optAddr].expiredTime - 8 hours <= block.timestamp)
                                {
                                        if (optAddr.balance == Optract(optAddr).queryOrderSize()) {
                                                filled[count] = true;
                                        } else {
                                                filled[count] = false;
                                        }
                                        addrlist[count] = optAddr;
                                        count += 1;
                                }
	
			}
		}
		return (addrlist, filled);
	}

	function inactiveOptracts(uint start, uint length, address owner) public view returns (
		address[] memory,
		   uint[] memory,
		   uint[] memory,
		   uint[] memory,
		   uint[] memory,
	           bool[] memory)
	{
		require(start > 0 && length > 0);
		require(totalOpts > 0 && totalOpts >= start);

		if (start + length - 1 > totalOpts) {
			length = totalOpts - start + 1;
		}

		address[] memory addrlist = new address[](_getNumOfInActiveOptracts(start, length, owner));
		uint[] memory expTimeList= new uint[](_getNumOfInActiveOptracts(start, length, owner));
		uint[] memory priceList = new uint[](_getNumOfInActiveOptracts(start, length, owner));
		uint[] memory ETHList = new uint[](_getNumOfInActiveOptracts(start, length, owner));
		uint[] memory opriceList = new uint[](_getNumOfInActiveOptracts(start, length, owner));
		bool[] memory filled = new bool[](_getNumOfInActiveOptracts(start, length, owner));

                // assume all the following function calls return same order
		expTimeList = inactiveOptractsLoop(start, length, owner, 1);
		priceList = inactiveOptractsLoop(start, length, owner, 2);
		ETHList = inactiveOptractsLoop(start, length, owner, 3);
		opriceList = inactiveOptractsLoop(start, length, owner, 4);
		(addrlist, filled) = inactiveOptractsFilledStatus(start, length, owner);
		return (addrlist, expTimeList, priceList, ETHList, opriceList, filled);
        }

}

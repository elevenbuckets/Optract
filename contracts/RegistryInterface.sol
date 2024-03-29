pragma solidity ^0.5.2;

interface iOptractRegistry { // PoC ETH-DAI Optract

	function createOptract(uint256 ETHAmount, uint256 totalPrice, uint period, uint optionPrice) external;
	function destructRecord() external;
	function queryOptionMinPrice() external view returns (uint);
	function isExpired(address optractAddress) external view returns (bool);
	function getExpireTime() external view returns (uint);
        function queryOptractRecords(address _addr) external view returns (uint, uint, address);
        function setCurrencyTokenAddr(address newCurrencyTokenAddr) external returns (bool);
        function setBlkAddr(address newBlkAddr) external returns (bool);
        function setMemberCtrAddr(address _addr) external returns (bool);
	function activeOptracts(uint start, uint length, address owner) external view returns (
		address[] memory addrlist, 
		   uint[] memory expTimeList, 
		   uint[] memory priceList, 
		   uint[] memory ETHList,
		   uint[] memory opriceList
	);
	function activeOptractsFilledStatus(uint start, uint length, address owner) external view returns (
		address[] memory addrlist, 
		   bool[] memory filled
	);
}

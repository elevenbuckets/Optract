pragma solidity ^0.5.2;

interface iOptractRegistry { // PoC ETH-DAI Optract

	function createOptract(uint256 ETHAmount, uint256 totalPrice, uint period) external;
	function destructRecord() external;
	function queryInitPrice() external view returns (uint);
	function isExpired(address optractAddress) external view returns (bool);
	function getExpireTime() external view returns (uint);
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

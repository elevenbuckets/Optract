pragma solidity ^0.5.2;
import "./SafeMath.sol";
// import "./RegistryInterface.sol";
// import "./BlockRegistryInterface.sol";

/*
roles:
   * originalOwner: someone want to buy the right of some ETH, pay DAI to ethSeller
   * ethSeller: someone want to sell the rights of some ETH, fill in ETH to this contract
   * buyer: someone want to buy the ownership of those ETH, pay DAI to currentOwner and become new owner
            (can have many buyers)
time:
   * `period`: in order of months
   * the new contract owner cannot sell the ownership right away
*/

contract Optract {
    using SafeMath for uint256;
    address public originalOwner;
    address public currentOwner;
    address public ethSeller;
    address public registryAddr;  // the contract registry
    address public blkAddr;  // the side-chain address
    uint256 public ethAmount;
    uint256 public totalPriceDai;
    uint256 public actionTime;  // right now, the actions are contract creation and newOwner()
    uint256 public period;  // length of time
    bool onStock = true;
    bool expired = true;  // query "registry" to determine when to expire

    constructor(uint256 _ethAmount, uint256 _totalPriceDai, address _registryAddr, address _originalOwner, address _blkAddr) public {
        ethAmount = _ethAmount;
        totalPriceDai = totalPriceDai;
        registryAddr = _registryAddr;
        originalOwner = _originalOwner;
        currentOwner = _originalOwner;
        blkAddr = _blkAddr;
        actionTime = block.timestamp;
    }


    modifier ownerOnly() {
        require(msg.sender = currentOwner);
        _;
    }

    modifier isOnStock() {
        require(onStock == true);
        _;
    }

    modifier isExpired() {
        require(expired == true);
        _;
    }

    modifier isNotExpired() {
        require(expired == false);
        _;
    }

    // after construct, need a ethSeller to fill in ETH, and the ethSeller obtain DAI
    function fillInEth() public {
        require(msg.value >= ethAmount);
        ethSeller = msg.sender;
        actionTime = block.timestamp;
        iDAI.transfer(msg.sender, msg.sender, totalPriceDai);
    }

    // a successful buyer get the ownership (verified through state channel)
    function newOwner(
        bytes32[] memory proof,
        bool[] memory isLeft,
        bytes32 targetLeaf,
        bytes32 _merkleRoot,
        bool _onStock,
        uint256 newPrice
    ) public isOnStock returns(bool) {
        // verify: msg.sender is in targetLeaf
        require(BlockRegistryInterface(scAddr).merkleTreeValidator(bytes32[] memory proof, bool[] memory isLeft, bytes32 targetLeaf, bytes32 _merkleRoot) == true);
        require(block.timestamp > actionTime + 2 hours, "");

        // new owner
        onStock = _onStock;  // if set to false, the new owner cannot sell it again (or can by toggle this bool?)
        currentOwner = msg.sender;
        totalPriceDai = newPrice;

        // the new owner transfer ETH to contract owner
        msg.sender.transfer(ethAmount);

        return true;
    }

    // function setNewDaiPrice(uint newPrice) public ownerOnly {
    // }


    // two ways to end this contract: (before expire) the last owner withdraw ETH or (after expire) ethSeller take ETH back
    function ownerWithdrawETH() public isNotExpired {
        require(msg.sender == currentOwner);
        onStock = false;
        // require(block.timestamp > actionTime + 2 hours, "");  // cannot withdraw right away
        msg.sender.transfer(address(this).balance);
    }

    function takeBackETH() public expired {
        require(msg.sender == ethSeller);
        onStock = false;
        msg.sender.transfer(address(this).balance);
    }

    // query functions
    function queryOrderPrice() public returns (uint256){
        return totalPriceDai;
    }

    function queryOrderSize() public returns (uint256){
        return ethAmount;
    }


}

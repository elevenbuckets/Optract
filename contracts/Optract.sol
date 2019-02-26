pragma solidity ^0.5.2;
import "./SafeMath.sol";
// import "./RegistryInterface.sol";
// import "./BlockRegistryInterface.sol";

/*
roles:
   * originalOwner: someone want to buy the right of some ETH, pay DAI to ethSeller
   * ethSeller: someone want to sell the rights of some ETH, fill in ETH to this contract
   * buyer: someone want to buy the ownership of those ETH, pay DAI to currentOwner and become new owner
            (originalOwner is the first buyer)
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
    uint256 public totalPriceInDai;
    uint256 public optionPrice;
    uint256 public actionTime;  // right now, the actions are contract creation and newOwner()
    uint256 public period;  // length of time
    bool public onStock = false;
    bool public expired = false;  // query "registry" to determine when to expire
    bool public exercised = false;

    constructor (
        uint256 _ethAmount,
        uint256 _totalPriceInDai,
        address _registryAddr,
        address _originalOwner,
        address _blkAddr
    ) public {
        ethAmount = _ethAmount;
        totalPriceInDai = _totalPriceInDai;
        registryAddr = _registryAddr;
        originalOwner = _originalOwner;
        blkAddr = _blkAddr;

        currentOwner = _originalOwner;
        actionTime = block.timestamp;  // use this to avoid some too soon operations
        optionPrice = registry(registryAddr).queryInitPrice();
    }

    modifier ownerOnly() {
        require(msg.sender = currentOwner, "not owner");
        _;
    }

    modifier isOnStock() {
        require(onStock == true, "not on stock");
        _;
    }

    modifier isExpired() {
        require(registry(registryAddr).isExpired == true, "can no longer excercise");
        _;
    }

    modifier isNotExpired() {
        require(registry(registryAddr).isExpired == false, "now can excercise");
        _;
    }

    // after construct, need a ethSeller to fill in ETH, and the ethSeller obtain DAI
    function fillInEth() public payable {
        require(ethSeller == address(0), "others fill ETH already");  // only one can fill in ETH
        require(msg.value == ethAmount, "need to deposit exact amount of ETH");
        ethSeller = msg.sender;
        actionTime = block.timestamp;
        iDAI.transfer(originalOwner, msg.sender, optionPrice);
    }

    // a successful buyer get the ownership (verified through state channel)
    function newOwner(
        bytes32[] memory proof,
        bool[] memory isLeft,
        bytes32 targetLeaf,
        bytes32 merkleRoot
    ) public isOnStock returns(bool) {
        // verify: from msg.sender generate the corresponding targetLeaf
        require(iBlockRegistry(blkAddr).merkleTreeValidator(proof, isLeft, targetLeaf, merkleRoot) == true, "invalid Merkle Proof");
        require(block.timestamp > actionTime + 2 hours, "cannot change ownership too soon");
        address prevOwner = currentOwner;
        uint dealPrice = optionPrice;

        // new owner
        onStock = false;
        currentOwner = msg.sender;
        optionPrice = newPrice;

        // the new owner transfer DAI to contract owner
        iDAI.transfer(currentOwner, prevOwner, dealPrice);
        iDAI.transfer(currentOwner, iBlockRegistry(blkAddr), dealPrice/500);  // 0.2% fee to block contract

        return true;
    }

    function putOnStock(uint256 _newOptionPrice) public ownerOnly {
        // call it when a buyer want to sell the option
        require(onStock == false, "can only put on Stock once");
        onStock = true;
        newPrice = _newOptionPrice;
    }

    function setNewOptionPrice(uint newPrice) public ownerOnly {
        // add a time restriction?
        optionPrice = newPrice;
    }

    // two ways to end this contract:
    //   (isNotExpired) the last owner pay DAI and withdraw ETH or (expired) ethSeller take ETH back
    function currentOwnerExercise() public ownerOnly isNotExpired {
        onStock = false;
        exercised = true;
        // require(block.timestamp > actionTime + 2 hours, "");  // cannot withdraw right away
        iDAI.transfer(currentOwner, ethSeller, totalPriceInDai);
        msg.sender.transfer(address(this).balance);
        selfdestruct(msg.sender);
    }

    function ethSellerWithdraw() public expired {
        // if the contract owner don't exercise, ethSeller get the eth back
        require(msg.sender == ethSeller, "only ethSeller can call it");
        require(exercised == false, "already exercised");
        onStock = false;
        msg.sender.transfer(address(this).balance);
        selfdestruct(msg.sender);
    }

    // query functions
    function queryOptionPrice() public returns (uint256) {
        return optionPrice;
    }

    function queryOrderPrice() public returns (uint256) {
        return totalPriceInDai;
    }

    function queryOrderSize() public returns (uint256) {
        return ethAmount;
    }

    function queryOnStock() public returns (bool) {
        return onStock;
    }

}

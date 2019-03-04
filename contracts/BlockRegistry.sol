pragma solidity ^0.5.2;
import "./SafeMath.sol";


contract BlockRegistry{
    using SafeMath for uint256;

    // Variables
    address[4] public managers;
    address[16] public validators;
    uint constant public period_all = 20;
    uint public initHeight;
    uint public sblockNo;
    uint constant public sblockTimeStep = 15 minutes;  // better way to define?

    struct blockStat{
        uint blockHeight;
        bytes32 merkleRoot;
        string ipfsAddr;
        // uint timestamp;
    }

    mapping (uint => blockStat) public blockHistory;
    // ex:
    // function newBlock(bytes32 merkleRoot, bytes32 ipfsAddr) external validatorOnly {
    //      blockHistory[sblockNo] = blockStat(block.number, merkleRoot, ipfsAddr)
    // }


    constructor() public {
        // always INITIALIZE ARRAY VALUES!!!
        managers = [ 0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
            0x4AD56641C569C91C64C28a904cda50AE5326Da41,
            0xaF7400787c54422Be8B44154B1273661f1259CcD,
            address(0)];
    }

    // Modifiers
    modifier managerOnly() {
        require(msg.sender == managers[0] || msg.sender == managers[1] || msg.sender == managers[2] || msg.sender == managers[3]);
        _;
    }

    // query
    function getSblockNo() external view returns (uint) {
        return sblockNo;
    }

}

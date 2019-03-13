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
    uint public prevTimeStamp;
    uint public sblockTimeStep = 15 minutes;  // better way to define?

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
        validators = [ 0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
            0x4AD56641C569C91C64C28a904cda50AE5326Da41,
            0xaF7400787c54422Be8B44154B1273661f1259CcD,
            address(0), address(0), address(0), address(0), address(0),
            address(0), address(0), address(0), address(0), address(0),
            address(0), address(0), address(0)];
        prevTimeStamp = block.timestamp - sblockTimeStep;
    }

    // Modifiers
    modifier managerOnly() {
        require(msg.sender == managers[0] || msg.sender == managers[1] || msg.sender == managers[2] || msg.sender == managers[3]);
        _;
    }

    modifier validatorOnly() {
        require(msg.sender == validators[0] || msg.sender == validators[1] || msg.sender == validators[2] || 
                msg.sender == validators[3] || msg.sender == validators[4] || msg.sender == validators[5] || 
                msg.sender == validators[6] || msg.sender == validators[7] || msg.sender == validators[8] || 
                msg.sender == validators[9] || msg.sender == validators[10] || msg.sender == validators[11] || 
                msg.sender == validators[12] || msg.sender == validators[13] || msg.sender == validators[14] ||
                msg.sender == validators[15]);
        _;
    }

    function submitMerkleRoot(uint _initHeight, bytes32 _merkleRoot, string memory _ipfsAddr) public validatorOnly returns (bool) {
        // require(block.timestamp >= prevTimeStamp + sblockTimeStep, 'too soon');
        require(block.timestamp >= prevTimeStamp + 2 minutes, 'time step between blocks too short');  // for test purpose
        // uncomment following for debug purpose
        // require(block.number >= _initHeight + period_all && block.number <= _initHeight + period_all + 4);
        // require(blockHistory[_initHeight].blockHeight == 0 &&
        //         blockHistory[_initHeight].merkleRoot == 0x0 &&
        //         keccak256(abi.encodePacked(blockHistory[_initHeight].ipfsAddr)) == keccak256(abi.encodePacked('')),
        //         'side-block exists');
        blockHistory[_initHeight] = blockStat(_initHeight, _merkleRoot, _ipfsAddr);
        sblockNo += 1;
        return true;
    }

    // query
    function getSblockNo() external view returns (uint) {
        return sblockNo;
    }

    function getBlockInfo(uint _sblockNo) external view returns (uint, bytes32, string memory) {
        return (blockHistory[_sblockNo].blockHeight, blockHistory[_sblockNo].merkleRoot, blockHistory[_sblockNo].ipfsAddr);
    }

}

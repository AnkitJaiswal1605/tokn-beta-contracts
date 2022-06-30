// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ToknITO is Initializable, UUPSUpgradeable, PausableUpgradeable, OwnableUpgradeable{
    
    // ToknFactory public toknFactory;
    string public  version;
    IERC20 public usdc;
    address payable public treasury;

    uint public treasuryPercentage;
    

    enum State {Started, Running, Cancelled, Ended}
    
    struct ITOConfig{
        uint toknId;
        address toknAddress;
        uint toknsAvailable;
        uint price;
        address[] investors;
        State itoState;
        mapping(address => uint) bookedTokns;
    }

    // mapping(uint => mapping(address => uint)) public bookedTokns;
    mapping(address => mapping(uint => ITOConfig)) public toknITOs;
    // mapping(address => uint) public artistTracker;
    // mapping(address => uint) public userTracker;

    
    // address[] public artistList;
    // address[] public userList;


    
    function initialize(IERC20 _usdc) public initializer{
        // toknFactory = _toknFactory;
        __Pausable_init();
        __UUPSUpgradeable_init();
        __Ownable_init();
        usdc = _usdc;
        treasury = payable(msg.sender);
        treasuryPercentage = 13;
    }
    
    
    function setTreasuryPercentage(uint _pc) public onlyOwner whenNotPaused{
        require(msg.sender == treasury, "Caller not authorized");
        treasuryPercentage = _pc;
    }

    function setTreasury(address _treasury) public onlyOwner whenNotPaused{
        require(msg.sender == treasury , "Caller not authorized");
        treasury = payable(_treasury);
    }

    // function getUsersCount() public view returns(uint){
    //     return userList.length;    
    // }
    
    // function isContract(address _addr) private view returns (bool){
    //   uint32 size;
    //   assembly {
    //     size := extcodesize(_addr)
    //   }
    //   return (size > 0);
    // }
    
    // function airdropTracker(uint _id, address _receiver, uint _price) public {
        
    //         address artist = toknFactory.toknIdToArtist(_id);
    //         require(artist == msg.sender || isContract(msg.sender));
    //         if(artistTracker[artist] == 0) {
    //             artistList.push(artist); 
    //         }
    //         artistTracker[artist] += _price;
    //     // }
    //     if(userTracker[_receiver] == 0) {
    //         userList.push(_receiver);
    //     }
    //     userTracker[_receiver] += _price;
    // }
    
    
   
    
    function startITO(address _toknAddress, uint _id, uint _price) public whenNotPaused{
        
        require(msg.sender == OwnableUpgradeable(_toknAddress).owner(), "Caller not authorized");
        toknITOs[_toknAddress][_id].price = _price*10**6;
        toknITOs[_toknAddress][_id].itoState = State.Running;
        toknITOs[_toknAddress][_id].toknsAvailable = ERC1155Upgradeable(_toknAddress).balanceOf(msg.sender, _id);
    }
    
    function stopITO(address _toknAddress, uint _id) public whenNotPaused{
        
        require(msg.sender == OwnableUpgradeable(_toknAddress).owner() && toknITOs[_toknAddress][_id].itoState== State.Running);
        toknITOs[_toknAddress][_id].itoState = State.Ended;
    }    
    
    function getCurrentState(address _toknAddress, uint _id) public view returns(State) {
        
        return toknITOs[_toknAddress][_id].itoState;
    }

    function getITO(address _toknAddress, uint _id) public view returns(uint price, uint available, address[] memory investors, State state) {
        ITOConfig storage ito = toknITOs[_toknAddress][_id];
        price = ito.price;
        available = ito.toknsAvailable;
        investors = ito.investors;
        state = ito.itoState;
        
    }
    
    function investFixedPrice(address _toknAddress, uint _id, uint _qty) public whenNotPaused{
        
        require(_qty <= toknITOs[_toknAddress][_id].toknsAvailable && toknITOs[_toknAddress][_id].itoState == State.Running);
        uint usdcAmount = _qty * toknITOs[_toknAddress][_id].price;
        uint platform_fee = usdcAmount*treasuryPercentage/uint(100);
        usdc.transferFrom(msg.sender, address(this), usdcAmount+platform_fee);
        toknITOs[_toknAddress][_id].toknsAvailable -= _qty;
        toknITOs[_toknAddress][_id].investors.push(payable(msg.sender));
        toknITOs[_toknAddress][_id].bookedTokns[msg.sender] += _qty;
    }

  
  
    function allocateFixedPrice(address _toknAddress, uint _id) public whenNotPaused{
        
        
        require(OwnableUpgradeable(_toknAddress).owner() == msg.sender, "Caller not authorised");
        require(toknITOs[_toknAddress][_id].itoState == State.Ended);
        address[] memory toknInvestors = toknITOs[_toknAddress][_id].investors;
        for(uint i = 0; i < toknInvestors.length; i++) {
            
            ERC1155Upgradeable(_toknAddress).safeTransferFrom(msg.sender, toknInvestors[i], _id, toknITOs[_toknAddress][_id].bookedTokns[toknInvestors[i]], "");
            uint amount = toknITOs[_toknAddress][_id].price * toknITOs[_toknAddress][_id].bookedTokns[toknInvestors[i]];
            uint treasury_amount = amount*treasuryPercentage/uint(100);
          
                usdc.transfer(treasury, treasury_amount);
                usdc.transfer(msg.sender, amount);
        
            
            // airdropTracker(_id, toknInvestors[i], amount);
        }
    }
    
   function getBookedToknsFor(address _toknAddress, address _investor, uint _id) public view returns (uint) {
       return toknITOs[_toknAddress][_id].bookedTokns[_investor];
   }

   function pause() public onlyOwner{
       
        _pause();
    }

    function unPause() public onlyOwner{
        
        _unpause();
    }
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner{
        version = "0.1";
    }
}
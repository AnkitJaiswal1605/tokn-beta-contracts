// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";




contract ToknCollectionV2 is Initializable, ERC1155Upgradeable, UUPSUpgradeable, OwnableUpgradeable, IERC2981Upgradeable {
        string public version;
    using Counters for Counters.Counter;
    Counters.Counter _tokenIdTracker;
   
    

    
    string _baseUri;
    string contractUri;
    uint256 public royaltyPercentage;
    address public treasury;

    mapping(uint => uint) public tokenSupply;
    mapping(string => uint) public songToTokenId;
    mapping(uint => uint) public tokenPrice;
    bool initialized;

    function initialize() public initializer{
       
       
    }

    modifier isNotInitialized(){
        require(!initialized);
        _;
    }

    function initializeState(string calldata _uri, string calldata _contractUri, address _treasury) public isNotInitialized onlyOwner{
        _setURI(_uri);
        _baseUri = _uri;
        contractUri = _contractUri;
        royaltyPercentage = 10;
        treasury = _treasury;
        version = "2.0";
        initialized = true; 
    }

    function contractURI() public view returns (string memory) {
        return contractUri;
    }

     function setRoyaltyPercentage(uint256 _royalty) external onlyOwner {
        require(_royalty >= 0 && _royalty <= 100, "Invalid value enterned.");
        royaltyPercentage = _royalty;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid value enterned.");
        treasury = _treasury;
    }

    function mintNew(uint _qty, string calldata _name, uint _price) public onlyOwner{
        
        _mint(_msgSender(), _tokenIdTracker.current(), _qty, "");
        tokenSupply[_tokenIdTracker.current()] += _qty;
        songToTokenId[_name] = _tokenIdTracker.current();
        tokenPrice[_tokenIdTracker.current()] = _price;
        _tokenIdTracker.increment();
        
    }

    function mintExisting(uint _toknId, uint _qty) public onlyOwner{
        require(_toknId < _tokenIdTracker.current());
        _mint(_msgSender(), _toknId, _qty, "");
        tokenSupply[_toknId] += _qty;
    }

    function uri(uint256 _tokenId) override public view returns (string memory) {
       return string(
           abi.encodePacked(
               _baseUri,
               Strings.toString(_tokenId),
               ".json"
           )
       );
    }   

    function setBaseUri(string calldata _uri) public onlyOwner{
        _baseUri = _uri;
    }

    function setTokenPrice(uint _id, uint _price) public onlyOwner{
        tokenPrice[_id] = _price;
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
    external
    view
    override
    returns (address receiver, uint256 royaltyAmount)
    {
        require(tokenId < _tokenIdTracker.current(), "Nonexistent token");
  
        uint256 amount = salePrice*royaltyPercentage/uint256(100);
        return (treasury, amount);
    } 

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return (
            interfaceId == type(IERC2981Upgradeable).interfaceId ||
            super.supportsInterface(interfaceId)
        );
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner{
        version = "2.0";
    }

    function setContractUri(string calldata _uri) public onlyOwner{
        
        contractUri = _uri;
    }
   
    
}

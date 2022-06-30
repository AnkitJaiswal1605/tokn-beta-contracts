//SPDX-License-Identifier: MIT
 
pragma solidity 0.8.11;

import "./ToknITO.sol";

contract Airdrop is ToknITO {
    
    constructor(ToknFactory _toknFactory, IERC20 _usdc) ToknITO(_toknFactory, _usdc) {
    }
    
    function airdropToArtist(uint _amount) public {
        require(msg.sender == toknFactory.deployer());
        uint totalValue;
        for(uint i = 0; i < artistList.length; i++) {
            totalValue += artistTracker[artistList[i]];
        }
        for(uint j = 0; j < artistList.length; j++) {
            toknFactory.safeTransferFrom(msg.sender, artistList[j], 1, artistTracker[artistList[j]] / totalValue * _amount, "");
            artistTracker[artistList[j]] = 0;
        }
        artistList = new address[](0);
    }
    
    function airdropToUsers(uint _amount) public {
        require(msg.sender == toknFactory.deployer());
        uint totalValue;
        for(uint i = 0; i < userList.length; i++) {
            totalValue += userTracker[userList[i]];
        }
        for(uint j = 0; j < userList.length; j++) {
            toknFactory.safeTransferFrom(msg.sender, userList[j], 1, userTracker[userList[j]] / totalValue * _amount, "");
            userTracker[userList[j]] = 0;
        }
        userList = new address[](0);
    }
    
}
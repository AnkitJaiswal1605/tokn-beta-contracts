// SPDX-License-Identifier: MIT
pragma solidity^0.8.0;

import "./Airdrop.sol";
// import "./ToknFactory.sol";

contract ToknExchange{
    
    ToknFactory public toknFactory;
    Airdrop public airdrop;
    IERC20 public usdc;
    
    struct Order {
        uint qty;
        uint price;
    }
    
    struct BuybackReq{
        uint sellId;
        uint askPrice;
        uint buyId;
        uint bidPrice;
        uint finalPrice;
    }
    
    mapping(uint => Order[]) public sellOrders;
    mapping(uint => Order[]) public buyOrders;

    mapping(uint => uint) public royalties;
    
    mapping(uint => mapping(uint => address)) public seller;
    mapping(uint => mapping(uint => address)) public buyer;
    
    constructor(ToknFactory _toknFactory, Airdrop _airdrop, IERC20 _usdc) {
        toknFactory = _toknFactory;
        airdrop = _airdrop;
        usdc = _usdc;
    }  
    
    function returnSellOrders(uint _id) public view returns(Order[] memory) {
        return sellOrders[_id];
    }

    function returnBuyOrders(uint _id) public view returns(Order[] memory) {
        return buyOrders[_id];
    }

    function setRoyaltyForTokn(uint _id, uint _royalty) public {
        require(msg.sender == toknFactory.toknIdToArtist(_id));
        require(royalties[_id] == 0);
        royalties[_id] = _royalty;
    }

    function lowestAskOrder(uint _id) public view returns(uint) {
        uint lowestAsk = sellOrders[_id][0].price;
        uint lowestId = 0;
        for(uint i = 1; i < sellOrders[_id].length; i++) {
            if (sellOrders[_id][i].price < lowestAsk && sellOrders[_id][i].qty !=0) {
               lowestAsk = sellOrders[_id][i].price;
               lowestId = i;
            }
        }
        return lowestId;
    }    
    
    function highestBidOrder(uint _id) public view returns(uint) {
        uint highestBid = buyOrders[_id][0].price;
        uint highestId = 0;
        for(uint i = 1; i < buyOrders[_id].length; i++) {
            if (buyOrders[_id][i].price > highestBid && buyOrders[_id][i].qty !=0) {
                highestBid = buyOrders[_id][i].price;
                highestId = i;
            }
        }
        return highestId;
    }
    
    function addSellOrder(uint _id, uint _qty, uint _price) internal {
        sellOrders[_id].push(Order(_qty, _price));
        uint sellerId = sellOrders[_id].length - 1;
        seller[_id][sellerId] = msg.sender;        
    }
    
    function addBuyOrder(uint _id, uint _qty, uint _price) internal {
        buyOrders[_id].push(Order(_qty, _price));
        uint buyerId = buyOrders[_id].length - 1;
        buyer[_id][buyerId] = msg.sender;        
    }
    
    function sellLimitOrder(uint id, uint _qty, uint _price) public {
        // uint id = toknFactory.symbolToToknId(_symbol);
        require(_qty <= toknFactory.balanceOf(msg.sender, id));
        if(buyOrders[id].length == 0) {
            addSellOrder(id, _qty, _price);
        } else {
            uint buyId = highestBidOrder(id);
            Order memory target = buyOrders[id][buyId];
            if(_price <= target.price) {
                if(_qty <= target.qty) {
                    toknFactory.safeTransferFrom(msg.sender, buyer[id][buyId], id, _qty, "");
                    buyOrders[id][buyId].qty -= _qty;
                    uint amount  =  _qty * target.price;
                    uint commission = amount*royalties[id]/uint(100);
                    uint treasury = airdrop.treasuryPercentage();
                    uint toknCommission = amount * treasury/uint(100);
                    usdc.transfer(toknFactory.deployer(), toknCommission);
                    usdc.transfer(msg.sender, amount - commission - toknCommission);
                    usdc.transfer(toknFactory.toknIdToArtist(id), commission);
                    
                    airdrop.airdropTracker(id, buyer[id][buyId], _qty * target.price);
                } else {
                    toknFactory.safeTransferFrom(msg.sender, buyer[id][buyId], id, target.qty, "");
                    uint amount = target.qty * target.price;
                    uint commission = amount*royalties[id]/uint(100); 
                    uint treasury = airdrop.treasuryPercentage();
                    uint toknCommission = amount * treasury/uint(100);
                    usdc.transfer(toknFactory.deployer(), toknCommission);
                    usdc.transfer(msg.sender, amount - commission - toknCommission);
                    usdc.transfer(toknFactory.toknIdToArtist(id), commission);
                    airdrop.airdropTracker(id, buyer[id][buyId], target.qty * target.price);
                    buyOrders[id][buyId].qty -= target.qty;
                    sellLimitOrder(id, _qty - target.qty, _price);
                }
            } else {
                addSellOrder(id, _qty, _price);
            }
        }
    }
    
    function buyLimitOrder(uint id, uint _qty, uint _price) public {
        uint usdcAmount = _qty * _price;
        usdc.transferFrom(msg.sender, address(this), usdcAmount);
        // uint id = toknFactory.symbolToToknId(_symbol);
        if(sellOrders[id].length == 0) {
            addBuyOrder(id, _qty, _price);
        } else {
            uint sellId = lowestAskOrder(id);
            Order memory target = sellOrders[id][sellId];
            if(_price >= target.price) {
                if(_qty <= target.qty) { 
                    toknFactory.safeTransferFrom(seller[id][sellId], msg.sender, id, _qty, "");
                    uint amount = _qty * target.price;
                    uint commission = amount*royalties[id]/uint(100);
                    uint treasury = airdrop.treasuryPercentage();
                    uint toknCommission = amount * treasury/uint(100);
                    usdc.transfer(toknFactory.deployer(), toknCommission);
                    usdc.transfer(seller[id][sellId],  amount - commission - toknCommission);
                    usdc.transfer(toknFactory.toknIdToArtist(id), commission);
                    airdrop.airdropTracker(id, msg.sender, _qty * target.price);
                    usdc.transfer(msg.sender, _qty * (_price - target.price));
                    sellOrders[id][sellId].qty -= _qty;
                } else {
                    toknFactory.safeTransferFrom(seller[id][sellId], msg.sender, id, target.qty, "");
                    uint amount = target.qty * target.price;
                    uint commission = amount*royalties[id]/uint(100);
                    uint treasury = airdrop.treasuryPercentage();
                    uint toknCommission = amount * treasury/uint(100);
                    usdc.transfer(toknFactory.deployer(), toknCommission);
                    usdc.transfer(seller[id][sellId], amount - commission - toknCommission);
                    usdc.transfer(toknFactory.toknIdToArtist(id), commission);
                    airdrop.airdropTracker(id, msg.sender, target.qty * target.price);
                    usdc.transfer(msg.sender, target.qty * (_price - target.price));  
                    sellOrders[id][sellId].qty -= target.qty;
                    buyLimitOrder(id, _qty - target.qty, _price);
                }
            } else {
                addBuyOrder(id, _qty, _price);
            }
        }
    }
    
    function sellMarketOrder(uint id, uint _qty) public {
        // uint id = toknFactory.symbolToToknId(_symbol);
        require(_qty <= toknFactory.balanceOf(msg.sender, id));
        require(buyOrders[id].length !=0, "No buy orders currently available");
        uint buyId = highestBidOrder(id);
        Order memory target = buyOrders[id][buyId];
        if(_qty <= target.qty) {
            toknFactory.safeTransferFrom(msg.sender, buyer[id][buyId], id, _qty, "");
            uint amount  =  _qty * buyOrders[id][buyId].price;
            uint commission = amount*royalties[id]/uint(100);
            uint treasury = airdrop.treasuryPercentage();
            uint toknCommission = amount * treasury/uint(100);
            usdc.transfer(toknFactory.deployer(), toknCommission);
            usdc.transfer(msg.sender, amount - commission - toknCommission);
            usdc.transfer(toknFactory.toknIdToArtist(id), commission);
            airdrop.airdropTracker(id, buyer[id][buyId], _qty * buyOrders[id][buyId].price);
            buyOrders[id][buyId].qty -= _qty;
        } else {
            toknFactory.safeTransferFrom(msg.sender, buyer[id][buyId], id, target.qty, "");
            uint amount  =  target.qty * buyOrders[id][buyId].price;
            uint commission = amount*royalties[id]/uint(100);
            uint treasury = airdrop.treasuryPercentage();
            uint toknCommission = amount * treasury/uint(100);
            usdc.transfer(toknFactory.deployer(), toknCommission);
            usdc.transfer(msg.sender, amount - commission - toknCommission);
            usdc.transfer(toknFactory.toknIdToArtist(id), commission);
            airdrop.airdropTracker(id, buyer[id][buyId], target.qty * buyOrders[id][buyId].price);
            buyOrders[id][buyId].qty -= target.qty;
            sellMarketOrder(id, _qty - target.qty);
        }
    }
    
    function buyMarketOrder(uint id, uint _qty) public {
        uint advance = usdc.allowance(msg.sender, address(this));
        // uint id = toknFactory.symbolToToknId(_symbol);
        require(sellOrders[id].length !=0, "No sell orders currently available");
        uint sellId = lowestAskOrder(id);
        Order memory target = sellOrders[id][sellId];
        require(advance >= _qty * target.price);
        if(_qty <= target.qty) {
            require(advance >= _qty * target.price, "Advance not sufficient for the quantity");
            toknFactory.safeTransferFrom(seller[id][sellId], msg.sender, id, _qty, "");
            uint amount  =  _qty * sellOrders[id][sellId].price;
            uint commission = amount*royalties[id]/uint(100);
            uint treasury = airdrop.treasuryPercentage();
            uint toknCommission = amount * treasury/uint(100);
            usdc.transfer(toknFactory.deployer(), toknCommission);
            usdc.transfer(seller[id][sellId], amount - commission - toknCommission);
            usdc.transfer(toknFactory.toknIdToArtist(id), commission);
            airdrop.airdropTracker(id, msg.sender, _qty * sellOrders[id][sellId].price);
            sellOrders[id][sellId].qty -= _qty;
        } else {
            require(advance >= target.qty * target.price, "Advance not sufficient for the quantity");
            toknFactory.safeTransferFrom(seller[id][sellId], msg.sender, id, target.qty, "");
            uint amount  =  target.qty * sellOrders[id][sellId].price;
            uint commission = amount*royalties[id]/uint(100);
            uint treasury = airdrop.treasuryPercentage();
            uint toknCommission = amount * treasury/uint(100);
            usdc.transfer(toknFactory.deployer(), toknCommission);
            usdc.transfer(seller[id][sellId], amount - commission - toknCommission);
            usdc.transfer(toknFactory.toknIdToArtist(id), commission);
            airdrop.airdropTracker(id, msg.sender, target.qty * sellOrders[id][sellId].price);
            sellOrders[id][sellId].qty -= target.qty;
            buyMarketOrder(id, _qty - target.qty);
        }
    } 
    
    function buyback(uint _id, uint _premium) public payable {
        require(msg.sender == toknFactory.toknIdToArtist(_id));
        BuybackReq memory req;
        req.sellId = lowestAskOrder(_id);
        req.askPrice = sellOrders[_id][req.sellId].price;
        req.buyId = highestBidOrder(_id);
        req.bidPrice = buyOrders[_id][req.buyId].price;
        req.finalPrice = ((req.askPrice + req.bidPrice)/2) * (1 + _premium); 
        address[] memory addrs = toknFactory.returnAddressesForTokn(_id);
        for(uint i = 0; i < addrs.length; i++) {
            toknFactory.safeTransferFrom(addrs[i], toknFactory.toknIdToArtist(_id), _id, toknFactory.balanceOf(addrs[i], _id), "");
            usdc.transfer(addrs[i], toknFactory.balanceOf(addrs[i], _id) * req.finalPrice);
        }
    }
}
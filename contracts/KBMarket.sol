//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./NFT.sol";
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
// security against transactions for multiple requests
import 'hardhat/console.sol';

contract KBMarket is ReentrancyGuard {
    using Counters for Counters.Counter;

    /* number of items minting, number of transactions, tokens that have not been sold
     keep track of tokens total number - tokenId
     arrays need to know the length - help to keep track for arrays */

     Counters.Counter private _tokenIds;
     Counters.Counter private _tokensSold;
     Counters.Counter private _auctionIds;

     // determine who is the owner of the contract
     // charge a listing fee so the owner makes a commission

     address payable owner; 
     // we are deploying to matic the API is the same so you can use ether the same as matic
     // they both have 18 decimal 
     // 0.045 is in the cents 
     uint256 listingPrice = 0.045 ether;
     uint256 public balances;
     constructor() {
         //set the owner
         owner = payable(msg.sender);
     }

     // structs can act like objects

     struct MarketToken {
         uint itemId;
         address nftContract;
         uint256 tokenId;
         address payable seller;
         address payable owner;
         uint256 price;
         bool sold;
     }

    // tokenId return which MarketToken -  fetch which one it is 

    mapping(uint256 => MarketToken) private idToMarketToken;
    
    struct Auction {
        uint256 highestBid;
        uint256 closingTime;
        address highestBidder;
        address originalOwner;
        bool isActive;
    }

    // NFT id => Auction data
    mapping(uint256 => Auction) public auctions;
    // listen to events from front end applications
    event MarketTokenMinted(
        uint indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );
      event NewAuctionOpened(
        uint indexed itemId,
        uint256 startingBid,
        uint256 closingTime,
        address originalOwner
    );
    event AuctionClosed(
        uint indexed itemId,
        uint256 highestBid,
        address highestBidder
    );
     event BidPlaced(uint indexed tokenId, uint256 bidPrice, address bidder);

    event ProductListed( 
    uint indexed itemId
    );

    // get the listing price
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    // two functions to interact with contract
    // 1. create a market item to put it up for sale
    // 2. create a market sale for buying and selling between parties

    function makeMarketItem(
        address nftContract,
        uint tokenId,
        uint price
    )
    public payable nonReentrant {
        // nonReentrant is a modifier to prevent reentry attack

    require(price > 0, 'Price must be at least one wei');
    require(msg.value == listingPrice, 'Price must be equal to listing price');

    _tokenIds.increment();
    uint itemId = _tokenIds.current();

    //putting it up for sale - bool - no owner
    idToMarketToken[itemId] = MarketToken(
        itemId,
         nftContract,
         tokenId,
         payable(msg.sender),
         payable(address(0)),
         price,
         false
    );

    // NFT transaction 
    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

    emit MarketTokenMinted(
        itemId,
        nftContract,
        tokenId,
        msg.sender,
        address(0),
        price,
        false
    );
    }
    // function to conduct transactions and market sales 

    function createMarketSale(
        address nftContract,
        uint itemId) 
        public payable nonReentrant {
            uint price = idToMarketToken[itemId].price;
            uint tokenId = idToMarketToken[itemId].tokenId;
            require(msg.value == price, 'Please submit the asking price in order to continue');

            // transfer the amount to the seller
            idToMarketToken[itemId].seller.transfer(msg.value);
            // transfer the token from contract address to the buyer
            IERC721(nftContract).transferFrom(address(this),msg.sender, tokenId);
            idToMarketToken[itemId].owner = payable(msg.sender);
            idToMarketToken[itemId].sold = true;
            _tokensSold.increment(); 

            payable(owner).transfer(listingPrice);
        }
         modifier onlyItemOwner(uint256 id) {
        require(
            idToMarketToken[id].owner == msg.sender,
            "Only product owner can do this operation"
        );
        _;
    }
    function openAuction(
        uint tokenId,
        uint256 price,
        uint256 _duration,
        address nftContract

    ) public nonReentrant {

        require(auctions[tokenId].isActive == false, "Ongoing auction detected");
        require(_duration > 0 && price > 0, "Invalid input");

         _tokenIds.increment();
         uint itemId = _tokenIds.current();
         _auctionIds.increment();

     //putting it up for sale - bool - no owner
     idToMarketToken[itemId] = MarketToken(
        itemId,
         nftContract,
         tokenId,
         payable(msg.sender),
         payable(address(0)),
         price,
         false
        );
     IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        // Opening new auction
        auctions[tokenId].highestBid = price;
        auctions[tokenId].closingTime = block.timestamp + _duration;
        auctions[tokenId].highestBidder = msg.sender;
        auctions[tokenId].originalOwner = msg.sender;
        auctions[tokenId].isActive = true;

        emit NewAuctionOpened(
            tokenId,
            auctions[tokenId].highestBid,
            auctions[tokenId].closingTime,
            auctions[tokenId].highestBidder
        );
    }

    function placeBid(uint256 itemId) external payable {
        uint tokenId = idToMarketToken[itemId].tokenId;
        require(auctions[tokenId].isActive == true, "Not active auction");
        require(
            auctions[tokenId].closingTime > block.timestamp,
            "Auction is closed"
        );
        require(msg.value > auctions[tokenId].highestBid, "Bid is too low");

        if (auctions[tokenId].originalOwner != auctions[tokenId].highestBidder) {
            // Transfer ETH to Previous Highest Bidder
           payable (auctions[tokenId].highestBidder).transfer(auctions[tokenId].highestBid);
        }

        auctions[tokenId].highestBid = msg.value;
        auctions[tokenId].highestBidder = msg.sender;

        emit BidPlaced(
            tokenId,
            auctions[tokenId].highestBid,
            auctions[tokenId].highestBidder
        );
    }
    function closeAuction(address nftContract, uint256 itemId) external {
        uint tokenId = idToMarketToken[itemId].tokenId;
        require(auctions[tokenId].isActive == true, "Not active auction");
        require(
            auctions[tokenId].closingTime <= block.timestamp,
            "Auction is not closed"
        );

        // Transfer ETH to NFT Owner
        if (auctions[tokenId].originalOwner != auctions[tokenId].highestBidder) {
            payable (auctions[tokenId].originalOwner).transfer(auctions[tokenId].highestBid);
        }

        // Transfer NFT to Highest Bidder

            // transfer the token from contract address to the buyer
            IERC721(nftContract).transferFrom(address(this),auctions[tokenId].highestBidder, tokenId);
            idToMarketToken[itemId].owner = payable(auctions[tokenId].highestBidder);
            idToMarketToken[itemId].sold = true;
            _tokensSold.increment(); 

            payable(auctions[tokenId].highestBidder).transfer(listingPrice);

        // Close Auction
        auctions[tokenId].isActive = false;

        emit AuctionClosed(
            tokenId,
            auctions[tokenId].highestBid,
            auctions[tokenId].highestBidder
        );
    }

    // function to fetchMarketItems - minting, buying ans selling
    // return the number of unsold items

    function fetchMarketTokens() public view returns(MarketToken[] memory) {
        uint itemCount = _tokenIds.current();
        uint unsoldItemCount = _tokenIds.current() - _tokensSold.current();
        uint currentIndex = 0;

        // looping over the number of items created (if number has not been sold populate the array)
        MarketToken[] memory items = new MarketToken[](unsoldItemCount);
        for(uint i = 0; i < itemCount; i++) {
            if(idToMarketToken[i + 1].owner == address(0)) {
                uint currentId = i + 1;
                MarketToken storage currentItem = idToMarketToken[currentId];
                items[currentIndex] = currentItem; 
                currentIndex += 1;
            }
        } 
        return items; 
    }

        // return nfts that the user has purchased

        function fetchMyNFTs() public view returns (MarketToken[] memory) {
            uint totalItemCount = _tokenIds.current();
            // a second counter for each individual user
            uint itemCount = 0;
            uint currentIndex = 0;

            for(uint i = 0; i < totalItemCount; i++) {
                if(idToMarketToken[i + 1].owner == msg.sender) {
                    itemCount += 1;
                }
            }

            // second loop to loop through the amount you have purchased with itemcount
            // check to see if the owner address is equal to msg.sender

            MarketToken[] memory items = new MarketToken[](itemCount);
            for(uint i = 0; i < totalItemCount; i++) {
                if(idToMarketToken[i +1].owner == msg.sender) {
                    uint currentId = idToMarketToken[i + 1].itemId;
                    // current array
                    MarketToken storage currentItem = idToMarketToken[currentId];
                    items[currentIndex] = currentItem;
                    currentIndex += 1;
                }
            }
            return items;
        }
        function putItemToResell(address nftContract, uint256 itemId, uint256 newPrice)
        public
        payable
        nonReentrant
        onlyItemOwner(itemId)
    {
        uint256 tokenId = idToMarketToken[itemId].tokenId;
        require(newPrice > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        NFT tokenContract = NFT(nftContract);

        tokenContract.transferToken(msg.sender, address(this), tokenId);
       
        address payable oldOwner = idToMarketToken[itemId].owner;
        idToMarketToken[itemId].owner = payable(address(0));
        idToMarketToken[itemId].seller = oldOwner;
        idToMarketToken[itemId].price = newPrice;
        idToMarketToken[itemId].sold = false;
        _tokensSold.decrement();

        emit ProductListed(itemId);
    }

        // function for returning an array of minted nfts
        function fetchItemsCreated() public view returns(MarketToken[] memory) {
            // instead of .owner it will be the .seller
            uint totalItemCount = _tokenIds.current();
            uint itemCount = 0;
            uint currentIndex = 0;

      for(uint i = 0; i < totalItemCount; i++) {
                if(idToMarketToken[i + 1].seller == msg.sender) {
                    itemCount += 1;
                }
            }

            // second loop to loop through the amount you have purchased with itemcount
            // check to see if the owner address is equal to msg.sender

            MarketToken[] memory items = new MarketToken[](itemCount);
            for(uint i = 0; i < totalItemCount; i++) {
                if(idToMarketToken[i +1].seller == msg.sender) {
                    uint currentId = idToMarketToken[i + 1].itemId;
                    MarketToken storage currentItem = idToMarketToken[currentId];
                    items[currentIndex] = currentItem;
                    currentIndex += 1;
                }
        }
        return items;
    }
    function fetchAuctionsCreated() public view returns(Auction[] memory){
       uint totalAuctionCount = _auctionIds.current();
            uint auctionCount = 0;
            uint currentIndex = 0;

      for(uint i = 0; i < totalAuctionCount; i++) {
                if(auctions[i + 1].originalOwner == msg.sender) {
                    auctionCount += 1;
                }
            }
              Auction[] memory Auctions = new Auction[](auctionCount);
            for(uint i = 0; i < totalAuctionCount; i++) {
                if(auctions[i +1].originalOwner == msg.sender) {
                 uint currentId = i + 1;
                 Auction storage currentItem = auctions[currentId];
                 Auctions[currentIndex] = currentItem; 
                 currentIndex += 1;
                } 

    }
    return Auctions;


}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "ERC20.sol";

interface IProfi is IERC20 {
    function mintReferal(address) external;
    function decimals() external pure returns (uint8);
    function transferToken(address, address, uint256) external;
}

contract main is ERC1155("") {
    struct Referal {
        address provider;
        uint8 discount;
    }

    struct Collection {
        uint256 id;
        string title;
        string description;
        uint256[] ids;
    }

    struct Asset {
        uint256 id;
        string title;
        string description;
        string image;
        uint256 price;
        uint256 issued;
        uint256 available;
        uint256 creation_date;
    }

    struct Bet {
        address wallet;
        uint256 sum;
    }

    struct Auction {
        Collection collection;
        uint256 timeStart;
        uint256 timeEnd;
        uint256 startPrice;
        uint256 maxPrice;
        Bet lastBet;
    }

    struct Sell {
        address seller;
        uint256 NFTid;
        uint256 amount;
        uint256 price;
    }

    IProfi private profi;
    address private owner = msg.sender;
    
    Asset[] private assets;
    Auction[] private auctions;
    Collection[] private collections;
    Sell[] private sells;
    uint256[] private ownerCollections;

    mapping(string => Referal) private codeToReferal;
    mapping(address => string) private ownerToCode;
    mapping(address => bool) private activatedReferal;
    mapping(uint256 => uint256) private NFTtoCollection;
    mapping(address => uint256[]) private ownNFTs;
    mapping(uint256 => Bet[]) private bets;
    mapping(address => uint256[]) private wonLots;

    modifier onlyOwner {
        require(msg.sender == owner, unicode"Недостаточно прав");
        _;
    }

    modifier auctionIsActive(uint256 index) {
        require(auctions[index].timeStart <= block.timestamp, unicode"Аукцион ещё не начался");
        require(block.timestamp < auctions[index].timeEnd, unicode"Лот неактивен");
        _;
    }

    modifier afterSpendNFT(uint256 index) {
        _;
        if (balanceOf(msg.sender, ownNFTs[msg.sender][index]) == 0) {
            delete ownNFTs[msg.sender][index];
        }
    }

    constructor(address profiAddress) {
        profi = IProfi(profiAddress);
        assets.push(Asset(
            1,
            unicode"Комочек", 
            unicode"Комочек слился с космосом", 
            "cat_nft1.png", 
            0, 
            1,
            0, 
            block.timestamp
        ));
        assets.push(Asset(
            2,
            unicode"Вкусняшка", 
            unicode"Вкусняшка впервые пробует японскую кухню", 
            "cat_nft2.png", 
            0, 
            1,
            0, 
            block.timestamp
        ));
        assets.push(Asset(
            3,
            unicode"Пузырик", 
            unicode"Пузырик похитил котика с Земли", 
            "cat_nft3.png", 
            0, 
            1,
            0, 
            block.timestamp
        ));
        assets.push(Asset(
            4,
            unicode"Баскетболист", 
            unicode"Он идет играть в баскетбол", 
            "walker_nft1.png", 
            0, 
            1,
            0, 
            block.timestamp
        ));
        assets.push(Asset(
            5,
            unicode"Волшебник", 
            unicode"Он идет колдовать", 
            "walker_nft1.png", 
            0, 
            1,
            0, 
            block.timestamp
        ));

        ownNFTs[msg.sender] = [1, 2, 3, 4, 5];

        _mint(msg.sender, 1, 1, "");
        _mint(msg.sender, 2, 1, "");
        _mint(msg.sender, 3, 1, "");
        _mint(msg.sender, 4, 1, "");
        _mint(msg.sender, 5, 1, "");
    }

    function createReferal(string calldata wallet) external {
        require(codeToReferal[ownerToCode[msg.sender]].provider == address(0), unicode"Вы уже создали реферальный код");
        string memory code = string.concat("PROFI-", wallet[2:6], "2023");
        require(codeToReferal[code].provider == address(0), unicode"Такой код уже существует");
        ownerToCode[msg.sender] = code;
        codeToReferal[code] = Referal(msg.sender, 0);
    }

    function activateReferalCode(string calldata code) external {
        require(!activatedReferal[msg.sender], unicode"Вы уже активировали реферальный код");
        require(codeToReferal[code].provider != address(0), unicode"Такого кода нет");
        require(codeToReferal[code].provider != msg.sender, unicode"Нельзя активировать свой реферальный код");
        profi.mintReferal(msg.sender);
        activatedReferal[msg.sender] = true;
        if (codeToReferal[code].discount < 3) {
            codeToReferal[code].discount++;
        }
    }

    function sellNFT(uint256 index, uint256 amount, uint256 price) external afterSpendNFT(index) {
        uint256 id = ownNFTs[msg.sender][index];
        require(NFTtoCollection[id] == 0 || msg.sender != owner, unicode"Вы не можете продать часть коллекции");
        bool notFound = true;
        for (uint256 i = 0; i < sells.length; i++) {
            if (sells[i].seller == msg.sender && sells[i].price == price && sells[i].NFTid == id) {
                notFound = false;
                sells[i].amount += amount;
                break;
            }
        }
        if (notFound) {
            sells.push(Sell(msg.sender, id, amount, price));
        }

        _burn(msg.sender, id, amount);
    }

    function buyNFT(uint256 index, uint256 amount) external {
        require(amount <= sells[index].amount, unicode"Нельзя купить больше, чем продаётся");
        profi.transferToken(msg.sender, sells[index].seller, sells[index].price * amount * (codeToReferal[ownerToCode[msg.sender]].discount / 100));

        if (balanceOf(msg.sender, sells[index].NFTid) == 0) {
            ownNFTs[msg.sender].push(sells[index].NFTid);
        }
        _mint(msg.sender, sells[index].NFTid, amount, "");

        if (sells[index].amount == amount) {
            delete sells[index];
        } else {
            sells[index].amount -= amount;
        }
    }

    function createSingleNFT(
        string memory title,
        string memory description,
        string memory image,
        uint256 price,
        uint256 issued
    ) external onlyOwner {
        uint256 tokenNumber = assets.length + 1;
        assets.push(Asset(
            tokenNumber,
            title, 
            description, 
            image, 
            price, 
            issued, 
            0, 
            block.timestamp
        ));
        ownNFTs[msg.sender].push(tokenNumber);
        
        _mint(owner, tokenNumber, issued, "");
    }

    function createCollectionNFT(
        string memory collectionTitle,
        string memory collectionDescription,
        uint256[] memory ids
    ) external onlyOwner {
        uint256 collectionNumber = collections.length + 1;

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            require(NFTtoCollection[id] == 0, unicode"Один из токенов уже состоит в коллекции");
            require(assets[id - 1].issued > 0, unicode"Одного из токенов не существует");
            NFTtoCollection[id] = collectionNumber;
        }

        Collection memory newCollection = Collection(collectionNumber, collectionTitle, collectionDescription, ids);
        collections.push(newCollection);
        ownerCollections.push(collectionNumber);
    }

    function transferNFT(address to, uint256 index, uint256 amount) external afterSpendNFT(index) {
        uint256 id = ownNFTs[msg.sender][index];
        if (balanceOf(to, id) == 0) {
            ownNFTs[to].push(id);
        }
        _safeTransferFrom(msg.sender, to, id, amount, "");
    }

    function startAuction(uint256 collectionIndex, uint256 asideTime, uint256 duration, uint256 startPrice, uint256 maxPrice) external onlyOwner {
        require(ownerCollections[collectionIndex] != 0, unicode"Коллекции не существует");
        require(maxPrice > startPrice, unicode"Максимальная ставка должна быть больше стартовой");
        auctions.push(Auction(
            collections[ownerCollections[collectionIndex] - 1], 
            block.timestamp + asideTime, 
            block.timestamp + asideTime + duration, 
            startPrice, 
            maxPrice, 
            Bet(msg.sender, startPrice)
        ));
        delete ownerCollections[collectionIndex];
    }

    function checkAuctionExpired(uint256 index) external onlyOwner {
        require(auctions[index].maxPrice != 0, unicode"Лот не существует");
        if (block.timestamp > auctions[index].timeEnd) {
            _sendWinning(index);
        }
    }

    function finishAuction(uint256 index) external onlyOwner auctionIsActive(index) {
        auctions[index].timeEnd = block.timestamp;
        _sendWinning(index);
    }

    function bid(uint256 index, uint256 sum) external auctionIsActive(index) {
        profi.transferToken(msg.sender, owner, sum);
        bool notFound = true;
        uint256 betsCount = bets[index].length;
        for (uint256 i = 0; i < betsCount; i++) {
            if (bets[index][i].wallet == msg.sender) {
                notFound = false;
                require(bets[index][i].sum + sum > auctions[index].lastBet.sum, unicode"Маленькая ставка");
                bets[index][i].sum += sum;
                auctions[index].lastBet = bets[index][i];
                break;
            }
        }
        if (notFound) {
            require(sum > auctions[index].lastBet.sum, unicode"Маленькая ставка");
            bets[index].push(Bet(msg.sender, sum));
            auctions[index].lastBet = bets[index][betsCount];
        }

        if (auctions[index].lastBet.sum >= auctions[index].maxPrice) {
            auctions[index].timeEnd = block.timestamp;
            _sendWinning(index);
        }
    }

    function getNFTCollection(uint256 NFTid) external view returns(uint256) {
        return NFTtoCollection[NFTid];
    }

    function getActivatedReferal() external view returns(bool) {
        return activatedReferal[msg.sender];
    }

    function getAuctions() external view returns(Auction[] memory) {
        return auctions;
    }

    function getBets(uint256 auctionIndex) external view returns(Bet[] memory) {
        return bets[auctionIndex];
    }

    function getMyBet(uint256 auctionIndex) external view returns(Bet memory) {
        for (uint256 i = 0; i < bets[auctionIndex].length; i++) {
            if (bets[auctionIndex][i].wallet == msg.sender) {
                return bets[auctionIndex][i];
            }
        }
        return Bet(address(0), 0);
    }

    function getSells() external view returns(Sell[] memory) {
        return sells;
    }

    function getAsset(uint256 id) external view returns(Asset memory) {
        return assets[id - 1];
    }

    function getAssets() external view returns(Asset[] memory) {
        return assets;
    }

    function getCollections() external view returns(Collection[] memory) {
        return collections;
    }

    function getMyNFTs() external view returns(Asset[] memory, uint256[] memory) {
        address[] memory sender = new address[](ownNFTs[msg.sender].length);
        Asset[] memory NFTs = new Asset[](ownNFTs[msg.sender].length);
        for (uint256 i = 0; i < ownNFTs[msg.sender].length; i++) {
            if (ownNFTs[msg.sender][i] != 0) {
                sender[i] = msg.sender;
                NFTs[i] = assets[ownNFTs[msg.sender][i] - 1];
            }
        }
        return (NFTs, balanceOfBatch(sender, ownNFTs[msg.sender]));
    }

    function getOwnerCollections() external view onlyOwner returns(uint256[] memory) {
        return ownerCollections;
    }

    function getBalance() external view returns(uint256) {
        return profi.balanceOf(msg.sender);
    }

    function getMyDiscount() external view returns(uint256) {
        return codeToReferal[ownerToCode[msg.sender]].discount;
    }

    function getMyCode() external view returns(string memory) {
        return ownerToCode[msg.sender];
    }

    function getWonLots() external view returns(uint256[] memory) {
        return wonLots[msg.sender];
    }

    function _sendWinning(uint256 index) private {
        address winner = auctions[index].lastBet.wallet;
        uint256[] memory ids = auctions[index].collection.ids;
        uint256[] memory amounts = new uint256[](ids.length);
        wonLots[winner].push(index);
        for (uint256 i = 0; i < ids.length; i++) {
            amounts[i] = balanceOf(owner, ids[i]);
            if (balanceOf(winner, ids[i]) == 0) {
                ownNFTs[winner].push(ids[i]);
            }
            delete ownNFTs[owner][index];
        }
        _safeBatchTransferFrom(owner, winner, ids, amounts, "");
    }
}
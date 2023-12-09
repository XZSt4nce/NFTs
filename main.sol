// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "ERC20.sol";

// Интерфейс реализующий работу с токеном стандарта ERC20
interface IProfi is IERC20 {
    function mintReferal(address) external;
    function decimals() external pure returns (uint8);
    function transferToken(address, address, uint256) external;
}

contract main is ERC1155("") {
    /*
        Структура для рефералов
        Содержит:
            адрес пользователя, предоставившего код,
            скидка
    */
    struct Referal {
        address provider;
        uint8 discount;
    }
    // Структура коллекции
    struct Collection {
        uint256 id;
        string title;
        string description;
        uint256[] ids;
    }
    // Структура обособленного NFT
    struct Asset {
        uint256 id;
        string title;
        string description;
        string image;
        uint256 price;
        uint256 issued;
        uint256 available;
        uint256 creation_date;
        uint256 collection;
    }
    // Структура ставки
    struct Bet {
        address wallet;
        uint256 sum;
    }
    // Структура лота на аукционе
    struct Auction {
        Collection collection;
        uint256 timeStart;
        uint256 timeEnd;
        uint256 startPrice;
        uint256 maxPrice;
        Bet lastBet;
    }
    // Структура для продажи обособленного NFT
    struct Sell {
        address seller;
        uint256 NFTid;
        uint256 amount;
        uint256 price;
    }

    IProfi private profi; // Переменная для работы с токенами ERC20
    address private owner = msg.sender; // Владелец контракта
    
    Asset[] private assets; // Массив всех NFT
    Auction[] private auctions; // Массив всех лотов
    Collection[] private collections; // Массив всех коллекций
    Sell[] private sells; // Массив всех продаж
    uint256[] private ownerCollections; // Массив коллекций, принадлежащий владельцу

    mapping(string => Referal) private codeToReferal; // Доступ к структуре для реферала по коду
    mapping(address => string) private ownerToCode; // Доступ к коду по адресу его создателя
    mapping(address => bool) private activatedReferal; // Активировал ли код пользователь по указанному адресу
    mapping(address => uint256[]) private ownNFTs; // Доступ к собственным NFT по адресу
    mapping(uint256 => Bet[]) private bets; // Доступ ко всем ставкам по индексу лота
    mapping(address => uint256[]) private wonLots; // Доступ к выигранным лотам по адресу пользователя

    // Выполнение метода только в случае, если вызывающий его пользователь является владельцем контракта
    modifier onlyOwner {
        require(msg.sender == owner, unicode"Недостаточно прав");
        _;
    }

    // Выполнение метода только в случае, если лот по указанному индексу – активен
    modifier auctionIsActive(uint256 index) {
        require(auctions[index].timeStart <= block.timestamp, unicode"Аукцион ещё не начался");
        require(block.timestamp < auctions[index].timeEnd, unicode"Лот неактивен");
        _;
    }

    // Если после траты обособленных NFT у пользователя их не остаётся, то они удаляются из собственности
    modifier afterSpendNFT(uint256 index) {
        _;
        if (balanceOf(msg.sender, ownNFTs[msg.sender][index]) == 0) {
            delete ownNFTs[msg.sender][index];
        }
    }

    constructor(address profiAddress) {
        profi = IProfi(profiAddress); // Реализация методов интерфейса по адресу контракта, реализуещего их
        // Инициализация начальных NFT для создания коллекций и присваивание их владельцу системы
        assets.push(Asset(
            1,
            unicode"Комочек", 
            unicode"Комочек слился с космосом", 
            "cat_nft1.png", 
            0, 
            1,
            0, 
            block.timestamp,
            0
        ));
        assets.push(Asset(
            2,
            unicode"Вкусняшка", 
            unicode"Вкусняшка впервые пробует японскую кухню", 
            "cat_nft2.png", 
            0, 
            1,
            0, 
            block.timestamp,
            0
        ));
        assets.push(Asset(
            3,
            unicode"Пузырик", 
            unicode"Пузырик похитил котика с Земли", 
            "cat_nft3.png", 
            0, 
            1,
            0, 
            block.timestamp,
            0
        ));
        assets.push(Asset(
            4,
            unicode"Баскетболист", 
            unicode"Он идет играть в баскетбол", 
            "walker_nft1.png", 
            0, 
            1,
            0, 
            block.timestamp,
            0
        ));
        assets.push(Asset(
            5,
            unicode"Волшебник", 
            unicode"Он идет колдовать", 
            "walker_nft2.png", 
            0, 
            1,
            0, 
            block.timestamp,
            0
        ));

        ownNFTs[msg.sender] = [1, 2, 3, 4, 5];

        _mint(msg.sender, 1, 1, "");
        _mint(msg.sender, 2, 1, "");
        _mint(msg.sender, 3, 1, "");
        _mint(msg.sender, 4, 1, "");
        _mint(msg.sender, 5, 1, "");
    }

    /*
        Создание кода для рефералов, если пользователь его ещё не создавал и подобный код не существует
        Вход: адрес пользователя
    */
    function createReferal(string calldata wallet) external {
        require(codeToReferal[ownerToCode[msg.sender]].provider == address(0), unicode"Вы уже создали реферальный код");
        string memory code = string.concat("PROFI-", wallet[2:6], "2023");
        require(codeToReferal[code].provider == address(0), unicode"Такой код уже существует");
        ownerToCode[msg.sender] = code;
        codeToReferal[code] = Referal(msg.sender, 0);
    }

    /*
        Активация реферального кода
        Если пользователь не активировал код и код валидный, то пользователю начисляется 100 PROFI,
        а создавшему код пользователю начисляется +1% скидка, если она уже не превышает 3%
        Вход: реферальный код
    */
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

    /*
        Продажа обособленного NFT, который не состоит в данный момент в коллекции
        Вход:
            индекс на NFT, которой владеет пользователь,
            количество NFT,
            цена продажи
    */
    function sellNFT(uint256 index, uint256 amount, uint256 price) external afterSpendNFT(index) {
        uint256 id = ownNFTs[msg.sender][index];
        require(assets[id - 1].collection == 0 || msg.sender != owner, unicode"Вы не можете продать часть коллекции");
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

        assets[id - 1].available += amount;
        _burn(msg.sender, id, amount);
    }

    /*
        Изменение цены продаваемой пользователем NFT
        Вход: индекс продаваемой NFT, новая цена
    */
    function changeSellPrice(uint256 index, uint256 price) external {
        require(sells[index].seller == msg.sender, unicode"Это не ваш NFT");
        sells[index].price = price;
    }

    /*
        Покупка обособленного NFT
        Вход:
            индекс продаваемой NFT,
            количество покупаемого NFT
    */
    function buyNFT(uint256 index, uint256 amount) external {
        Sell memory sell = sells[index];
        require(amount <= sell.amount, unicode"Нельзя купить больше, чем продаётся");
        require(msg.sender != sell.seller, unicode"Нельзя купить свой NFT");
        uint256 price = sell.price - sell.price * codeToReferal[ownerToCode[msg.sender]].discount / 100;
        profi.transferToken(msg.sender, sell.seller, price * sell.amount);

        if (balanceOf(msg.sender, sell.NFTid) == 0) {
            ownNFTs[msg.sender].push(sell.NFTid);
        }

        if (sell.amount == amount) {
            delete sells[index];
        } else {
            sells[index].amount -= amount;
        }

        assets[sell.NFTid - 1].available -= amount;
        _mint(msg.sender, sell.NFTid, amount, "");
    }

    /*
        Создать новую NFT.
        Создавать NFT имеет право только владелец системы.
        Вход:
            название,
            описание,
            путь к картинке,
            ценность,
            количество выпускаемых
    */
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
            block.timestamp,
            0
        ));
        ownNFTs[msg.sender].push(tokenNumber);
        
        _mint(owner, tokenNumber, issued, "");
    }

    /*
        Создание коллекции из существующих обособленных NFT.
        Создавать коллекции имеет право только владелец системы.
        Ни одна из обособленных NFT не должна принадлежать ни какой из коллекций.
        Вход:
            название,
            описание,
            идентификаторы NFT
    */
    function createCollectionNFT(
        string memory collectionTitle,
        string memory collectionDescription,
        uint256[] memory ids
    ) external onlyOwner {
        uint256 collectionNumber = collections.length + 1;

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            require(assets[id - 1].collection == 0, unicode"Один из токенов уже состоит в коллекции");
            require(assets[id - 1].issued > 0, unicode"Одного из токенов не существует");
            assets[id - 1].collection = collectionNumber;
        }

        Collection memory newCollection = Collection(collectionNumber, collectionTitle, collectionDescription, ids);
        collections.push(newCollection);
        ownerCollections.push(collectionNumber);
    }

    /*
        Безвозмездный перевод NFT пользователю
        Вход:
            адрес пользователя,
            индекс собственной NFT,
            количество NFT
    */
    function transferNFT(address to, uint256 index, uint256 amount) external afterSpendNFT(index) {
        uint256 id = ownNFTs[msg.sender][index];
        if (balanceOf(to, id) == 0) {
            ownNFTs[to].push(id);
        }
        _safeTransferFrom(msg.sender, to, id, amount, "");
    }

    /*
        Начать отложенный аукцион.
        Может выполнить только владелец системы.
        Вход:
            индекс коллекции,
            через сколько секунд начать аукцион,
            через сколько секунд после начала закончить аукцион,
            стартовая цена,
            максимальная цена
    */
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

    /*
        Если время лота по данному индексу истекло, то передать NFT из коллекции лидеру ставок.
        Может выполнить только владелец системы.
        Вход: индекс лота
    */
    function checkAuctionExpired(uint256 index) external onlyOwner {
        require(auctions[index].maxPrice != 0, unicode"Лот не существует");
        if (block.timestamp > auctions[index].timeEnd) {
            _sendWinning(index);
        }
    }

    /*
        Досрочно закончить аукцион.
        Может выполнить только владелец системы.
        Вход: индекс лота
    */
    function finishAuction(uint256 index) external onlyOwner auctionIsActive(index) {
        auctions[index].timeEnd = block.timestamp;
        _sendWinning(index);
    }

    /*
        Сделать или увеличить ставку на активный лот.
        Вход: индекс лота, сумма ставки
    */
    function bid(uint256 index, uint256 sum) external auctionIsActive(index) {
        require(auctions[index].lastBet.wallet != msg.sender, unicode"Вы уже лидер");
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

    // Выход: активировал ли реферальный код пользователь, вызывающий метод
    function getActivatedReferal() external view returns(bool) {
        return activatedReferal[msg.sender];
    }

    // Выход: все лоты аукциона
    function getAuctions() external view returns(Auction[] memory) {
        return auctions;
    }

    /*
        Вход: индекс лота
        Выход: все ставки на лот
    */
    function getBets(uint256 auctionIndex) external view returns(Bet[] memory) {
        return bets[auctionIndex];
    }

    /*
        Вернуть ставку на лот пользователя, вызывающего метод
        Вход: индекс лота
        Выход: структура ставки
    */
    function getMyBet(uint256 auctionIndex) external view returns(Bet memory) {
        for (uint256 i = 0; i < bets[auctionIndex].length; i++) {
            if (bets[auctionIndex][i].wallet == msg.sender) {
                return bets[auctionIndex][i];
            }
        }
        return Bet(address(0), 0);
    }

    // Выход: все активные продажи NFT
    function getSells() external view returns(Sell[] memory) {
        return sells;
    }

    /*
        Вернуть информацию по конкретному NFT
        Вход: идентификатор NFT
        Выход: структура NFT
    */
    function getAsset(uint256 id) external view returns(Asset memory) {
        return assets[id - 1];
    }

    function getAssets(uint256[] memory ids) external view returns(Asset[] memory) {
        Asset[] memory selectedAssets = new Asset[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            selectedAssets[i] = assets[ids[i] - 1];
        }
        return selectedAssets;
    }

    // Выход: все коллекции
    function getCollection(uint256 id) external view returns(Collection memory) {
        return collections[id - 1];
    }

    // Выход: структуры NFT и их количество, принадлежащих пользователю, который вызывает метод
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

    /*
        Вернуть все коллекции, которые принадлежат владельцу системы.
        Может выполнить только владелец системы.
        Выход: массив коллекций
    */
    function getOwnerCollections() external view onlyOwner returns(Collection[] memory) {
        Collection[] memory ownColls = new Collection[](ownerCollections.length);
        for (uint256 i = 0; i < ownerCollections.length; i++) {
            ownColls[i] = collections[ownerCollections[i] - 1];
        }
        return ownColls;
    }

    // Выход: баланс PROFI пользователя, вызывающего метод
    function getBalance() external view returns(uint256) {
        return profi.balanceOf(msg.sender);
    }

    // Выход: скидка на покупки пользователя, вызывающего метод
    function getMyDiscount() external view returns(uint256) {
        return codeToReferal[ownerToCode[msg.sender]].discount;
    }

    // Выход: код пользователя, вызывающего метод
    function getMyCode() external view returns(string memory) {
        return ownerToCode[msg.sender];
    }

    // Выход: идентификаторы выигранных лотов пользователя, вызывающего метод
    function getWonLots() external view returns(uint256[] memory) {
        return wonLots[msg.sender];
    }

    /*
        Внутренний метод для выдачи NFT из коллекции победителю аукциона
        Вход: индекс лота
    */
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
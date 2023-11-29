// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "professional.sol";

contract main is ERC1155, proffesional {
    struct Referal {
        address provider;
        uint8 discount;
    }

    struct Collection {
        string title;
        string description;
    }

    struct Asset {
        string title;
        string description;
        string image;
        uint256 price;
        uint256 issued;
        uint256 available;
        uint256 creation_date;
        uint256 collection;
    }

    struct Bet {
        address wallet;
        uint256 amount;
    }

    address owner = msg.sender;
    uint256 tokensCount = 0;
    uint256 collectionsCount = 0;

    mapping(string => Referal) codeToReferal;
    mapping(address => string) ownerToCode;
    mapping(address => Referal) activatedReferal;
    mapping(uint256 => Asset) Assets;
    mapping(uint256 => Collection) CollectionNFT;
    mapping(uint256 => uint256) NFTtoCollection;

    modifier onlyOwner {
        require(msg.sender == owner, unicode"Вы не владелец системы");
        _;
    }

    constructor() ERC1155("") {
        _createSingleNFT(
            unicode"Герда в профиль", 
            unicode"Скучающая хаски по имени Герда", 
            "husky_nft1.png", 
            2000 * 10**decimals(), 
            7,
            0
        );
        _createSingleNFT(
            unicode"Герда на фрилансе", 
            unicode"Герда релизнула новый проект", 
            "husky_nft2.png", 
            5000 * 10**decimals(), 
            5,
            0
        );
        _createSingleNFT(
            unicode"Новогодняя Герда", 
            unicode"Герда ждет боя курантов", 
            "husky_nft3.png", 
            3500 * 10**decimals(), 
            2,
            0
        );
        _createSingleNFT(
            unicode"Герда в отпуске", 
            unicode"Приехала отдохнуть после тяжелого проекта", 
            "husky_nft4.png", 
            4000 * 10**decimals(), 
            6,
            0
        );

        string[] memory spaceKittiesTitles;
        spaceKittiesTitles[0] = unicode"Комочек";
        spaceKittiesTitles[1] = unicode"Вкусняшка";
        spaceKittiesTitles[2] = unicode"Пузырик";
        string[] memory spaceKittiesDescriptions;
        spaceKittiesDescriptions[0] = unicode"Комочек слился с космосом";
        spaceKittiesDescriptions[1] = unicode"Вкусняшка впервые пробует японскую кухню";
        spaceKittiesDescriptions[2] = unicode"Пузырик похитил котика с Земли";
        string[] memory spaceKittiesImages;
        spaceKittiesImages[0] = "cat_nft1.png";
        spaceKittiesImages[1] = "cat_nft2.png";
        spaceKittiesImages[2] = "cat_nft3.png";
        uint256[] memory spaceKittiesIssued;
        spaceKittiesIssued[0] = 1;
        spaceKittiesIssued[1] = 1;
        spaceKittiesIssued[2] = 1;

        _createCollectionNFT(
            unicode"Космические котики", 
            unicode"Они путешествуют по вселенной",
            spaceKittiesTitles,
            spaceKittiesDescriptions,
            spaceKittiesImages,
            spaceKittiesIssued
        );

        string[] memory pedestriansTitles;
        pedestriansTitles[0] = unicode"Баскетболист";
        pedestriansTitles[0] = unicode"Волшебник";
        string[] memory pedestriansDescriptions;
        pedestriansDescriptions[0] = unicode"Он идет играть в баскетбол";
        pedestriansDescriptions[0] = unicode"Он идет колдовать";
        string[] memory pedestriansImages;
        pedestriansImages[0] = "walker_nft1.png";
        pedestriansImages[1] = "walker_nft2.png";
        uint256[] memory pedestriansIssued;
        pedestriansIssued[0] = 1;
        pedestriansIssued[1] = 1;

        _createCollectionNFT(
            unicode"Пешеходы",
            unicode"Куда они идут?",
            pedestriansTitles,
            pedestriansDescriptions,
            pedestriansImages,
            pedestriansIssued
        );
    }

    function transferProfi(address to, uint256 amount) external {
        _transferToken(msg.sender, to, amount);
    }

    function createReferal(string calldata wallet) external {
        require(codeToReferal[ownerToCode[msg.sender]].provider == address(0), unicode"Вы уже создали реферальный код");
        string memory code = string.concat("PROFI-", wallet[2:6], "2023");
        require(codeToReferal[code].provider == address(0), unicode"Такой код уже существует");
        ownerToCode[msg.sender] = code;
        codeToReferal[code] = Referal(msg.sender, 0);
    }

    function activateReferalCode(string calldata code) external {
        require(activatedReferal[msg.sender].provider == address(0), unicode"Вы уже активировали реферальный код");
        require(codeToReferal[code].provider != msg.sender, unicode"Нельзя активировать свой реферальный код");
        _mintReferal();
        activatedReferal[msg.sender] = codeToReferal[code];
        if (codeToReferal[code].discount < 3) {
            codeToReferal[code].discount++;
        }
    }

    function sellNFT(uint256 NFTid, uint256 price) external {

    }

    function openAuction(
        uint256 CollectionId, 
        uint256 startBet,
        uint256 maxBet,
        uint256 timeStart, 
        uint256 timeEnd
    ) external onlyOwner {

    }

    function createSingleNFT(
        string memory title,
        string memory description,
        string memory image,
        uint256 price,
        uint256 issued,
        uint256 collection
    ) external onlyOwner {
        _createSingleNFT(
            title,
            description,
            image,
            price,
            issued,
            collection
        );
    }

    function createCollectionNFT(
        string memory collectionTitle,
        string memory collectionDescription,
        string[] memory titles,
        string[] memory descriptions,
        string[] memory images,
        uint256[] memory issued
    ) external onlyOwner {
        _createCollectionNFT(
            collectionTitle,
            collectionDescription,
            titles,
            descriptions,
            images,
            issued
        );
    }

    function getOwnCode() external view returns(string memory) {
        return ownerToCode[msg.sender];
    }

    function _createSingleNFT(
        string memory title,
        string memory description,
        string memory image,
        uint256 price,
        uint256 issued,
        uint256 collection
    ) private {
        uint256 tokenNumber = tokensCount++;
        Assets[tokenNumber] = Asset(
            title, 
            description, 
            image, 
            price, 
            issued, 
            0, 
            block.timestamp,
            collection
        );
        
        _mint(owner, tokenNumber, issued, "");
    }

    function _createCollectionNFT(
        string memory collectionTitle,
        string memory collectionDescription,
        string[] memory titles,
        string[] memory descriptions,
        string[] memory images,
        uint256[] memory issued
    ) private {
        uint256 collectionNumber = collectionsCount++ + 1;
        CollectionNFT[collectionNumber] = Collection(collectionTitle, collectionDescription);

        uint256[] memory ids;

        for (uint256 i = 0; i < titles.length; i++) {
            uint256 tokenNumber = tokensCount++;
            Assets[tokenNumber] = Asset(
                titles[i],
                descriptions[i],
                images[i],
                0, 
                issued[i],
                0, 
                block.timestamp,
                collectionNumber
            );
            NFTtoCollection[tokenNumber] = collectionNumber;

            ids[i] = tokenNumber;
        }

        _mintBatch(msg.sender, ids, issued, "");
    }
}
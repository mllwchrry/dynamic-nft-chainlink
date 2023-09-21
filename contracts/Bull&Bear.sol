// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

import "hardhat/console.sol";


contract BullBear is ERC721, ERC721Enumerable, ERC721URIStorage, KeeperCompatibleInterface, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    AggregatorV3Interface public pricefeed;

    uint public /* immutable */ interval;
    uint public lastTimeStamp;

    int256 public currentPrice;

    event TokensUpdated(string trend);

    // IPFS URIs for the dynamic nft graphics/metadata.
    string[] bullUrisIpfs = [
        "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json",
        "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
        "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
    ];
    string[] bearUrisIpfs = [
        "https://ipfs.io/ipfs/Qmdx9Hx7FCDZGExyjLR6vYcnutUR8KhBZBnZfAPHiUommN?filename=beanie_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
    ];

    constructor(uint updateInterval, address _pricefeed) ERC721("Bull&Bear", "BBTK") {
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        pricefeed = AggregatorV3Interface(_pricefeed);
        currentPrice = getLatestPrice();
    }

    function getLatestPrice() public view returns (int256) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = pricefeed.latestRoundData();
        
        return price;
    }

    function setPriceFeed(address newFeed) public onlyOwner {
        pricefeed = AggregatorV3Interface(newFeed);
    }

    function setInterval(uint256 newInterval) public onlyOwner {
        interval = newInterval;
    }

    function updateAllTokenURIs(string memory trend) internal {
        if (compareStrings('bull', trend)) {
            for (uint i = 0; i < _tokenIdCounter.current(); i++) {
                _setTokenURI(i, bullUrisIpfs[0]);
            }
        } else {
            for (uint i = 0; i < _tokenIdCounter.current(); i++) {
                _setTokenURI(i, bearUrisIpfs[0]);
            }
        }

        emit TokensUpdated(trend);
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }

    function safeMint(address to) public {
        uint256 tokenId = _tokenIdCounter.current();

        _tokenIdCounter.increment();

        _safeMint(to, tokenId);

        // Default to a bull NFT
        string memory defaultUri = bullUrisIpfs[0];
        _setTokenURI(tokenId, defaultUri);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            int latestPrice = getLatestPrice();
            
            if (latestPrice != currentPrice) {
                if (latestPrice > currentPrice) {
                    updateAllTokenURIs('bull');
                } else {
                    updateAllTokenURIs('bear');
                }
                currentPrice = latestPrice;
            }
        } else {
            console.log('interval is not up yet');
        }
    }
}
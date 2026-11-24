// SPDX-License-Identifier: MIT
// Ported from Kolektivo/geonft-registry-monorepo (MIT) to OpenZeppelin v5.
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title GeoNFT — geospatial NFT (TERRA / GAIABIO land token)
/// @notice ERC-721 whose metadata carries GeoJSON topology plus an on-chain
///         ecological index updated by the registry owner (steward multisig).
contract GeoNFT is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    uint256 private _tokenIdCounter;

    struct EcologicalIndex {
        string indexType;
        int256 indexValue;
    }

    // GeoNFT token properties
    mapping(uint256 => string) private geoJsons; // mapping of tokenId to geoJson
    mapping(uint256 => EcologicalIndex) private ecologicalIndexMap;

    constructor(address owner_) ERC721("GEONFT Minter", "GEONFT") Ownable(owner_) {}

    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function safeMint(address to, string memory uri, string memory _geoJson) public {
        uint256 tokenId = _tokenIdCounter++;

        // set geoJson
        geoJsons[tokenId] = _geoJson;

        // default index value to 0 type to area_m2
        EcologicalIndex memory ecologicalIndex = EcologicalIndex("area_m2", 0);
        ecologicalIndexMap[tokenId] = ecologicalIndex;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // Returns an array of tokenIds, URIs for an owner address
    function getTokensByOwner(address owner)
        public
        view
        returns (uint256[] memory, string[] memory, string[] memory)
    {
        uint256 totalTokensForOwner = ERC721.balanceOf(owner);
        uint256[] memory _tokenIds = new uint256[](totalTokensForOwner);
        string[] memory _uris = new string[](totalTokensForOwner);
        string[] memory _geoJsons = new string[](totalTokensForOwner);

        for (uint256 i; i < totalTokensForOwner; ++i) {
            _tokenIds[i] = ERC721Enumerable.tokenOfOwnerByIndex(owner, i);
            _uris[i] = tokenURI(_tokenIds[i]);
            _geoJsons[i] = geoJsons[_tokenIds[i]];
        }
        return (_tokenIds, _uris, _geoJsons);
    }

    function setTokenURI(uint256 tokenId, string memory uri) external onlyOwner {
        _setTokenURI(tokenId, uri);
    }

    function setGeoJson(uint256 tokenId, string memory _geoJson) external onlyOwner {
        geoJsons[tokenId] = _geoJson;
    }

    function getEcologicalIndex(uint256 _tokenId) public view returns (EcologicalIndex memory) {
        return ecologicalIndexMap[_tokenId];
    }

    function setEcologicalIndex(
        uint256 _tokenId,
        string memory _indexType,
        int256 _indexValue
    ) external onlyOwner {
        EcologicalIndex storage ecologicalIndex = ecologicalIndexMap[_tokenId];
        ecologicalIndex.indexType = _indexType;
        ecologicalIndex.indexValue = _indexValue;
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, amount);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function geoJson(uint256 tokenId) public view returns (string memory) {
        return geoJsons[tokenId];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

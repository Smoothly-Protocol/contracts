// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "Solidity-RLP/RLPReader.sol";

contract PatriciaTreeVerifier is Test {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for RLPReader.Iterator;
  using RLPReader for bytes;

  struct MerkleProof {
    bytes32 expectedRoot;
    bytes key;
    bytes[] proof;
    uint256 keyIndex;
    uint256 proofIndex;
    bytes expectedValue;
  }

  bytes32 expectedRoot = hex'2c039c2837ee22218fd85fd7af5e893801577687fba8f368f19913399f6408c2'; 
  bytes key = hex'417ebaa8de17c9a73acf7cf3f6c998ca2dd1e993276cc9dd37dfb7fb0cb197a4';
  bytes expectedValue = hex'f7f6b0aad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d610501804101';
  bytes[] proof = [
    bytes(hex'f85180808080a0a48dc333e67d452dc7869eebf4d67bf7ca6e1b049885de00818120b183c69b318080808080808080a03dbabc55ea14a2e97f514622a318a5c14bac95d05e18aa6fa2252fce915b4bed808080'),
    bytes(hex'f85ba0317ebaa8de17c9a73acf7cf3f6c998ca2dd1e993276cc9dd37dfb7fb0cb197a4b838f7f6b0aad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d610501804101')
  ]; // Proof for validator with key "0xb87cd2a01042DFbf8d101DFe22ECb93CD1902185" + "154"

  function testVerifyProof() public {
    MerkleProof memory data = MerkleProof(
      expectedRoot,
      key, // Keccak256 encoded
      proof,
      0, // Index for recursion
      0, // Index for recursion
      expectedValue
    );
    assertEq(verifyProof(data), true);
  }

  function verifyProof(MerkleProof memory data) public returns (bool) {
    bytes memory node = data.proof[data.proofIndex];
    RLPReader.RLPItem[] memory dec = node.toRlpItem().toList();
    require(keccak256(node) == data.expectedRoot, "invalid root hash");

    uint numItems = dec.length;

    if(numItems == 17) {
      console.log("%s", "Branch node");
      if(data.keyIndex >= data.key.length) {
        if(keccak256(dec[16].toBytes()) == keccak256(data.expectedValue)) {
          return true;
        }
      } else {
        uint8 index = uint8(bufferToNibbles(data.key)[data.keyIndex]);
        bytes32 newExpectedRoot = bytes32(dec[index].toBytes());
        if(newExpectedRoot.length != 0) {
          data.expectedRoot = newExpectedRoot;
          data.keyIndex += 1;
          data.proofIndex += 1;
          return verifyProof(data);
        }
      }
    } else if(numItems == 2) {
      bytes memory nodeKey = dec[0].toBytes();
      bytes memory nodeValue = dec[1].toBytes();
      bytes1[] memory restKey = bufferToNibbles(nodeKey);
      bytes1[] memory actualKey = bufferToNibbles(data.key);
      uint8 prefix = uint8(restKey[0]);

      if(prefix == 2) {
        console.log("%s", "Leaf even");
        if(keccak256(slice(actualKey, data.keyIndex)) == keccak256(slice(restKey,2)) &&
          keccak256(data.expectedValue) == keccak256(nodeValue)
        ) {
          return true;
        }
      } else if(prefix == 3) {
        console.log("%s", "Leaf odd");
        if(keccak256(slice(actualKey, data.keyIndex)) == keccak256(slice(restKey,1)) &&
          keccak256(data.expectedValue) == keccak256(nodeValue)
        ) {
          return true;
        }
      } else if(prefix == 0) {
        console.log("%s", "extension even");
        bytes memory sharedNibbles = slice(restKey, 2);
        uint extensionLength = sharedNibbles.length;
        if(keccak256(sharedNibbles) == keccak256(slice(actualKey, data.keyIndex, data.keyIndex + extensionLength))) {
          data.expectedRoot = bytes32(dec[1].toBytes());
          data.keyIndex += extensionLength;
          data.proofIndex += 1;
          return verifyProof(data);
        }
      } else if(prefix == 1) {
        console.log("%s", "extension odd");
        bytes memory sharedNibbles = slice(restKey, 1);
        uint extensionLength = sharedNibbles.length;
        if(keccak256(sharedNibbles) == keccak256(slice(actualKey, data.keyIndex, data.keyIndex + extensionLength))) {
          data.expectedRoot = bytes32(dec[1].toBytes());
          data.keyIndex += extensionLength;
          data.proofIndex += 1;
          return verifyProof(data);
        }
      } else {
        // This shouldn't be reached if the proof has the correct format
        revert("Invalid proof");
      }
    }
    data.expectedValue.length == 0 ? true : false;
  }

  function bufferToNibbles(bytes memory _key) public pure returns(bytes1[] memory nibbles) {
    nibbles = new bytes1[](_key.length * 2);
    for(uint i = 0; i < _key.length; i++) {
      uint q = i * 2;
      nibbles[q] = _key[i] >> 4;
      ++q;
      nibbles[q] = bytes1(uint8(_key[i]) % 16);
    }
  }

  function slice(bytes1[] memory _key, uint start) public pure returns(bytes memory result) {
    for(uint i = start; i < _key.length; i++) {
      result = abi.encodePacked(result, _key[i]); 
    }
  }

  function slice(bytes1[] memory _key, uint start, uint end) public pure returns(bytes memory result) {
    for(uint i = start; i < end; i++) {
      result = abi.encodePacked(result, _key[i]); 
    }
  }
}

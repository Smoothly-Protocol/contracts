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

  bytes32 expectedRoot = hex'74eedb5ed018dc8f4371e8f52654f59b04b5997f19e650bfdd8eb0afd606645f'; 
  bytes key = hex'de6f5fafd87fb98ff05aa9ed1780cb31f2ea7b9303a88e21ea53f4bc3665563f';
  bytes expectedValue = hex'f83ab0aad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61808080808474727565';
  bytes[] proof = [
    bytes(hex'f90211a07858ee64da70d070cca14ff3ddefe1e835dec2599095f0baaf2deb66727479f2a02d5f267cedb1e497f795f17dee0dd5011f4d27560c113b0b6c899ffef871381ea049a128d880140846e2a9c73b2461a9af30c9b57aa004cd90d01d78d5e3d6d5aea0b0940464932d95d066ed6a47a4c8ebbf89f082a6cdb056a9eddd85f6a77cddd9a0e6f557b78d5d3deb6799c2a41c49c0c12ca240a7a279f322bf0b72b03b9f4cb0a0579ae6f098fb781ebce442b6af9767b766ab392333f718aa01979cb179410fd3a0f87f50d003abc8b3b54836321a9645228e390b7848b03c013a3db9f22f3d2474a0dde9043259917acf3e435d9e5456b9ce0ed86172be1d4a68cbdfcd72bcca9d04a08cef23fb37001aca960a4852d78e5abbe478482e9f509c9c3a671c3a355025cfa015eaad12dcceb05b6bda56d2214759d08b54ea0ea499f6d819cdf09c16ea95b8a0b40975a038563c5833e4d48a1dd89ba9cc3ab34f9db2baaf093d942c7bf571b6a0fb3769b82174d8e366111fd8820e99b3214c47ff58e68973dad254b907cdaf18a0369a31c8a909b159893faed5312ccdab62d653d70c96aa6c091747482ff2aff9a018c13e9decd6193bcacc4b073a5e3934979e0eab14a863a37aa97e0934ecceaba03e9a816321b6d5e9451b3a857b194e43a9289abfbede2a9d195bd3bd6d93ad3fa0bcf2afe0a079cbdffb166086e0f63b5dc99f7c3d4731ef8df99cd77137fd54d680'),
    bytes(hex'f90211a093f3cc803254cc9c78260c77ee1c9e5aaec8a93f2573c4355a2b8a070bc3f19ca01b2274831e6e8247c51af601e174428b37d1e7c01c8065ddec81dea79857c78da077755c747ada6704df985d2fdef0b1d8c10f8ad9e56cc12a7a33969eae822dfaa0f6016b777583e7ea2552a3bc922469c4d7a06083f4cbb861691e30536aaa72dca0dbe5149d75023c881326b774b3d622b5b69fc418f5e317e04bad98ad41db8cefa070821ba16e0960064c104ac1e7fd26a7b340de9da7716a41ea187bad238dc472a046efda1c8b7534ddae82e715ab3f7edfa35cf85a969ff8f4986d05636a0f19bea0b2320d6d3e15776ef55f0427d3859ee73cf981c59175a1c44cd2e71b7e89776ea0aeb55d86ec04514e291fa4c9aadee00877a0424f6f74c1e5fa245aca5fece4cba0de93fd3132a3bada311c7d56b58b8b1259349869197649c488ba1437da4c5108a005130b2245e2ac759a572b1b21928e73c9e8af081c880ec9d168c416570461d8a0ce1c89c3a1c3fa0133a6f7b290fa2dac5131a7c5f78b619feb2d2626a618c18ea069d7746b76ee00ddb53794cc038110f64c569ad27739c4e7d2af8fc6433bc331a0c257f0469692c435ed3be26afd2f9915fe8fc2ad37c9423b1860d3117d280c34a0cd9b460b82a8b992db249dbf5e395a63085c1f4dbe0edb3348f38329babc955ea0f466db63e15ab1ad7d8ba62ed9488098c31ca8ad1d645439bbda9506894e8cfc80'),
    bytes(hex'f85fa0206f5fafd87fb98ff05aa9ed1780cb31f2ea7b9303a88e21ea53f4bc3665563fb83cf83ab0aad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61808080808474727565')
  ]; // Proof for validator with key "0xb87cd2a01042DFbf8d101DFe22ECb93CD1902185" + "154"

  event logString(string s);
  event logBytes1A(bytes1[] b);

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
      emit logString("Branch node");
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
      } else if(prefix == 1) {
        console.log("%s", "extension odd");
      } else {
        // This should be reached if the proof has the correct format
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
}

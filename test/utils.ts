import { Trie } from '@ethereumjs/trie';
import { RLP } from '@ethereumjs/rlp'

export async function getProof(user: any, trie: Trie) {
  const key = Buffer.from(user.address.toLowerCase());
  const proof = await trie.createProof(key);
  const value = await trie.verifyProof(trie.root(), key, proof) as Buffer;
  return [proof, value];
}

export async function buildTrie(numUsers: number, signers: any, numValidators: number) {
  // MPTrie
  const trie = new Trie({useKeyHashing: true})
  const validator = [
      38950,
      0,
      0,
      0,
      0.65 * 10 ** 18,
      0 // bool any non-zero byte except "0x80" is considered true
  ];

  // Build validators
  let tValidators = [];
  for(let i = 0; i < numValidators; i++) {
    tValidators.push(validator);
  }

  // Store users with validators in trie
  for(let i = 0; i < numUsers; i++) {
    await trie.put(Buffer.from(signers[i].address.toLowerCase()), Buffer.from(RLP.encode(tValidators)))
  }
  
  return trie;
}

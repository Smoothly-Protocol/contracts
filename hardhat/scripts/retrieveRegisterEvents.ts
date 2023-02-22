import { ethers } from "hardhat";

// Types 
interface ValidatorInfo {
  publickey: string;
  valid_signature: boolean;
  validatorindex: number; 
}

const main = async () => {
  const abi = [
    `event ValidatorRegistered(address indexed eth1_addr, string validator, uint id)`  
  ];
  const address = "0x5d8cba0a25ad107e3d2874ccb7063ac3d306dd82";
  const contract = new ethers.Contract("0x8d3b2dc0c22A2BDC17975c065a65637bD9d58F6B", abi, ethers.provider);
  const logs = contract.filters.ValidatorRegistered(address);
  const filter: Array<any> = await contract.queryFilter(logs);
  const url = `https://goerli.beaconcha.in/api/v1/validator/eth1/${address}`;
    const headers = {
    method: "GET",
    headers: {
      "Accept": "application/json",
      "Content-Type": "application/json"
    }
  }
  const req = await fetch(url, headers);
  const res = await req.json();
  filter.forEach(e => {
    verifyValidator(e.args[0], e.args[1], e.args[2], res)
  }); 
};

const verifyValidator = async (eth1Addr: string, pubKey: string, id: number, res: any) => {
  if(res.status === "OK") {
    let data: Array<ValidatorInfo> = [];
    data = res.data.length != undefined ? res.data : data.push(res.data);
    const { verified, index } = proofOwnership(eth1Addr, pubKey, data);
    if(verified) {
      const newUser: User = {
        eth1Addr: eth1Addr,
        validatorId: id,
        pubKey: pubKey,
        validatorIndex: index,
        missedSlots: 0,
        slashFee: 0,
        firstBlockProposed: false,
        firstMissedSlot: false
      }
      const isInserted = await findValidator(pubKey);
      if(!isInserted) {
        insertValidator(newUser);
      } else {
        console.log(`ERR: Already inserted in db ${pubKey}`);
      }
    } else {
      console.log(`ERR: ${eth1Addr} doesn't match any validators with ${pubKey}`);
    }
  } else {
    console.log("ERR: something went wrong on verifyValidator req call.");
  }
}

const proofOwnership = (
  eth1Addr: string, 
  pubKey: string, 
  data: Array<ValidatorInfo>
): {verified: boolean, index: number} => {
  const len = data.length;
  let verified: boolean = false;
  let index: number = 0;
  if(len > 0) {
    for(let i = 0; i < len; i++) {
      if((data[i].publickey == pubKey) && (data[i].validatorindex != null)) {
        verified = true;
        index = Number(data[i].validatorindex);
        return { verified, index }; 
      }
    }
  } 
  return { verified, index };
}

const insertValidator = async (user: User): Promise<any> => {
  try {
    const url = process.env.DB_URL + "insertOne";
    const query = JSON.stringify({
      "collection": process.env.DB_COLLECTION,
      "database": process.env.DB_DATABASE,
      "dataSource": process.env.DB_DATASOURCE,
      "document": user
    });
    const config: any = {
      method: 'post',
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Request-Headers': '*',
        'api-key': process.env.DB_API,
      },
      body: query
    };
    const res = await fetch(url, config);
    const data = await res.json();
    return data;
  } catch (err) {
    console.log(err);
  }
}

const findValidator = async (pubKey: string): Promise<any> => {
  try {
    const url = process.env.DB_URL + "findOne";
    const query = JSON.stringify({
      "collection": process.env.DB_COLLECTION,
      "database": process.env.DB_DATABASE,
      "dataSource": process.env.DB_DATASOURCE,
      "filter": {"pubKey": pubKey}
    });
    const config: any = {
      method: 'post',
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Request-Headers': '*',
        'api-key': process.env.DB_API,
      },
      body: query
    };
    const res = await fetch(url, config);
    const data = await res.json();
    if(data.document == null) {
      return false;  
    };
    return true;
  } catch (err) {
    console.log(err);
  }
}

main();

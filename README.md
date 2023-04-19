# ![1500x500 smoothly](https://user-images.githubusercontent.com/106842341/233216098-c26c079b-1ce2-48d4-99e0-d85ae924d513.jpeg)


# 
**tldr:** 

Smoothly is a tool which gives home validators the ability to pool together their tips and MEV from block proposals which, on average, increases their reward and allows for more frequent distributions. Home Stakers change the fee recipient address in their validator client to our pool contract and can connect their wallet and claim their “share” of the rewards ***fortnightly.*** < — (for you Phiz). 

**Why would a an individual validator want to do this?** 

Validators receive various types of rewards for their contribution to the network. Most of these rewards are locked in the validator wallet until after withdrawals are enabled with the Shanghai hard fork (March-April 2023). These locked rewards include Attestations, Sync Committee Participation, and the Block Reward (issuance) for proposals. When your validator is chosen to propose a block, in addition to the block reward, you receive the tips associated with that block, and these fees are sent to your “fee recipient” address. The tips also include MEV if you’re using an external builder. Since the magnitude of tips and MEV are highly dependent on network activity, individuals may want to “pool” their tips together with other validators in order to have a better chance of receiving tips from a block when network activity is very high and block space demand is at its peak.  Linked at the bottom of this page is best statistical analysis I’ve seen on the topic, and was presented at Devcon in Bogota, Columbia by Ken Smith; an active contributor to Rocketpool. The tl;dr analysis shows that on average over a 5 year time span, validators in a “fee recipient” pool earn 41.6% more ETH than those not in the pool. Also worth noting in this analysis is that the smoothing pool outperformed single validators 9/10 times over that 5 year period. 

**The Situation:** 

Solo stakers are becoming a rare breed; there are a growing number of ways to stake your ETH that  offer higher rewards with less technical knowhow.  Although there are good actors like Rocketpool and Stakewise, a large amount of stake is held by centralized entities.  There are three main incentives which large actors offer that separate them from the home staker community.   

1. *Issuing an Liquid Staking Derivative*. By receiving an LSD such as cbEth or stEth in exchange for your ETH that you’ve staked, you are essentially still liquid and could put that up as collateral to borrow against, lend, and generate a higher yield than vanilla staking at the protocol level. This is true. 
2. *Issuing a native token*. By staking with Rocketpool and running your own node you get exposure to RPL rewards which increases your APY. This is true. 
3. *Reward Smoothing*. By staking with Rocketpool, Lido, or Coinbase, the tips and MEV from block proposals can be distributed among all the validators in the associated pool. This gives you exposure to more block proposals which in turn gives you a higher probability of receiving a share of rewards from a block with a large amount of MEV. This is true. 

**Our Solution** 

We’re not here to issue another LSD and we don’t have a token, but we are here to provide a service to boost the average APY for home stakers in order remain competitive in the staking marketplace. We promote staking at home, running your own hardware, and making your own decisions about MEV-boost relays whilst giving you exposure to blocks proposed during high network activity and MEV events.  Our protocol requires no additional software to be run on your staking machine; the only change you will have to make is regarding the fee recipient address associated with your validator. As an insurance policy, we require each validator that registers to the protocol to deposit 0.65 ETH into the contract to be used as a mechanism for punishing the associated user if they act maliciously.
 
**License**

 * Copyright 2023 Smoothly Protocol LLC
 * All files in this repository are licensed under Apache-2.0 unless otherwise noted.
 * Our contracts make use of the Openzeppelin contract Ownable.sol which is licensed under the MIT license.


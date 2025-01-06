## IDRCoin

Disclaimer: this is a part of Penerbangan Pertama educational content, DO NOT USE ON PRODUCTION as this project contains intentional bug.

IDRCoin is a implementation of ERC20 with custom logic.
This coin is fixed stable coin, first in the world.
But we do not guarantee the stability of the coin on DEX. We are not responsible for any loss.

Use case of our token is, you can use it to gain access to our service, BankHub.
IDRCoin can also be used for P2P on our platform later (not implemented yet).

Anyone can have IDRCoin by trading it with USDT on `IDRCoin` contract.

## BankHub

BankHub is a platform that allows you to manage your finance.
You can deposit your IDRCoin to BankHub by providing Bank address and gain interest.

For now our official partner is Bank ABC and Bank IRB.

But anyone can create their own bank and join our platform by providing KYC to us.

## Scope

All contracts would be deployed on Ethereum mainnet.

The scope of this audit is limited to the following files:

```tree
src/IDRCoin.sol
src/BankHub.sol
```

## Out of Scope

1. ALL interaction with DEX is out of scope in this audit.
2. Currently there are no user withdrawal function in `IDRCoin` contract. So user can only bought IDRCoin with USDT, but cannot sell it back to USDT.

## Known Issue

`IDRCoin::conversionRate` is fixed at 16000.

## Actors and Roles

1. OWNER is trusted. All OWNER action is assumed to be correct. Issue related to OWNER action is invalid.
2. BANK is the one who approved by OWNER to be a bank. BANK is the one who hold IDRCoin and provide interest to USER.
3. USER is the one who interact with IDRCoin.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```


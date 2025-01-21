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

But anyone can create their own bank and join our platform by providing KYC to us and some payment (DM us for details).

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
3. USDT blacklisting this contract is out of scope.

## Known Issue

1. `IDRCoin::conversionRate` is fixed at 16000.
2. `BankHub::getIDRCoinLoan` can be used to get IDRCoin without any collateral and no function to pay back. This is intended.

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

### Coverage

```shell
$ forge coverage
╭--------------------+------------------+------------------+----------------+-----------------╮
| File               | % Lines          | % Statements     | % Branches     | % Funcs         |
+=============================================================================================+
| src/BankHub.sol    | 91.07% (51/56)   | 90.74% (49/54)   | 35.71% (5/14)  | 100.00% (13/13) |
|--------------------+------------------+------------------+----------------+-----------------|
| src/IDRCoin.sol    | 84.72% (61/72)   | 85.25% (52/61)   | 11.11% (1/9)   | 90.00% (18/20)  |
|--------------------+------------------+------------------+----------------+-----------------|
| test/ERC20Mock.sol | 92.59% (25/27)   | 94.74% (18/19)   | 50.00% (5/10)  | 87.50% (7/8)    |
|--------------------+------------------+------------------+----------------+-----------------|
| Total              | 88.39% (137/155) | 88.81% (119/134) | 33.33% (11/33) | 92.68% (38/41)  |
╰--------------------+------------------+------------------+----------------+-----------------╯
```

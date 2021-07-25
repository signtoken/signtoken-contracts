const { expect, assert } = require("chai");
const { web3, artifacts } = require("hardhat");
const deploy = require("../scripts/deploy")

function increaseBlock() {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({ method: "evm_mine", params: [] }, (error, res) => {
            if (error) return reject(error)
            resolve(res)
        })
    })
}

describe("max_supply", () => {
    let accounts;
    let contracts;

    before(async function () {
        accounts = await web3.eth.getAccounts();
        const MaxSupplyTest = await artifacts.require("MaxSupplyTest");
        const maxSupplyTest = await MaxSupplyTest.new();
        contracts = {
            signToken: maxSupplyTest
        }
    });

    it("test reached max supply", async () => {
        const name = "John Wick"
        const fee = web3.utils.toWei("0.01")
        await contracts.signToken.sign(name, { value: fee })
        assert.equal(await contracts.signToken.nextSignId(), 1)
        assert.equal(await contracts.signToken.getNameBySignId(0), name)

        await contracts.signToken.claim()
        assert.equal((await contracts.signToken.balanceOf(accounts[0])).toString(), "1000000000000000000") // 1 SIGN

        await contracts.signToken.claim()
        assert.equal((await contracts.signToken.balanceOf(accounts[0])).toString(), "2000000000000000000") // 2 SIGN

        // max supply is 3 SIGN
        await contracts.signToken.claim()
        assert.equal((await contracts.signToken.balanceOf(accounts[0])).toString(), "3000000000000000000") // 3 SIGN

        // check disabled mint SIGN
        assert.equal((await contracts.signToken.amountPerBlock()).toNumber(), 0)
        // can't claim more token
        try {
            await contracts.signToken.claim()
        } catch (error) {
            assert.include(error.message, "NO_PRODUCTIVITY")
        }
    })
})
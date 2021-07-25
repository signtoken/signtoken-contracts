const { expect, assert } = require("chai");
const { web3 } = require("hardhat");
const deploy = require("../scripts/deploy")

function increaseBlock() {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({ method: "evm_mine", params: [] }, (error, res) => {
            if (error) return reject(error)
            resolve(res)
        })
    })
}

describe("basic", () => {
    let accounts;
    let contracts;

    before(async function () {
        accounts = await web3.eth.getAccounts();
        contracts = await deploy();
    });

    it("sign a name", async () => {
        const name = "John Wick"
        const fee = web3.utils.toWei("0.01")
        await contracts.signToken.sign(name, { value: fee })

        assert.equal(await contracts.signToken.nextSignId(), 1)
        assert.equal(await contracts.signToken.getNameBySignId(0), name)
    })

    it("claim token", async () => {
        await contracts.signToken.claim()
        assert.equal((await contracts.signToken.balanceOf(accounts[0])).toString(), "1000000000000000000") // 1 SIGN
        // await increaseBlock()
        await contracts.signToken.claim()
        assert.equal((await contracts.signToken.balanceOf(accounts[0])).toString(), "2000000000000000000") // 2 SIGN
    })
})
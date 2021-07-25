const { expect, assert } = require("chai");
const { web3, artifacts, contract } = require("hardhat");
const deploy = require("../scripts/deploy")

function increaseBlock() {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({ method: "evm_mine", params: [] }, (error, res) => {
            if (error) return reject(error)
            resolve(res)
        })
    })
}

describe("buy_on_pancake", () => {
    let accounts;
    let contracts;

    before(async function () {
        accounts = await web3.eth.getAccounts();

        const PancakeFactory = await artifacts.require("PancakeFactory");
        const factory = await PancakeFactory.new(accounts[0]);

        const WBNB = await artifacts.require("WBNB");
        const wbnb = await WBNB.new();

        const PancakeRouter = await artifacts.require("PancakeRouter");
        const router = await PancakeRouter.new(factory.address, wbnb.address);

        const SignToken = await hre.artifacts.require("BuyOnPancakeTest");
        const signToken = await SignToken.new(router.address)

        contracts = {
            factory,
            router,
            signToken,
            wbnb
        }
    });

    it("create pair & add liquidity", async () => {
        const amountToken = web3.utils.toWei("1000")
        const amountETH = web3.utils.toWei("10")
        const deadline = parseInt((new Date().getTime() / 1000) + (60 * 60)) // 1 hour

        // approve
        await contracts.signToken.approve(contracts.router.address, web3.utils.toWei("10000"))
        await contracts.router.addLiquidityETH(contracts.signToken.address, amountToken, amountToken, amountETH, accounts[0], deadline, {
            value: amountETH
        })
    })

    it("sign reached MAX_FEE = 1 BNB", async () => {
        const promiseArr = []

        // sign 99 name with fee 0.01 BNB per sign
        for(let i = 0; i < 99; i++) {
            promiseArr.push(contracts.signToken.sign(`name${i}`, {value: web3.utils.toWei("0.01")}))
        }

        await Promise.all(promiseArr)
        assert.equal((await web3.eth.getBalance(contracts.signToken.address)).toString(), "990000000000000000") // 0.99 BNB

        // if balance of contract reached 1 BNB -> Buy token and burn it
        await contracts.signToken.sign(`name100`, {value: web3.utils.toWei("0.01")})
        assert.equal((await web3.eth.getBalance(contracts.signToken.address)).toString(), "0")
        assert.equal((await contracts.signToken.balanceOf("0x0000000000000000000000000000000000000000")).toString(), "90702432370993407592") // burned 90.7024324 SIGN

    })
})
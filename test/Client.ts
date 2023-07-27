import {
    time,
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers, network } from "hardhat";
import { ContractTransactionResponse } from "ethers";
import {
    Client__factory,
    IPool,
    IPoolEscrow,
    IStakedEthToken,
    IWhiteListManager,
    PublicToken,
    PublicToken__factory,
} from "../typechain-types";

const POOL: string = "0xeA6b7151b138c274eD8d4D61328352545eF2D4b7";
const ESCROW: string = "0xa57C8861d923B57A09BC9270fA76198c8cDCB002";
const WHITELIST: string = "0x57a9cbED053f37EB67d6f5932b1F2f9Afbe347F3";
const STAKED_ETH: string = "0x65077fA7Df8e38e135bd4052ac243F603729892d";
const MULTISIG: string = "0x6C7692dB59FDC7A659208EEE57C2c876aE54a448";

const ONE_ETH: bigint = ethers.parseEther("1");
const HALF_ETH: bigint = ethers.parseEther("0.5");

async function impersonate(
    who: string,
    f: (signer: HardhatEthersSigner) => Promise<void>
): Promise<void> {
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [who],
    });
    const signer = await ethers.getSigner(who);
    try {
        await f(signer);
    } finally {
        network.provider.request({
            method: "hardhat_stopImpersonatingAccount",
            params: [who],
        });
    }
}

describe("Client", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function init() {
        const Pool: IPool = await ethers.getContractAt("IPool", POOL);
        const Escrow: IPoolEscrow = await ethers.getContractAt(
            "IPoolEscrow",
            ESCROW
        );
        const StakedEth: IStakedEthToken = await ethers.getContractAt(
            "IStakedEthToken",
            STAKED_ETH
        );
        const Whitelist: IWhiteListManager = await ethers.getContractAt(
            "IWhiteListManager",
            WHITELIST
        );

        // Deploy the PublicToken and the Client.
        const PublicTokenFactory: PublicToken__factory =
            await ethers.getContractFactory("PublicToken");
        const PublicToken: PublicToken = await PublicTokenFactory.deploy();
        const ClientFactory: Client__factory = await ethers.getContractFactory(
            "Client"
        );
        const Client = await ClientFactory.deploy(
            POOL,
            ESCROW,
            STAKED_ETH,
            await PublicToken.getAddress()
        );

        // Grant the CLIENT_ROLE to the Client contract.
        await PublicToken.grantRole(
            await PublicToken.CLIENT_ROLE(),
            await Client.getAddress()
        );

        // These are the user accounts.
        const [_, one, two, three] = await ethers.getSigners();

        // Add the Client contract to the whitelist.
        await three.sendTransaction({
            to: MULTISIG,
            value: ethers.parseEther("5"),
        });
        await impersonate(
            MULTISIG,
            async (multisig: HardhatEthersSigner): Promise<void> => {
                await Whitelist.connect(multisig).updateWhiteList(ESCROW, true);
                await Whitelist.connect(multisig).updateWhiteList(
                    await Client.getAddress(),
                    true
                );
            }
        );

        // Fund the escrow with some ETH.
        await three.sendTransaction({
            to: ESCROW,
            value: ethers.parseEther("5"),
        });

        return { Pool, Escrow, StakedEth, PublicToken, Client, one, two };
    }

    describe("Staking", function () {
        it("Should take ETH and mint PublicToken", async function () {
            const { StakedEth, PublicToken, Client, one } = await loadFixture(
                init
            );
            const tx: Promise<ContractTransactionResponse> = Client.connect(
                one
            ).stake({
                value: ONE_ETH,
            });
            // Verify that ETH is taken.
            await expect(tx).to.changeEtherBalances(
                [await one.getAddress(), Client, POOL],
                [-ONE_ETH, 0, ONE_ETH]
            );
            // Verify that StakedETH is given to the Client contract.
            await expect(tx).to.changeTokenBalance(
                StakedEth,
                await Client.getAddress(),
                ONE_ETH
            );
            // Verify that user is given the equivalent amount of the PublicToken.
            await expect(tx).to.changeTokenBalance(
                PublicToken,
                await one.getAddress(),
                ONE_ETH
            );
        });
    });

    describe("Unstaking", function () {
        it("Should exchange PublicToken for ETH", async function () {
            const { Pool, StakedEth, PublicToken, Client, one, two } =
                await loadFixture(init);

            // First: stake.
            await Client.connect(one).stake({ value: ONE_ETH });
            await Client.connect(two).stake({ value: ONE_ETH });

            const before: bigint = await PublicToken.totalSupply();

            // User one now wants to withdraw.
            await PublicToken.connect(one).approve(
                await Client.getAddress(),
                ethers.MaxUint256
            );
            const tx: Promise<ContractTransactionResponse> =
                Client.connect(one).request(HALF_ETH);

            // Now verify that ETH was actually moved from the Escrow contract directly to the user.
            await expect(tx).to.changeEtherBalances(
                [ESCROW, Client, await one.getAddress()],
                [-HALF_ETH, 0, HALF_ETH]
            );

            // Verify that the PublicToken was burnt.
            await expect(tx).to.changeTokenBalance(PublicToken, one, -HALF_ETH);
            const after: bigint = await PublicToken.totalSupply();
            expect(before - after).to.be.equal(HALF_ETH);

            // Verify that StakedETH was taken out of the Client.
            await expect(tx).to.changeTokenBalances(
                StakedEth,
                [Client, ESCROW],
                [-HALF_ETH, HALF_ETH]
            );
        });
    });
});

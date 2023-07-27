import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const { INFURA_APIKEY } = process.env;
const MAINNET = `https://mainnet.infura.io/v3/${INFURA_APIKEY}`;

const config: HardhatUserConfig = {
    networks: {
        hardhat: {
            forking: {
                enabled: true,
                url: MAINNET,
            },
        },
    },
    solidity: "0.8.16",
};

export default config;

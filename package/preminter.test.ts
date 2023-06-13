import {
  createTestClient,
  http,
  createWalletClient,
  createPublicClient,
} from "viem";
import { foundry, mainnet } from "viem/chains";
import { describe, it, beforeEach, expect } from "vitest";
import { parseEther } from "viem";
import {
  zoraCreator1155FactoryImplConfig,
  zoraCreator1155PreminterABI as preminterAbi,
  zoraCreator1155ImplABI,
} from "./wagmiGenerated";
import { chainConfigs } from "./chainConfigs";
import preminter from "../out/ZoraCreator1155Preminter.sol/ZoraCreator1155Preminter.json";
import {
  ContractCreationConfig,
  TokenCreationConfig,
  preminterTypedDataDefinition,
} from "./preminter";

const walletClient = createWalletClient({
  chain: foundry,
  transport: http(),
});

export const walletClientWithAccount = createWalletClient({
  chain: foundry,
  transport: http(),
});

const testClient = createTestClient({
  chain: foundry,
  mode: "anvil",
  transport: http(),
});

const publicClient = createPublicClient({
  chain: foundry,
  transport: http(),
});

type Address = `0x${string}`;

// JSON-RPC Account
const [deployerAccount, creatorAccount, collectorAccount] =
  (await walletClient.getAddresses()) as [Address, Address, Address];

type TestContext = {
  preminterAddress: `0x${string}`;
  zoraMintFee: bigint;
};

const deployPreminterContract = async () => {
  const factoryProxyAddress = zoraCreator1155FactoryImplConfig.address[
    mainnet.id
  ].toLowerCase() as `0x${string}`;

  const fixedPriceMinterAddress = await publicClient.readContract({
    abi: zoraCreator1155FactoryImplConfig.abi,
    address: factoryProxyAddress,
    functionName: "fixedPriceMinter",
  });

  const deployPreminterHash = await walletClient.deployContract({
    abi: preminter.abi,
    bytecode: preminter.bytecode.object as `0x${string}`,
    account: deployerAccount,
  });

  const receipt = await publicClient.waitForTransactionReceipt({
    hash: deployPreminterHash,
  });

  const contractAddress = receipt.contractAddress!;

  const initializeHash = await walletClient.writeContract({
    abi: preminterAbi,
    address: contractAddress,
    functionName: "initialize",
    account: deployerAccount,
    args: [factoryProxyAddress, fixedPriceMinterAddress],
  });

  await publicClient.waitForTransactionReceipt({ hash: initializeHash });

  return {
    contractAddress,
  };
};

describe("ZoraCreator1155Preminter", () => {
  beforeEach<TestContext>(async (ctx) => {
    // deploy signature minter contract
    await testClient.setBalance({
      address: deployerAccount,
      value: parseEther("10"),
    });

    const { contractAddress } = await deployPreminterContract();

    ctx.preminterAddress = contractAddress;
    ctx.zoraMintFee = BigInt(chainConfigs[mainnet.id].MINT_FEE_AMOUNT);
  });

  it<TestContext>("can sign and recover a signature", async ({
    preminterAddress,
  }) => {
    const contractConfig: ContractCreationConfig = {
      contractAdmin: creatorAccount,
      contractURI: "ipfs://asdfasdfasdf",
      contractName: "My fun NFT",
 
    };

    const tokenConfig: TokenCreationConfig = {
      tokenURI: "ipfs://tokenIpfsId0",
      maxSupply: 100n,
      maxTokensPerAddress: 10n,
      pricePerToken: parseEther("0.1"),
      saleDuration: 100n,
      royaltyMintSchedule: 30,
      royaltyBPS: 200,
      royaltyRecipient: creatorAccount,
      uid: 1n
    };

    const signedMessage = await walletClient.signTypedData({
      ...preminterTypedDataDefinition({
        preminterAddress,
        chainId: foundry.id,
        contractConfig,
        tokenConfig,
      }),
      account: creatorAccount,
    });

    const recoveredAddress = await publicClient.readContract({
      abi: preminterAbi,
      address: preminterAddress,
      functionName: "recoverSigner",
      args: [contractConfig, tokenConfig, signedMessage],
    });

    expect(recoveredAddress).to.equal(creatorAccount);
  });

  it<TestContext>(
    "can sign and mint multiple tokens",
    async ({ preminterAddress, zoraMintFee }) => {
      
      // setup contract and token creation parameters
      const contractConfig: ContractCreationConfig = {
        contractAdmin: creatorAccount,
        contractURI: "ipfs://asdfasdfasdf",
        contractName: "My fun NFT",
        
      };

      const tokenConfig: TokenCreationConfig = {
        tokenURI: "ipfs://tokenIpfsId0",
        maxSupply: 100n,
        maxTokensPerAddress: 10n,
        pricePerToken: parseEther("0.1"),
        saleDuration: 100n,
        royaltyMintSchedule: 30,
        royaltyBPS: 200,
        royaltyRecipient: creatorAccount,
        uid: 1n
      };

      // have creator sign the message to create the contract
      // and the token
      const signedMessage = await walletClient.signTypedData({
        ...preminterTypedDataDefinition({
          preminterAddress,
          chainId: foundry.id,
          contractConfig,
          tokenConfig,
        }),
        // signer account is the creator
        account: creatorAccount,
      });

      const quantityToMint = 2n;

      const valueToSend =
        (zoraMintFee + tokenConfig.pricePerToken) * quantityToMint;

      const comment = 'I love this!';

      // now have the collector execute the first signed message;
      // it should create the contract, the token,
      // and min the quantity to mint tokens to the collector
      // the signature along with contract + token creation
      // parameters are required to call this function
      const mintHash = await walletClient.writeContract({
        abi: preminterAbi,
        functionName: "premint",
        account: collectorAccount,
        address: preminterAddress,
        args: [contractConfig, tokenConfig, signedMessage, quantityToMint, comment],
        value: valueToSend,
      });

      // ensure it succeeded
      expect(
        (await publicClient.waitForTransactionReceipt({ hash: mintHash }))
          .status
      ).toBe("success");

      // get contract hash which acts as a unique identifier for contract
      // creation parametesr, and can be used to look up the contract address
      const contractHash = await publicClient.readContract({
        abi: preminterAbi,
        address: preminterAddress,
        functionName: "contractDataHash",
        args: [contractConfig]
      })

      const createdContractAddress = await publicClient.readContract({
        abi: preminterAbi,
        address: preminterAddress,
        functionName: "contractAddresses",
        args: [contractHash],
      });

      const tokenBalance = await publicClient.readContract({
        abi: zoraCreator1155ImplABI,
        address: createdContractAddress,
        functionName: "balanceOf",
        args: [collectorAccount, 1n],
      });

      // get token balance - should be amount that was created
      expect(tokenBalance).toBe(quantityToMint);

      // create a signature to create a second token,
      // with different ipfs url and price per token
      const tokenConfig2: TokenCreationConfig = {
        ...tokenConfig,
        tokenURI: "ipfs://tokenIpfsId2",
        pricePerToken: parseEther("0.05"),
        uid: 2n
      };

      const signedMessage2 = await walletClient.signTypedData({
        ...preminterTypedDataDefinition({
          preminterAddress,
          chainId: foundry.id,
          contractConfig,
          tokenConfig: tokenConfig2,
        }),
        account: creatorAccount,
      });

      const quantityToMint2 = 4n;

      const valueToSend2 =
        (zoraMintFee + tokenConfig2.pricePerToken) * quantityToMint2;

      // now have the collector execute the second signed message
      const mintHash2 = await walletClient.writeContract({
        abi: preminterAbi,
        functionName: "premint",
        account: collectorAccount,
        address: preminterAddress,
        args: [contractConfig, tokenConfig2, signedMessage2, quantityToMint2, comment],
        value: valueToSend2,
      });

      expect(
        (await publicClient.waitForTransactionReceipt({ hash: mintHash2 }))
          .status
      ).toBe("success");

      // get balance of second token
      const tokenBalance2 = await publicClient.readContract({
        abi: zoraCreator1155ImplABI,
        address: createdContractAddress,
        functionName: "balanceOf",
        args: [collectorAccount, 2n],
      });

      expect(tokenBalance2).toBe(quantityToMint2);
    },
    // 10 second timeout
    10 * 1000
  );
});

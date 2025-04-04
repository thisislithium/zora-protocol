import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import {
  zoraCreator1155FactoryImplABI,
  zoraCreator1155ImplABI,
  zoraCreator1155PremintExecutorImplABI,
  zoraCreatorFixedPriceSaleStrategyABI,
  zoraCreatorMerkleMinterStrategyABI,
  zoraCreatorRedeemMinterFactoryABI,
  zoraCreatorRedeemMinterStrategyABI,
  protocolRewardsABI,
  erc20MinterABI,
} from "@zoralabs/zora-1155-contracts";
import { zoraTimedSaleStrategyImplABI } from "@zoralabs/erc20z";
import {
  zoraMints1155ABI,
  zoraMintsManagerImplABI,
  zoraSparks1155ABI,
} from "@zoralabs/sparks-contracts";
import {
  cointagFactoryImplABI,
  cointagImplABI as cointagABI,
} from "@zoralabs/cointags-contracts";
import erc721Drop from "@zoralabs/nft-drop-contracts/dist/artifacts/ERC721Drop.sol/ERC721Drop.json" with { type: "json" };
import zoraNFTCreatorV1 from "@zoralabs/nft-drop-contracts/dist/artifacts/ZoraNFTCreatorV1.sol/ZoraNFTCreatorV1.json" with { type: "json" };
import editionMetadataRenderer from "@zoralabs/nft-drop-contracts/dist/artifacts/EditionMetadataRenderer.sol/EditionMetadataRenderer.json" with { type: "json" };
import dropMetadataRenderer from "@zoralabs/nft-drop-contracts/dist/artifacts/DropMetadataRenderer.sol/DropMetadataRenderer.json" with { type: "json" };
import { commentsImplABI } from "@zoralabs/comments-contracts";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const abisPath = path.join(__dirname, "..", "abis");
if (!fs.existsSync(abisPath)) {
  fs.mkdirSync(abisPath);
}

function output_abi(abiName, abi) {
  fs.writeFileSync(
    path.join(abisPath, `${abiName}.json`),
    JSON.stringify(abi, null, 2),
  );
}

output_abi("ERC721Drop", erc721Drop.abi);
output_abi("ZoraNFTCreatorV1", zoraNFTCreatorV1.abi);
output_abi("EditionMetadataRenderer", editionMetadataRenderer.abi);
output_abi("DropMetadataRenderer", dropMetadataRenderer.abi);

output_abi("ZoraCreator1155FactoryImpl", zoraCreator1155FactoryImplABI);
output_abi("ZoraCreator1155Impl", zoraCreator1155ImplABI);
output_abi(
  "ZoraCreator1155PremintExecutorImpl",
  zoraCreator1155PremintExecutorImplABI,
);
output_abi(
  "ZoraCreatorFixedPriceSaleStrategy",
  zoraCreatorFixedPriceSaleStrategyABI,
);
output_abi(
  "ZoraCreatorMerkleMinterStrategy",
  zoraCreatorMerkleMinterStrategyABI,
);
output_abi("ZoraCreatorRedeemMinterFactory", zoraCreatorRedeemMinterFactoryABI);
output_abi(
  "ZoraCreatorRedeemMinterStrategy",
  zoraCreatorRedeemMinterStrategyABI,
);
output_abi("ZoraTimedSaleStrategy", zoraTimedSaleStrategyImplABI);

output_abi("ProtocolRewards", protocolRewardsABI);

output_abi("ZoraMints1155", zoraMints1155ABI);
output_abi("ZoraMintsManagerImpl", zoraMintsManagerImplABI);
output_abi("ZoraSparks1155", zoraSparks1155ABI);

output_abi("ERC20Minter", erc20MinterABI);

output_abi("Comments", commentsImplABI);
output_abi("CointagFactory", cointagFactoryImplABI);
output_abi("Cointag", cointagABI);

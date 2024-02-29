// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {IGenericComponent} from "../core/components/IGenericComponent.sol";
import {TypesLibrary} from "../core/TypesLibrary.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {TraitCollectionComponent, ID as TRAIT_COLLECTION_COMPONENT_ID, Layout as TraitCollection} from "../generated/components/TraitCollectionComponent.sol";
import {TraitMetadataComponent, ID as TRAIT_METADATA_COMPONENT_ID, Layout as TraitMetadata} from "../generated/components/TraitMetadataComponent.sol";
import {ITraitsProvider, TokenURITrait, TraitDataType} from "../interfaces/ITraitsProvider.sol";
import {JSONRenderer} from "../libraries/JSONRenderer.sol";
import {ITokenURIHandler} from "./ITokenURIHandler.sol";

bytes32 constant TRAIT_NAME_FIELD = keccak256("trait_name");
bytes32 constant VALUE_FIELD = keccak256("value");

struct ComponentData {
    bool isAttribute;
    IGenericComponent component;
    bytes[] byteValues;
    string[] keys;
    TypesLibrary.SchemaValue[] schemaValues;
    TraitMetadata metadata;
}

abstract contract TokenURISystem is
    GameRegistryConsumerUpgradeable,
    ITokenURIHandler
{
    /**
     * @inheritdoc ITokenURIHandler
     */
    function tokenURI(
        address,
        address tokenContract,
        uint256 tokenId
    ) external view virtual override returns (string memory) {
        // Setup the parent component
        uint256 entity = EntityLibrary.tokenToEntity(tokenContract, tokenId);

        // Get all tokenURI trait components for this contract
        TraitCollection memory collection = TraitCollectionComponent(
            _gameRegistry.getComponent(TRAIT_COLLECTION_COMPONENT_ID)
        ).getLayoutValue(EntityLibrary.addressToEntity(tokenContract));

        // Initialize the traits array by counting all traits
        TokenURITrait[] memory extraTraits = getExtraTraits(entity);

        // Initialize traits array, combining traits from components and extra traits
        TokenURITrait[] memory traits = new TokenURITrait[](
            collection.componentIds.length + extraTraits.length
        );

        // Iterate through each component and generate a trait
        ComponentData memory data;
        for (uint256 idx; idx < collection.componentIds.length; idx++) {
            data.isAttribute = collection.isAttribute[idx];
            data.component = IGenericComponent(
                _gameRegistry.getComponent(collection.componentIds[idx])
            );
            (data.keys, data.schemaValues) = data.component.getSchema();
            data.byteValues = data.component.getByteValues(entity);

            // Get trait metadata
            data.metadata = TraitMetadataComponent(
                _gameRegistry.getComponent(TRAIT_METADATA_COMPONENT_ID)
            ).getLayoutValue(collection.componentIds[idx]);

            // Iterate through each component value and generate a trait
            traits[idx] = TokenURITrait({
                name: data.metadata.traitName,
                dataType: _mapSchemaToDataType(data.schemaValues[0]),
                isTopLevelProperty: !data.isAttribute,
                hidden: false,
                value: data.byteValues[0]
            });
        }

        // Add extra traits from contracts overriding _getExtraTraits
        for (uint256 idx; idx < extraTraits.length; idx++) {
            traits[collection.componentIds.length + idx] = extraTraits[idx];
        }

        return JSONRenderer.generateTokenURI(traits);
    }

    /**
     * Virtual function to override when adding additional traits to the tokenURI
     */
    function getExtraTraits(
        uint256 entity
    ) internal view virtual returns (TokenURITrait[] memory extraTraits);

    /** INTERNAL **/

    function _mapSchemaToDataType(
        TypesLibrary.SchemaValue schemaValue
    ) internal pure returns (TraitDataType) {
        if (schemaValue == TypesLibrary.SchemaValue.BOOL) {
            return TraitDataType.BOOL;
        } else if (
            schemaValue == TypesLibrary.SchemaValue.INT8 ||
            schemaValue == TypesLibrary.SchemaValue.INT16 ||
            schemaValue == TypesLibrary.SchemaValue.INT32 ||
            schemaValue == TypesLibrary.SchemaValue.INT64 ||
            schemaValue == TypesLibrary.SchemaValue.INT128 ||
            schemaValue == TypesLibrary.SchemaValue.INT256 ||
            schemaValue == TypesLibrary.SchemaValue.INT
        ) {
            return TraitDataType.INT;
        } else if (
            schemaValue == TypesLibrary.SchemaValue.UINT8 ||
            schemaValue == TypesLibrary.SchemaValue.UINT16 ||
            schemaValue == TypesLibrary.SchemaValue.UINT32 ||
            schemaValue == TypesLibrary.SchemaValue.UINT64 ||
            schemaValue == TypesLibrary.SchemaValue.UINT128 ||
            schemaValue == TypesLibrary.SchemaValue.UINT256
        ) {
            return TraitDataType.UINT;
        } else if (schemaValue == TypesLibrary.SchemaValue.STRING) {
            return TraitDataType.STRING;
        } else if (
            schemaValue == TypesLibrary.SchemaValue.INT8_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.INT16_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.INT32_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.INT64_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.INT128_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.INT256_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.INT_ARRAY
        ) {
            return TraitDataType.INT_ARRAY;
        } else if (
            schemaValue == TypesLibrary.SchemaValue.UINT8_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.UINT16_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.UINT32_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.UINT64_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.UINT128_ARRAY ||
            schemaValue == TypesLibrary.SchemaValue.UINT256_ARRAY
        ) {
            return TraitDataType.UINT_ARRAY;
        }

        // schemaValue == TypesLibrary.SchemaValue.ADDRESS ||
        // schemaValue == TypesLibrary.SchemaValue.ADDRESS_ARRAY ||
        // schemaValue == TypesLibrary.SchemaValue.BOOL_ARRAY ||
        // schemaValue == TypesLibrary.SchemaValue.BYTES ||
        // schemaValue == TypesLibrary.SchemaValue.BYTES4 ||
        // schemaValue == TypesLibrary.SchemaValue.BYTES_ARRAY ||
        // schemaValue == TypesLibrary.SchemaValue.STRING_ARRAY
        return TraitDataType.NOT_INITIALIZED;
    }
}

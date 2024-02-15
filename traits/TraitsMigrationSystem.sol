// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {IGenericComponent} from "../core/components/IGenericComponent.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {IGameRegistry} from "../core/IGameRegistry.sol";
import {TraitDataType} from "../interfaces/ITraitsProvider.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {ANIMATION_URL_TRAIT_ID, DAMAGE_TRAIT_ID, EVASION_TRAIT_ID, SPEED_TRAIT_ID, ACCURACY_TRAIT_ID, HEALTH_TRAIT_ID, DESCRIPTION_TRAIT_ID} from "../Constants.sol";
import {ENERGY_PROVIDED_TRAIT_ID, EQUIPMENT_TYPE_TRAIT_ID, IMAGE_TRAIT_ID, IS_PLACEABLE_TRAIT_ID, MODEL_GLTF_URL_TRAIT_ID, NAME_TRAIT_ID} from "../Constants.sol";
import {PLACEABLE_IS_BOTTOM_STACKABLE_TRAIT_ID, PLACEABLE_IS_TOP_STACKABLE_TRAIT_ID, PLACEABLE_TERRAIN_TRAIT_ID} from "../Constants.sol";
import {RARITY_TRAIT_ID, GLTF_SCALING_FACTOR_TRAIT_ID, SIZE_TRAIT_ID, SHIP_RANK_TRAIT_ID, SOULBOUND_TRAIT_ID} from "../Constants.sol";

import {ID as GAME_ITEMS_ID} from "../tokens/gameitems/IGameItems.sol";
import {AnimationUrlComponent, ID as AnimationUrlComponentId, Layout as AnimationUrlComponentLayout} from "../generated/components/AnimationUrlComponent.sol";
import {CombatModifiersComponent, ID as CombatModifiersComponentId, Layout as CombatModifiersComponentLayout} from "../generated/components/CombatModifiersComponent.sol";
import {DescriptionComponent, ID as DescriptionComponentId, Layout as DescriptionComponentLayout} from "../generated/components/DescriptionComponent.sol";
import {EnergyProvidedComponent, ID as EnergyProvidedComponentId, Layout as EnergyProvidedComponentLayout} from "../generated/components/EnergyProvidedComponent.sol";
import {EquipmentTypeComponent, ID as EquipmentTypeComponentId, Layout as EquipmentTypeComponentLayout} from "../generated/components/EquipmentTypeComponent.sol";
import {ImageUrlComponent, ID as ImageUrlComponentId, Layout as ImageUrlComponentLayout} from "../generated/components/ImageUrlComponent.sol";
import {IsPlaceableComponent, ID as IsPlaceableComponentId, Layout as IsPlaceableComponentLayout} from "../generated/components/IsPlaceableComponent.sol";
import {ModelUrlComponent, ID as ModelUrlComponentId, Layout as ModelUrlComponentLayout} from "../generated/components/ModelUrlComponent.sol";
import {NameComponent, ID as NameComponentId, Layout as NameComponentLayout} from "../generated/components/NameComponent.sol";
import {PlaceableObjectComponent, ID as PlaceableObjectComponentId, Layout as PlaceableObjectComponentLayout} from "../generated/components/PlaceableObjectComponent.sol";
import {RarityComponent, ID as RarityComponentId, Layout as RarityComponentLayout} from "../generated/components/RarityComponent.sol";
import {Scale1DComponent, ID as Scale1DComponentId, Layout as Scale1DComponentLayout} from "../generated/components/Scale1DComponent.sol";
import {Size3DComponent, ID as Size3DComponentId, Layout as Size3DComponentLayout} from "../generated/components/Size3DComponent.sol";
import {ShipRankComponent, ID as ShipRankComponentId, Layout as ShipRankComponentLayout} from "../generated/components/ShipRankComponent.sol";
import {SoulboundComponent, ID as SoulboundComponentId, Layout as SoulboundComponentLayout} from "../generated/components/SoulboundComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.traitsmigrationsystem")
);

contract TraitsMigrationSystem is GameRegistryConsumerUpgradeable {
    /// @notice Trait has not been initialized to the proper type
    error DataTypeMismatch(TraitDataType expected, TraitDataType actual);

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Sets a abi-encoded bytes trait value for component type traits
     * @dev It's not recommended to use this function as it doesn't have type safety
     */
    function setTraitBytes(
        uint256 entity,
        uint256 traitId,
        bytes memory value,
        TraitDataType encodedType
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) returns (bool) {
        // Filter on traitIds and match to an existing component type trait
        if (traitId == ANIMATION_URL_TRAIT_ID) {
            if (encodedType != TraitDataType.STRING) {
                revert DataTypeMismatch(TraitDataType.STRING, encodedType);
            }

            AnimationUrlComponent(
                _gameRegistry.getComponent(AnimationUrlComponentId)
            ).setLayoutValue(
                    entity,
                    AnimationUrlComponentLayout({
                        value: abi.decode(value, (string))
                    })
                );
            return true;
        } else if (traitId == DAMAGE_TRAIT_ID) {
            _setCombatModifier(entity, 0, value, encodedType);
            return true;
        } else if (traitId == EVASION_TRAIT_ID) {
            _setCombatModifier(entity, 1, value, encodedType);
            return true;
        } else if (traitId == SPEED_TRAIT_ID) {
            _setCombatModifier(entity, 2, value, encodedType);
            return true;
        } else if (traitId == ACCURACY_TRAIT_ID) {
            _setCombatModifier(entity, 3, value, encodedType);
            return true;
        } else if (traitId == HEALTH_TRAIT_ID) {
            _setCombatModifier(entity, 4, value, encodedType);
            return true;
        } else if (traitId == DESCRIPTION_TRAIT_ID) {
            if (encodedType != TraitDataType.STRING) {
                revert DataTypeMismatch(TraitDataType.STRING, encodedType);
            }

            DescriptionComponent(
                _gameRegistry.getComponent(DescriptionComponentId)
            ).setLayoutValue(
                    entity,
                    DescriptionComponentLayout({
                        value: abi.decode(value, (string))
                    })
                );
            return true;
        } else if (traitId == ENERGY_PROVIDED_TRAIT_ID) {
            if (encodedType != TraitDataType.UINT) {
                revert DataTypeMismatch(TraitDataType.UINT, encodedType);
            }

            EnergyProvidedComponent(
                _gameRegistry.getComponent(EnergyProvidedComponentId)
            ).setLayoutValue(
                    entity,
                    EnergyProvidedComponentLayout({
                        value: abi.decode(value, (uint256))
                    })
                );
            return true;
        } else if (traitId == EQUIPMENT_TYPE_TRAIT_ID) {
            if (encodedType != TraitDataType.UINT) {
                revert DataTypeMismatch(TraitDataType.UINT, encodedType);
            }

            EquipmentTypeComponent(
                _gameRegistry.getComponent(EquipmentTypeComponentId)
            ).setLayoutValue(
                    entity,
                    EquipmentTypeComponentLayout({
                        value: abi.decode(value, (uint256))
                    })
                );
            return true;
        } else if (traitId == IMAGE_TRAIT_ID) {
            if (encodedType != TraitDataType.STRING) {
                revert DataTypeMismatch(TraitDataType.STRING, encodedType);
            }

            ImageUrlComponent(_gameRegistry.getComponent(ImageUrlComponentId))
                .setLayoutValue(
                    entity,
                    ImageUrlComponentLayout({
                        value: abi.decode(value, (string))
                    })
                );
            return true;
        } else if (traitId == IS_PLACEABLE_TRAIT_ID) {
            if (encodedType != TraitDataType.BOOL) {
                revert DataTypeMismatch(TraitDataType.BOOL, encodedType);
            }

            IsPlaceableComponent(
                _gameRegistry.getComponent(IsPlaceableComponentId)
            ).setLayoutValue(
                    entity,
                    IsPlaceableComponentLayout({
                        value: abi.decode(value, (bool))
                    })
                );
            return true;
        } else if (traitId == MODEL_GLTF_URL_TRAIT_ID) {
            if (encodedType != TraitDataType.STRING) {
                revert DataTypeMismatch(TraitDataType.STRING, encodedType);
            }

            ModelUrlComponent(_gameRegistry.getComponent(ModelUrlComponentId))
                .setLayoutValue(
                    entity,
                    ModelUrlComponentLayout({
                        value: abi.decode(value, (string))
                    })
                );
            return true;
        } else if (traitId == NAME_TRAIT_ID) {
            if (encodedType != TraitDataType.STRING) {
                revert DataTypeMismatch(TraitDataType.STRING, encodedType);
            }

            NameComponent(_gameRegistry.getComponent(NameComponentId))
                .setLayoutValue(
                    entity,
                    NameComponentLayout({value: abi.decode(value, (string))})
                );
            return true;
        } else if (traitId == PLACEABLE_IS_BOTTOM_STACKABLE_TRAIT_ID) {
            if (encodedType != TraitDataType.BOOL) {
                revert DataTypeMismatch(TraitDataType.BOOL, encodedType);
            }
            PlaceableObjectComponent placeableObject = _getPlaceableObject();
            PlaceableObjectComponentLayout memory layout = placeableObject
                .getLayoutValue(entity);

            // Set placeable is bottom stackable value
            layout.isBottomStackable = abi.decode(value, (bool));
            placeableObject.setLayoutValue(entity, layout);
            return true;
        } else if (traitId == PLACEABLE_IS_TOP_STACKABLE_TRAIT_ID) {
            if (encodedType != TraitDataType.BOOL) {
                revert DataTypeMismatch(TraitDataType.BOOL, encodedType);
            }
            PlaceableObjectComponent placeableObject = _getPlaceableObject();
            PlaceableObjectComponentLayout memory layout = placeableObject
                .getLayoutValue(entity);

            // Set placeable is top stackable value
            layout.isTopStackable = abi.decode(value, (bool));
            placeableObject.setLayoutValue(entity, layout);
            return true;
        } else if (traitId == PLACEABLE_TERRAIN_TRAIT_ID) {
            if (encodedType != TraitDataType.UINT) {
                revert DataTypeMismatch(TraitDataType.UINT, encodedType);
            }
            PlaceableObjectComponent placeableObject = _getPlaceableObject();
            PlaceableObjectComponentLayout memory layout = placeableObject
                .getLayoutValue(entity);

            // Set placeable terrain value
            layout.terrain = abi.decode(value, (uint8));
            placeableObject.setLayoutValue(entity, layout);
            return true;
        } else if (traitId == RARITY_TRAIT_ID) {
            if (encodedType != TraitDataType.UINT) {
                revert DataTypeMismatch(TraitDataType.UINT, encodedType);
            }

            // Set rarity value
            RarityComponent(_gameRegistry.getComponent(RarityComponentId))
                .setLayoutValue(
                    entity,
                    RarityComponentLayout({value: abi.decode(value, (uint256))})
                );
            return true;
        } else if (traitId == GLTF_SCALING_FACTOR_TRAIT_ID) {
            // Convert UINT256 to INT64
            if (encodedType != TraitDataType.UINT) {
                revert DataTypeMismatch(TraitDataType.UINT, encodedType);
            }

            // Set scale1d value
            Scale1DComponent(_gameRegistry.getComponent(Scale1DComponentId))
                .setLayoutValue(
                    entity,
                    Scale1DComponentLayout({
                        value: int64(int256(abi.decode(value, (uint256))))
                    })
                );
            return true;
        } else if (traitId == SIZE_TRAIT_ID) {
            // Convert UINT256[] to INT64[]
            if (encodedType != TraitDataType.UINT_ARRAY) {
                revert DataTypeMismatch(TraitDataType.UINT_ARRAY, encodedType);
            }

            // Set size3d value
            uint256[] memory uintValue = abi.decode(value, (uint256[]));
            Size3DComponent(_gameRegistry.getComponent(Size3DComponentId))
                .setLayoutValue(
                    entity,
                    Size3DComponentLayout({
                        x: int64(int256(uintValue[0])),
                        y: int64(int256(uintValue[1])),
                        z: int64(int256(uintValue[2]))
                    })
                );
            return true;
        } else if (traitId == SHIP_RANK_TRAIT_ID) {
            if (encodedType != TraitDataType.UINT) {
                revert DataTypeMismatch(TraitDataType.UINT, encodedType);
            }

            ShipRankComponent(_gameRegistry.getComponent(ShipRankComponentId))
                .setLayoutValue(
                    entity,
                    ShipRankComponentLayout({
                        value: abi.decode(value, (uint256))
                    })
                );
            return true;
        } else if (traitId == SOULBOUND_TRAIT_ID) {
            if (encodedType != TraitDataType.BOOL) {
                revert DataTypeMismatch(TraitDataType.BOOL, encodedType);
            }

            SoulboundComponent(_gameRegistry.getComponent(SoulboundComponentId))
                .setLayoutValue(
                    entity,
                    SoulboundComponentLayout({value: abi.decode(value, (bool))})
                );
            return true;
        }
        return false;
    }

    function getTraitInt256(
        uint256 entity,
        uint256 traitId
    ) public view returns (bool isComponent, int256 value) {
        if (traitId == DAMAGE_TRAIT_ID) {
            isComponent = true;
            value = _getCombatModifier(entity, 0);
        } else if (traitId == EVASION_TRAIT_ID) {
            isComponent = true;
            value = _getCombatModifier(entity, 1);
        } else if (traitId == SPEED_TRAIT_ID) {
            isComponent = true;
            value = _getCombatModifier(entity, 2);
        } else if (traitId == ACCURACY_TRAIT_ID) {
            isComponent = true;
            value = _getCombatModifier(entity, 3);
        } else if (traitId == HEALTH_TRAIT_ID) {
            isComponent = true;
            value = _getCombatModifier(entity, 4);
        }
    }

    function getTraitInt256Array(
        uint256 entity,
        uint256 traitId
    ) public view returns (bool isComponent, int256[] memory value) {
        // No INT256[] traits yet
    }

    function getTraitUint256(
        uint256 entity,
        uint256 traitId
    ) public view returns (bool isComponent, uint256 value) {
        if (traitId == ENERGY_PROVIDED_TRAIT_ID) {
            isComponent = true;
            value = EnergyProvidedComponent(
                _gameRegistry.getComponent(EnergyProvidedComponentId)
            ).getLayoutValue(entity).value;
        } else if (traitId == EQUIPMENT_TYPE_TRAIT_ID) {
            isComponent = true;
            value = EquipmentTypeComponent(
                _gameRegistry.getComponent(EquipmentTypeComponentId)
            ).getLayoutValue(entity).value;
        } else if (traitId == PLACEABLE_TERRAIN_TRAIT_ID) {
            isComponent = true;
            value = PlaceableObjectComponent(
                _gameRegistry.getComponent(PlaceableObjectComponentId)
            ).getLayoutValue(entity).terrain;
        } else if (traitId == RARITY_TRAIT_ID) {
            isComponent = true;
            value = RarityComponent(
                _gameRegistry.getComponent(RarityComponentId)
            ).getLayoutValue(entity).value;
        } else if (traitId == GLTF_SCALING_FACTOR_TRAIT_ID) {
            // Convert INT64 to UINT256
            isComponent = true;
            value = uint256(
                uint64(
                    Scale1DComponent(
                        _gameRegistry.getComponent(PlaceableObjectComponentId)
                    ).getLayoutValue(entity).value
                )
            );
        } else if (traitId == SHIP_RANK_TRAIT_ID) {
            isComponent = true;
            value = ShipRankComponent(
                _gameRegistry.getComponent(ShipRankComponentId)
            ).getLayoutValue(entity).value;
        }
    }

    function getTraitUint256Array(
        uint256 entity,
        uint256 traitId
    ) public view returns (bool isComponent, uint256[] memory value) {
        if (traitId == SIZE_TRAIT_ID) {
            // Convert INT64[] to UINT256[]
            isComponent = true;
            Size3DComponentLayout memory layout = Size3DComponent(
                _gameRegistry.getComponent(Size3DComponentId)
            ).getLayoutValue(entity);

            value = new uint256[](3);
            value[0] = uint256(uint64(layout.x));
            value[1] = uint256(uint64(layout.y));
            value[2] = uint256(uint64(layout.z));
        }
    }

    function getTraitBool(
        uint256 entity,
        uint256 traitId
    ) public view returns (bool isComponent, bool value) {
        if (traitId == IS_PLACEABLE_TRAIT_ID) {
            isComponent = true;
            value = IsPlaceableComponent(
                _gameRegistry.getComponent(IsPlaceableComponentId)
            ).getLayoutValue(entity).value;
        } else if (traitId == PLACEABLE_IS_BOTTOM_STACKABLE_TRAIT_ID) {
            isComponent = true;
            value = PlaceableObjectComponent(
                _gameRegistry.getComponent(PlaceableObjectComponentId)
            ).getLayoutValue(entity).isBottomStackable;
        } else if (traitId == PLACEABLE_IS_TOP_STACKABLE_TRAIT_ID) {
            isComponent = true;
            value = PlaceableObjectComponent(
                _gameRegistry.getComponent(PlaceableObjectComponentId)
            ).getLayoutValue(entity).isTopStackable;
        } else if (traitId == SOULBOUND_TRAIT_ID) {
            isComponent = true;
            value = SoulboundComponent(
                _gameRegistry.getComponent(SoulboundComponentId)
            ).getLayoutValue(entity).value;
        }
    }

    function getTraitString(
        uint256 entity,
        uint256 traitId
    ) public view returns (bool isComponent, string memory value) {
        if (traitId == ANIMATION_URL_TRAIT_ID) {
            isComponent = true;
            value = AnimationUrlComponent(
                _gameRegistry.getComponent(AnimationUrlComponentId)
            ).getLayoutValue(entity).value;
        } else if (traitId == DESCRIPTION_TRAIT_ID) {
            isComponent = true;
            value = DescriptionComponent(
                _gameRegistry.getComponent(DescriptionComponentId)
            ).getLayoutValue(entity).value;
        } else if (traitId == IMAGE_TRAIT_ID) {
            isComponent = true;
            value = ImageUrlComponent(
                _gameRegistry.getComponent(ImageUrlComponentId)
            ).getLayoutValue(entity).value;
        } else if (traitId == MODEL_GLTF_URL_TRAIT_ID) {
            isComponent = true;
            value = ModelUrlComponent(
                _gameRegistry.getComponent(ModelUrlComponentId)
            ).getLayoutValue(entity).value;
        } else if (traitId == NAME_TRAIT_ID) {
            isComponent = true;
            value = NameComponent(_gameRegistry.getComponent(NameComponentId))
                .getLayoutValue(entity)
                .value;
        } else {
            isComponent = false;
        }
    }

    function getTraitBytes(
        uint256 entity,
        uint256 traitId
    ) external view returns (bool isComponent, bytes memory value) {
        if (_getStringComponentId(traitId) != 0) {
            string memory decodedValue;
            (isComponent, decodedValue) = getTraitString(entity, traitId);
            value = abi.encode(decodedValue);
        } else if (_getUintComponentId(traitId) != 0) {
            uint256 decodedValue;
            (isComponent, decodedValue) = getTraitUint256(entity, traitId);
            value = abi.encode(decodedValue);
        } else if (_getUintArrayComponentId(traitId) != 0) {
            uint256[] memory decodedValue;
            (isComponent, decodedValue) = getTraitUint256Array(entity, traitId);
            value = abi.encode(decodedValue);
        } else if (_getIntComponentId(traitId) != 0) {
            int256 decodedValue;
            (isComponent, decodedValue) = getTraitInt256(entity, traitId);
            value = abi.encode(decodedValue);
        } else if (_getIntArrayComponentId(traitId) != 0) {
            int256[] memory decodedValue;
            (isComponent, decodedValue) = getTraitInt256Array(entity, traitId);
            value = abi.encode(decodedValue);
        } else if (_getBoolComponentId(traitId) != 0) {
            bool decodedValue;
            (isComponent, decodedValue) = getTraitBool(entity, traitId);
            value = abi.encode(decodedValue);
        }
    }

    function hasTrait(
        uint256 entity,
        uint256 traitId
    ) external view returns (bool isComponent, bool entityHasTrait) {
        uint256 componentId;

        // Check each trait category for matching componentId
        componentId = _getStringComponentId(traitId);
        if (componentId == 0) {
            componentId = _getUintComponentId(traitId);
        }
        if (componentId == 0) {
            componentId = _getUintArrayComponentId(traitId);
        }
        if (componentId == 0) {
            componentId = _getIntComponentId(traitId);
        }
        if (componentId == 0) {
            componentId = _getIntArrayComponentId(traitId);
        }
        if (componentId == 0) {
            componentId = _getBoolComponentId(traitId);
        }

        // Get return values
        if (componentId != 0) {
            isComponent = true;
            entityHasTrait = IGenericComponent(
                _gameRegistry.getComponent(componentId)
            ).has(entity);
        }
    }

    function isValidContract(
        address tokenContract
    ) external view returns (bool) {
        if (tokenContract == _getSystem(GAME_ITEMS_ID)) {
            return true;
        }
        return false;
    }

    /** INTERNAL **/

    function _setCombatModifier(
        uint256 entity,
        uint256 index,
        bytes memory value,
        TraitDataType encodedType
    ) internal {
        if (encodedType != TraitDataType.INT) {
            revert DataTypeMismatch(TraitDataType.INT, encodedType);
        }

        CombatModifiersComponent component = CombatModifiersComponent(
            _gameRegistry.getComponent(CombatModifiersComponentId)
        );
        CombatModifiersComponentLayout memory layout = component.getLayoutValue(
            entity
        );

        if (layout.value.length == 0) {
            layout.value = new int64[](5);
        }

        layout.value[index] = int64(abi.decode(value, (int256)));
        component.setLayoutValue(
            entity,
            CombatModifiersComponentLayout({value: layout.value})
        );
    }

    function _getCombatModifier(
        uint256 entity,
        uint256 index
    ) internal view returns (int256) {
        return
            int256(
                CombatModifiersComponent(
                    _gameRegistry.getComponent(CombatModifiersComponentId)
                ).getLayoutValue(entity).value[index]
            );
    }

    function _getPlaceableObject()
        internal
        view
        returns (PlaceableObjectComponent)
    {
        return
            PlaceableObjectComponent(
                _gameRegistry.getComponent(PlaceableObjectComponentId)
            );
    }

    function _getStringComponentId(
        uint256 traitId
    ) internal pure returns (uint256) {
        if (traitId == ANIMATION_URL_TRAIT_ID) {
            return AnimationUrlComponentId;
        } else if (traitId == DESCRIPTION_TRAIT_ID) {
            return DescriptionComponentId;
        } else if (traitId == IMAGE_TRAIT_ID) {
            return ImageUrlComponentId;
        } else if (traitId == MODEL_GLTF_URL_TRAIT_ID) {
            return ModelUrlComponentId;
        } else if (traitId == NAME_TRAIT_ID) {
            return NameComponentId;
        }
        return 0;
    }

    function _getUintComponentId(
        uint256 traitId
    ) internal pure returns (uint256) {
        if (traitId == ENERGY_PROVIDED_TRAIT_ID) {
            return EnergyProvidedComponentId;
        } else if (traitId == EQUIPMENT_TYPE_TRAIT_ID) {
            return EquipmentTypeComponentId;
        } else if (traitId == PLACEABLE_TERRAIN_TRAIT_ID) {
            return PlaceableObjectComponentId;
        } else if (traitId == RARITY_TRAIT_ID) {
            return RarityComponentId;
        } else if (traitId == GLTF_SCALING_FACTOR_TRAIT_ID) {
            return Scale1DComponentId;
        } else if (traitId == SHIP_RANK_TRAIT_ID) {
            return ShipRankComponentId;
        }
        return 0;
    }

    function _getUintArrayComponentId(
        uint256 traitId
    ) internal pure returns (uint256) {
        if (traitId == SIZE_TRAIT_ID) {
            return Size3DComponentId;
        }
        return 0;
    }

    function _getIntComponentId(
        uint256 traitId
    ) internal pure returns (uint256) {
        if (
            traitId == DAMAGE_TRAIT_ID ||
            traitId == EVASION_TRAIT_ID ||
            traitId == SPEED_TRAIT_ID ||
            traitId == ACCURACY_TRAIT_ID ||
            traitId == HEALTH_TRAIT_ID
        ) {
            return CombatModifiersComponentId;
        }
        return 0;
    }

    function _getIntArrayComponentId(uint256) internal pure returns (uint256) {
        // No INT256[] traits yet
        return 0;
    }

    function _getBoolComponentId(
        uint256 traitId
    ) internal pure returns (uint256) {
        if (traitId == IS_PLACEABLE_TRAIT_ID) {
            return IsPlaceableComponentId;
        } else if (
            traitId == PLACEABLE_IS_BOTTOM_STACKABLE_TRAIT_ID ||
            traitId == PLACEABLE_IS_TOP_STACKABLE_TRAIT_ID
        ) {
            return PlaceableObjectComponentId;
        } else if (traitId == SOULBOUND_TRAIT_ID) {
            return SoulboundComponentId;
        }
        return 0;
    }
}

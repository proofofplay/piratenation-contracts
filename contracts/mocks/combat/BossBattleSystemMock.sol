// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../combat/BossBattleSystem.sol";

contract BossBattleSystemMock is BossBattleSystem {
    bool public useFullValidationFlag;

    function setFullValidationFlag(bool flag) external {
        require(useFullValidationFlag != flag);
        useFullValidationFlag = flag;
    }

    function getBattle(
        uint256 battleEntity
    ) external view returns (Battle memory) {
        return _getBattle(battleEntity);
    }

    function getEntity(uint256 tokenId) external view returns (uint256) {
        return EntityLibrary.tokenToEntity(address(this), tokenId);
    }

    function getToken(
        uint256 entity
    ) external pure returns (address tokenAddress, uint256 tokenId) {
        return EntityLibrary.entityToToken(entity);
    }

    function getCurrentBattleId() external view returns (uint256) {
        return _getCurrentBattleId();
    }

    function rewindAccountCooldown(uint32 rewindTime) external {
        ICooldownSystem cooldown = ICooldownSystem(
            _getSystem(COOLDOWN_SYSTEM_ID)
        );

        cooldown.reduceCooldown(
            EntityLibrary.addressToEntity(_msgSender()),
            BOSS_BATTLE_COOLDOWN_ID,
            rewindTime
        );
    }

    function rewindShipCooldown(
        uint256 shipEntity,
        uint32 rewindTime
    ) external {
        ICooldownSystem cooldown = ICooldownSystem(
            _getSystem(COOLDOWN_SYSTEM_ID)
        );

        cooldown.reduceCooldown(
            shipEntity,
            BOSS_BATTLE_COOLDOWN_ID,
            rewindTime
        );
    }

    function rewindBattleTimelimit(
        uint256 battleEntity,
        uint32 rewindTime
    ) external {
        ICooldownSystem cooldown = ICooldownSystem(
            _getSystem(COOLDOWN_SYSTEM_ID)
        );

        cooldown.reduceCooldown(
            battleEntity,
            BOSS_BATTLE_COOLDOWN_ID,
            rewindTime
        );
    }

    /**
     * @dev Resolves an active battle with validations
     * @param params Struct of EndBattleParams inputs
     */
    function endBattleMock(
        EndBattleParams calldata params
    ) external nonReentrant {
        // Check caller is executing their own battle || battle entity != 0
        address account = _getPlayerAccount(_msgSender());
        if (
            _getBattleEntity(account) != params.battleEntity ||
            params.battleEntity == 0
        ) {
            revert InvalidCallToEndBattle();
        }

        // Check if call to end-battle still within battle time limit
        if (
            !ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID)).isInCooldown(
                params.battleEntity,
                BOSS_BATTLE_COOLDOWN_ID
            )
        ) {
            revert BattleExpired();
        }

        // Get Active battle
        Battle memory battle = _getBattle(params.battleEntity);

        if (
            params.moves.length >
            IGameGlobals(_getSystem(GAME_GLOBALS_ID)).getUint256(
                BOSS_BATTLE_MAX_MOVE_COUNT
            ) ||
            params.moves.length == 0
        ) {
            revert InvalidEndBattleParams();
        }

        ITraitsProvider traitsProvider = _traitsProvider();

        // Get ship starting health & boss starting health
        uint256 shipStartingHealth = battle.defenderCombatable.getCurrentHealth(
            battle.attackerEntity,
            traitsProvider
        );
        uint256 bossStartingHealth = battle.defenderCombatable.getCurrentHealth(
            battle.defenderEntity,
            traitsProvider
        );

        // Record the killing blow
        bool isFinalBlow;
        if (
            bossStartingHealth != 0 &&
            params.totalDamageDealt >= bossStartingHealth
        ) {
            isFinalBlow = true;
            bossEntityToFinalBlow[battle.defenderEntity] = FinalBlow(
                battle.attackerEntity,
                account
            );
        }

        _updateBossBattleCount(
            account,
            battle.defenderEntity,
            params.totalDamageDealt
        );

        // Emit results and set new health values of Boss & Ship
        emit BossBattleResult(
            account,
            battle.attackerEntity,
            battle.defenderEntity,
            params.battleEntity,
            shipStartingHealth,
            params.totalDamageDealt == 0
                ? bossStartingHealth
                : battle.defenderCombatable.decreaseHealth(
                    battle.defenderEntity,
                    params.totalDamageDealt
                ),
            params.totalDamageDealt,
            params.totalDamageTaken,
            isFinalBlow
        );

        // Clear battle record
        _clearBattleEntity(account);
    }
}

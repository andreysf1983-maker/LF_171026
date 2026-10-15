/*
 * Copyright (C) 2008-2018 LEGIONFORGE <https://www.legionforge.ru/>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef LEGIONFORGE_DB2STORES_H
#define LEGIONFORGE_DB2STORES_H

#include "DB2Store.h"
#include "DB2Structure.h"
#include "SharedDefines.h"
#include <map>
#include <set>
#include <unordered_map>
#include <unordered_set>
#include <vector>

 // temporary hack until includes are sorted out (don't want to pull in Windows.h)
#ifdef GetClassName
#undef GetClassName
#endif

class DB2HotfixGeneratorBase;

LF_GAME_API extern DB2Storage<AchievementEntry>                     sAchievementStore;
LF_GAME_API extern DB2Storage<AdventureJournalEntry>                sAdventureJournalStore;
LF_GAME_API extern DB2Storage<AnimKitEntry>                         sAnimKitStore;
LF_GAME_API extern DB2Storage<AreaTableEntry>                       sAreaTableStore;
LF_GAME_API extern DB2Storage<AreaTriggerEntry>                     sAreaTriggerStore;
LF_GAME_API extern DB2Storage<ArmorLocationEntry>                   sArmorLocationStore;
LF_GAME_API extern DB2Storage<ArtifactEntry>                        sArtifactStore;
LF_GAME_API extern DB2Storage<ArtifactCategoryEntry>                sArtifactCategoryStore;
LF_GAME_API extern DB2Storage<ArtifactAppearanceEntry>              sArtifactAppearanceStore;
LF_GAME_API extern DB2Storage<ArtifactAppearanceSetEntry>           sArtifactAppearanceSetStore;
LF_GAME_API extern DB2Storage<ArtifactPowerEntry>                   sArtifactPowerStore;
LF_GAME_API extern DB2Storage<ArtifactPowerPickerEntry>             sArtifactPowerPickerStore;
LF_GAME_API extern DB2Storage<ArtifactTierEntry>                    sArtifactTierStore;
LF_GAME_API extern DB2Storage<ArtifactUnlockEntry>                  sArtifactUnlockStore;
LF_GAME_API extern DB2Storage<AuctionHouseEntry>                    sAuctionHouseStore;
LF_GAME_API extern DB2Storage<BankBagSlotPricesEntry>               sBankBagSlotPricesStore;
LF_GAME_API extern DB2Storage<BannedAddonsEntry>                    sBannedAddonsStore;
LF_GAME_API extern DB2Storage<BarberShopStyleEntry>                 sBarberShopStyleStore;
LF_GAME_API extern DB2Storage<BattlePetAbilityEntry>                sBattlePetAbilityStore;
LF_GAME_API extern DB2Storage<BattlePetAbilityEffectEntry>          sBattlePetAbilityEffectStore;
LF_GAME_API extern DB2Storage<BattlePetAbilityStateEntry>           sBattlePetAbilityStateStore;
LF_GAME_API extern DB2Storage<BattlePetAbilityTurnEntry>            sBattlePetAbilityTurnStore;
LF_GAME_API extern DB2Storage<BattlePetBreedQualityEntry>           sBattlePetBreedQualityStore;
LF_GAME_API extern DB2Storage<BattlePetBreedStateEntry>             sBattlePetBreedStateStore;
LF_GAME_API extern DB2Storage<BattlePetSpeciesEntry>                sBattlePetSpeciesStore;
LF_GAME_API extern DB2Storage<BattlePetSpeciesStateEntry>           sBattlePetSpeciesStateStore;
LF_GAME_API extern DB2Storage<BattlePetSpeciesXAbilityEntry>        sBattlePetSpeciesXAbilityEntry;
LF_GAME_API extern DB2Storage<BattlemasterListEntry>                sBattlemasterListStore;
LF_GAME_API extern DB2Storage<BroadcastTextEntry>                   sBroadcastTextStore;
LF_GAME_API extern DB2Storage<CharStartOutfitEntry>                 sCharStartOutfitStore;
LF_GAME_API extern DB2Storage<CharTitlesEntry>                      sCharTitlesStore;
LF_GAME_API extern DB2Storage<ChatChannelsEntry>                    sChatChannelsStore;
LF_GAME_API extern DB2Storage<ChrClassesEntry>                      sChrClassesStore;
LF_GAME_API extern DB2Storage<ChrRacesEntry>                        sChrRacesStore;
LF_GAME_API extern DB2Storage<ChrSpecializationEntry>               sChrSpecializationStore;
LF_GAME_API extern DB2Storage<CinematicCameraEntry>                 sCinematicCameraStore;
LF_GAME_API extern DB2Storage<CinematicSequencesEntry>              sCinematicSequencesStore;
LF_GAME_API extern DB2Storage<ConversationLineEntry>                sConversationLineStore;
LF_GAME_API extern DB2Storage<CreatureDisplayInfoEntry>             sCreatureDisplayInfoStore;
LF_GAME_API extern DB2Storage<CreatureDisplayInfoExtraEntry>        sCreatureDisplayInfoExtraStore;
LF_GAME_API extern DB2Storage<CreatureFamilyEntry>                  sCreatureFamilyStore;
LF_GAME_API extern DB2Storage<CreatureModelDataEntry>               sCreatureModelDataStore;
LF_GAME_API extern DB2Storage<CreatureTypeEntry>                    sCreatureTypeStore;
LF_GAME_API extern DB2Storage<CriteriaEntry>                        sCriteriaStore;
LF_GAME_API extern DB2Storage<CriteriaTreeEntry>                    sCriteriaTreeStore;
LF_GAME_API extern DB2Storage<CurrencyTypesEntry>                   sCurrencyTypesStore;
LF_GAME_API extern DB2Storage<CurveEntry>                           sCurveStore;
LF_GAME_API extern DB2Storage<DestructibleModelDataEntry>           sDestructibleModelDataStore;
LF_GAME_API extern DB2Storage<DifficultyEntry>                      sDifficultyStore;
LF_GAME_API extern DB2Storage<DungeonEncounterEntry>                sDungeonEncounterStore;
LF_GAME_API extern DB2Storage<DurabilityCostsEntry>                 sDurabilityCostsStore;
LF_GAME_API extern DB2Storage<DurabilityQualityEntry>               sDurabilityQualityStore;
LF_GAME_API extern DB2Storage<EmotesEntry>                          sEmotesStore;
LF_GAME_API extern DB2Storage<EmotesTextEntry>                      sEmotesTextStore;
LF_GAME_API extern DB2Storage<FactionEntry>                         sFactionStore;
LF_GAME_API extern DB2Storage<FactionTemplateEntry>                 sFactionTemplateStore;
LF_GAME_API extern DB2Storage<GameObjectDisplayInfoEntry>           sGameObjectDisplayInfoStore;
LF_GAME_API extern DB2Storage<GameObjectsEntry>                     sGameObjectsStore;
LF_GAME_API extern DB2Storage<GarrAbilityEntry>                     sGarrAbilityStore;
LF_GAME_API extern DB2Storage<GarrBuildingEntry>                    sGarrBuildingStore;
LF_GAME_API extern DB2Storage<GarrBuildingPlotInstEntry>            sGarrBuildingPlotInstStore;
LF_GAME_API extern DB2Storage<GarrClassSpecEntry>                   sGarrClassSpecStore;
LF_GAME_API extern DB2Storage<GarrFollowerEntry>                    sGarrFollowerStore;
LF_GAME_API extern DB2Storage<GarrFollowerXAbilityEntry>            sGarrFollowerXAbilityStore;
LF_GAME_API extern DB2Storage<GarrMissionEntry>                     sGarrMissionStore;
LF_GAME_API extern DB2Storage<GarrPlotBuildingEntry>                sGarrPlotBuildingStore;
LF_GAME_API extern DB2Storage<GarrPlotEntry>                        sGarrPlotStore;
LF_GAME_API extern DB2Storage<GarrPlotBuildingEntry>                sGarrPlotBuildingStore;
LF_GAME_API extern DB2Storage<GarrPlotInstanceEntry>                sGarrPlotInstanceStore;
LF_GAME_API extern DB2Storage<GarrSiteLevelEntry>                   sGarrSiteLevelStore;
LF_GAME_API extern DB2Storage<GarrSiteLevelPlotInstEntry>           sGarrSiteLevelPlotInstStore;
LF_GAME_API extern DB2Storage<GemPropertiesEntry>                   sGemPropertiesStore;
LF_GAME_API extern DB2Storage<GlobalStringsEntry>                   sGlobalStringsStore;
LF_GAME_API extern DB2Storage<GlyphPropertiesEntry>                 sGlyphPropertiesStore;
LF_GAME_API extern DB2Storage<GuildColorBackgroundEntry>            sGuildColorBackgroundStore;
LF_GAME_API extern DB2Storage<GuildColorBorderEntry>                sGuildColorBorderStore;
LF_GAME_API extern DB2Storage<GuildColorEmblemEntry>                sGuildColorEmblemStore;
LF_GAME_API extern DB2Storage<GuildPerkSpellsEntry>                 sGuildPerkSpellsStore;
LF_GAME_API extern DB2Storage<HolidaysEntry>                        sHolidaysStore;
LF_GAME_API extern DB2Storage<ImportPriceArmorEntry>                sImportPriceArmorStore;
LF_GAME_API extern DB2Storage<ImportPriceQualityEntry>              sImportPriceQualityStore;
LF_GAME_API extern DB2Storage<ImportPriceShieldEntry>               sImportPriceShieldStore;
LF_GAME_API extern DB2Storage<ImportPriceWeaponEntry>               sImportPriceWeaponStore;
LF_GAME_API extern DB2Storage<ItemAppearanceEntry>                  sItemAppearanceStore;
LF_GAME_API extern DB2Storage<ItemArmorQualityEntry>                sItemArmorQualityStore;
LF_GAME_API extern DB2Storage<ItemArmorShieldEntry>                 sItemArmorShieldStore;
LF_GAME_API extern DB2Storage<ItemArmorTotalEntry>                  sItemArmorTotalStore;
LF_GAME_API extern DB2Storage<ItemBagFamilyEntry>                   sItemBagFamilyStore;
LF_GAME_API extern DB2Storage<ItemDamageAmmoEntry>                  sItemDamageAmmoStore;
LF_GAME_API extern DB2Storage<ItemDamageOneHandEntry>               sItemDamageOneHandStore;
LF_GAME_API extern DB2Storage<ItemDamageOneHandCasterEntry>         sItemDamageOneHandCasterStore;
LF_GAME_API extern DB2Storage<ItemDamageTwoHandEntry>               sItemDamageTwoHandStore;
LF_GAME_API extern DB2Storage<ItemDamageTwoHandCasterEntry>         sItemDamageTwoHandCasterStore;
LF_GAME_API extern DB2Storage<ItemDisenchantLootEntry>              sItemDisenchantLootStore;
LF_GAME_API extern DB2Storage<ItemEffectEntry>                      sItemEffectStore;
LF_GAME_API extern DB2Storage<ItemEntry>                            sItemStore;
LF_GAME_API extern DB2Storage<ItemExtendedCostEntry>                sItemExtendedCostStore;
LF_GAME_API extern DB2Storage<ItemLimitCategoryEntry>               sItemLimitCategoryStore;
LF_GAME_API extern DB2Storage<ItemModifiedAppearanceEntry>          sItemModifiedAppearanceStore;
LF_GAME_API extern DB2Storage<ItemPriceBaseEntry>                   sItemPriceBaseStore;
LF_GAME_API extern DB2Storage<ItemRandomPropertiesEntry>            sItemRandomPropertiesStore;
LF_GAME_API extern DB2Storage<ItemRandomSuffixEntry>                sItemRandomSuffixStore;
LF_GAME_API extern DB2Storage<ItemSearchNameEntry>                  sItemSearchNameStore;
LF_GAME_API extern DB2Storage<ItemSetEntry>                         sItemSetStore;
LF_GAME_API extern DB2Storage<ItemSetSpellEntry>                    sItemSetSpellStore;
LF_GAME_API extern DB2Storage<ItemSparseEntry>                      sItemSparseStore;
LF_GAME_API extern DB2Storage<ItemSpecEntry>                        sItemSpecStore;
LF_GAME_API extern DB2Storage<ItemSpecOverrideEntry>                sItemSpecOverrideStore;
LF_GAME_API extern DB2Storage<ItemUpgradeEntry>                     sItemUpgradeStore;
LF_GAME_API extern DB2Storage<LFGDungeonsEntry>                     sLFGDungeonsStore;
LF_GAME_API extern DB2Storage<LiquidTypeEntry>                      sLiquidTypeStore;
LF_GAME_API extern DB2Storage<LockEntry>                            sLockStore;
LF_GAME_API extern DB2Storage<MailTemplateEntry>                    sMailTemplateStore;
LF_GAME_API extern DB2Storage<MapEntry>                             sMapStore;
LF_GAME_API extern DB2Storage<ModifierTreeEntry>                    sModifierTreeStore;
LF_GAME_API extern DB2Storage<MountCapabilityEntry>                 sMountCapabilityStore;
LF_GAME_API extern DB2Storage<MountEntry>                           sMountStore;
LF_GAME_API extern DB2Storage<MovieEntry>                           sMovieStore;
LF_GAME_API extern DB2Storage<OverrideSpellDataEntry>               sOverrideSpellDataStore;
LF_GAME_API extern DB2Storage<PhaseEntry>                           sPhaseStore;
LF_GAME_API extern DB2Storage<PlayerConditionEntry>                 sPlayerConditionStore;
LF_GAME_API extern DB2Storage<PowerDisplayEntry>                    sPowerDisplayStore;
LF_GAME_API extern DB2Storage<PvpTalentEntry>                       sPvpTalentStore;
LF_GAME_API extern DB2Storage<PvpTalentUnlockEntry>                 sPvpTalentUnlockStore;
LF_GAME_API extern DB2Storage<QuestFactionRewardEntry>              sQuestFactionRewardStore;
LF_GAME_API extern DB2Storage<QuestV2CliTaskEntry>                  sQuestV2CliTaskStore;
LF_GAME_API extern DB2Storage<QuestMoneyRewardEntry>                sQuestMoneyRewardStore;
LF_GAME_API extern DB2Storage<QuestSortEntry>                       sQuestSortStore;
LF_GAME_API extern DB2Storage<QuestXPEntry>                         sQuestXPStore;
LF_GAME_API extern DB2Storage<RandPropPointsEntry>                  sRandPropPointsStore;
LF_GAME_API extern DB2Storage<RewardPackEntry>                      sRewardPackStore;
LF_GAME_API extern DB2Storage<SandboxScalingEntry>                  sSandboxScalingStore;
LF_GAME_API extern DB2Storage<ScalingStatDistributionEntry>         sScalingStatDistributionStore;
LF_GAME_API extern DB2Storage<ScenarioEntry>                        sScenarioStore;
LF_GAME_API extern DB2Storage<ScenarioStepEntry>                    sScenarioStepStore;
LF_GAME_API extern DB2Storage<SkillLineEntry>                       sSkillLineStore;
LF_GAME_API extern DB2Storage<SceneScriptPackageEntry>              sSceneScriptPackageStore;
LF_GAME_API extern DB2Storage<SkillLineAbilityEntry>                sSkillLineAbilityStore;
LF_GAME_API extern DB2Storage<SkillRaceClassInfoEntry>              sSkillRaceClassInfoStore;
LF_GAME_API extern DB2Storage<SoundKitEntry>                        sSoundKitStore;
LF_GAME_API extern DB2Storage<SpellEntry>                           sSpellStore;
LF_GAME_API extern DB2Storage<SpellAuraOptionsEntry>                sSpellAuraOptionsStore;
LF_GAME_API extern DB2Storage<SpellAuraRestrictionsEntry>           sSpellAuraRestrictionsStore;
LF_GAME_API extern DB2Storage<SpellCastTimesEntry>                  sSpellCastTimesStore;
LF_GAME_API extern DB2Storage<SpellCastingRequirementsEntry>        sSpellCastingRequirementsStore;
LF_GAME_API extern DB2Storage<SpellCategoriesEntry>                 sSpellCategoriesStore;
LF_GAME_API extern DB2Storage<SpellCategoryEntry>                   sSpellCategoryStore;
LF_GAME_API extern DB2Storage<SpellClassOptionsEntry>               sSpellClassOptionsStore;
LF_GAME_API extern DB2Storage<SpellCooldownsEntry>                  sSpellCooldownsStore;
LF_GAME_API extern DB2Storage<SpellDurationEntry>                   sSpellDurationStore;
LF_GAME_API extern DB2Storage<SpellEffectEntry>                     sSpellEffectStore;
LF_GAME_API extern DB2Storage<SpellEquippedItemsEntry>              sSpellEquippedItemsStore;
LF_GAME_API extern DB2Storage<SpellFocusObjectEntry>                sSpellFocusObjectStore;
LF_GAME_API extern DB2Storage<SpellInterruptsEntry>                 sSpellInterruptsStore;
LF_GAME_API extern DB2Storage<SpellItemEnchantmentEntry>            sSpellItemEnchantmentStore;
LF_GAME_API extern DB2Storage<SpellItemEnchantmentConditionEntry>   sSpellItemEnchantmentConditionStore;
LF_GAME_API extern DB2Storage<SpellLearnSpellEntry>                 sSpellLearnSpellStore;
LF_GAME_API extern DB2Storage<SpellLevelsEntry>                     sSpellLevelsStore;
LF_GAME_API extern DB2Storage<SpellMiscEntry>                       sSpellMiscStore;
LF_GAME_API extern DB2Storage<SpellPowerEntry>                      sSpellPowerStore;
LF_GAME_API extern DB2Storage<SpellProcsPerMinuteEntry>             sSpellProcsPerMinuteStore;
LF_GAME_API extern DB2Storage<SpellRadiusEntry>                     sSpellRadiusStore;
LF_GAME_API extern DB2Storage<SpellRangeEntry>                      sSpellRangeStore;
LF_GAME_API extern DB2Storage<SpellReagentsEntry>                   sSpellReagentsStore;
LF_GAME_API extern DB2Storage<SpellScalingEntry>                    sSpellScalingStore;
LF_GAME_API extern DB2Storage<SpellShapeshiftEntry>                 sSpellShapeshiftStore;
LF_GAME_API extern DB2Storage<SpellShapeshiftFormEntry>             sSpellShapeshiftFormStore;
LF_GAME_API extern DB2Storage<SpellTargetRestrictionsEntry>         sSpellTargetRestrictionsStore;
LF_GAME_API extern DB2Storage<SpellTotemsEntry>                     sSpellTotemsStore;
LF_GAME_API extern DB2Storage<SpellXSpellVisualEntry>               sSpellXSpellVisualStore;
LF_GAME_API extern DB2Storage<SummonPropertiesEntry>                sSummonPropertiesStore;
LF_GAME_API extern DB2Storage<TalentEntry>                          sTalentStore;
LF_GAME_API extern DB2Storage<TaxiNodesEntry>                       sTaxiNodesStore;
LF_GAME_API extern DB2Storage<TaxiPathEntry>                        sTaxiPathStore;
LF_GAME_API extern DB2Storage<TransmogHolidayEntry>                 sTransmogHolidayStore;
LF_GAME_API extern DB2Storage<TransmogSetEntry>                     sTransmogSetStore;
LF_GAME_API extern DB2Storage<TransmogSetGroupEntry>                sTransmogSetGroupStore;
LF_GAME_API extern DB2Storage<TransmogSetItemEntry>                 sTransmogSetItemStore;
LF_GAME_API extern DB2Storage<TransportAnimationEntry>              sTransportAnimationStore;
LF_GAME_API extern DB2Storage<TransportRotationEntry>               sTransportRotationStore;
LF_GAME_API extern DB2Storage<UnitPowerBarEntry>                    sUnitPowerBarStore;
LF_GAME_API extern DB2Storage<VehicleEntry>                         sVehicleStore;
LF_GAME_API extern DB2Storage<VehicleSeatEntry>                     sVehicleSeatStore;
LF_GAME_API extern DB2Storage<WorldEffectEntry>                     sWorldEffectStore;
LF_GAME_API extern DB2Storage<WorldMapAreaEntry>                    sWorldMapAreaStore;
LF_GAME_API extern DB2Storage<WorldMapOverlayEntry>                 sWorldMapOverlayStore;
LF_GAME_API extern DB2Storage<WorldSafeLocsEntry>                   sWorldSafeLocsStore;

struct TaxiPathBySourceAndDestination
{
    TaxiPathBySourceAndDestination() : ID(0), price(0) { }
    TaxiPathBySourceAndDestination(uint32 _id, uint32 _price) : ID(_id), price(_price) { }

    uint32 ID;
    uint32 price;
};

typedef std::map<uint32, TaxiPathBySourceAndDestination> TaxiPathSetForSource;
typedef std::map<uint32, TaxiPathSetForSource> TaxiPathSetBySource;

typedef std::vector<TaxiPathNodeEntry const*> TaxiPathNodeList;
typedef std::vector<TaxiPathNodeList> TaxiPathNodesByPath;

LF_GAME_API extern TaxiMask                                         sTaxiNodesMask;
LF_GAME_API extern TaxiMask                                         sOldContinentsNodesMask;
LF_GAME_API extern TaxiMask                                         sHordeTaxiNodesMask;
LF_GAME_API extern TaxiMask                                         sAllianceTaxiNodesMask;
LF_GAME_API extern TaxiPathSetBySource                              sTaxiPathSetBySource;
LF_GAME_API extern TaxiPathNodesByPath                              sTaxiPathNodesByPath;

#define DEFINE_DB2_SET_COMPARATOR(structure) \
    struct structure ## Comparator \
    { \
        bool operator()(structure const* left, structure const* right) const { return Compare(left, right); } \
        static bool Compare(structure const* left, structure const* right); \
    };

class LF_GAME_API DB2Manager
{
public:
    DEFINE_DB2_SET_COMPARATOR(MountTypeXCapabilityEntry)

    typedef std::vector<ItemBonusEntry const*> ItemBonusList;
    typedef std::unordered_map<uint32, std::unordered_map<uint32, MapDifficultyEntry const*>> MapDifficultyContainer;
    typedef std::set<MountTypeXCapabilityEntry const*, MountTypeXCapabilityEntryComparator> MountTypeXCapabilitySet;
    typedef std::vector<MountXDisplayEntry const*> MountXDisplayContainer;

    static DB2Manager& Instance();

    void LoadStores(std::string const& dataPath, uint32 defaultLocale);
    DB2StorageBase const* GetStorage(uint32 type) const;

    void LoadHotfixData();
    std::map<uint64, int32> const& GetHotfixData() const;

    std::vector<uint32> GetAreasForGroup(uint32 areaGroupId) const;
    static bool IsInArea(uint32 objectAreaId, uint32 areaId);
    std::vector<ArtifactPowerEntry const*> GetArtifactPowers(uint8 artifactId) const;
    std::unordered_set<uint32> const* GetArtifactPowerLinks(uint32 artifactPowerId) const;
    ArtifactPowerRankEntry const* GetArtifactPowerRank(uint32 artifactPowerId, uint8 rank) const;
    static char const* GetBroadcastTextValue(BroadcastTextEntry const* broadcastText, LocaleConstant locale = DEFAULT_LOCALE, uint8 gender = GENDER_MALE, bool forceGender = false);
    bool HasCharacterFacialHairStyle(uint8 race, uint8 gender, uint8 variationId) const;
    bool HasCharSections(uint8 race, uint8 gender, CharBaseSectionVariation variation) const;
    CharSectionsEntry const* GetCharSectionEntry(uint8 race, uint8 gender, CharBaseSectionVariation variation, uint8 variationIndex, uint8 color) const;
    CharStartOutfitEntry const* GetCharStartOutfitEntry(uint8 race, uint8 class_, uint8 gender) const;
    static char const* GetClassName(uint8 class_, LocaleConstant locale = DEFAULT_LOCALE);
    uint32 GetPowerIndexByClass(Powers power, uint32 classId) const;
    static char const* GetChrRaceName(uint8 race, LocaleConstant locale = DEFAULT_LOCALE);
    ChrSpecializationEntry const* GetChrSpecializationByIndex(uint32 class_, uint32 index) const;
    ChrSpecializationEntry const* GetDefaultChrSpecializationForClass(uint32 class_) const;
    static char const* GetCreatureFamilyPetName(uint32 petfamily, uint32 locale);
    float GetCurveValueAt(uint32 curveId, float x) const;
    EmotesTextSoundEntry const* GetTextSoundEmoteFor(uint32 emote, uint8 race, uint8 gender, uint8 class_) const;
    std::vector<uint32> const* GetFactionTeamList(uint32 faction) const;
    HeirloomEntry const* GetHeirloomByItemId(uint32 itemId) const;
    std::vector<uint32> const* GetGlyphBindableSpells(uint32 glyphPropertiesId) const;
    std::vector<uint32> const* GetGlyphRequiredSpecs(uint32 glyphPropertiesId) const;
    ItemBonusList const* GetItemBonusList(uint32 bonusListId) const;
    uint32 GetItemBonusListForItemLevelDelta(int16 delta) const;
    std::set<uint32> GetItemBonusTree(uint32 itemId, uint32 itemContext) const;
    std::vector<int32> GetItemBonusTreeVector(uint32 itemId, uint32 itemContext) const;
    ItemChildEquipmentEntry const* GetItemChildEquipment(uint32 itemId) const;
    ItemClassEntry const* GetItemClassByOldEnum(uint32 itemClass) const;
    bool HasItemCurrencyCost(uint32 itemId) const;
    std::vector<ItemLimitCategoryConditionEntry const*> const* GetItemLimitCategoryConditions(uint32 categoryId) const;
    uint32 GetItemDisplayId(uint32 itemId, uint32 appearanceModId) const;
    ItemModifiedAppearanceEntry const* GetItemModifiedAppearance(uint32 itemId, uint32 appearanceModId) const;
    ItemModifiedAppearanceEntry const* GetDefaultItemModifiedAppearance(uint32 itemId) const;
    std::vector<ItemSetSpellEntry const*> const* GetItemSetSpells(uint32 itemSetId) const;
    std::vector<ItemSpecOverrideEntry const*> const* GetItemSpecOverrides(uint32 itemId) const;
    static LFGDungeonsEntry const* GetLfgDungeon(uint32 mapId, Difficulty difficulty);
    static uint32 GetDefaultMapLight(uint32 mapId);
    static uint32 GetLiquidFlags(uint32 liquidType);
    MapDifficultyContainer const& GetMapDifficulties() const;
    MapDifficultyEntry const* GetDefaultMapDifficulty(uint32 mapId, Difficulty* difficulty = nullptr) const;
    MapDifficultyEntry const* GetMapDifficultyData(uint32 mapId, Difficulty difficulty) const;
    MapDifficultyEntry const* GetDownscaledMapDifficultyData(uint32 mapId, Difficulty &difficulty) const;
    std::string GetNameGenEntry(uint8 race, uint8 gender) const;
    MountEntry const* GetMount(uint32 spellId) const;
    MountEntry const* GetMountById(uint32 id) const;
    MountTypeXCapabilitySet const* GetMountCapabilities(uint32 mountType) const;
    MountXDisplayContainer const* GetMountDisplays(uint32 mountId) const;
    ResponseCodes ValidateName(std::wstring const& name, LocaleConstant locale) const;
    std::vector<uint32> const* GetPhasesForGroup(uint32 group) const;
    PowerTypeEntry const* GetPowerTypeEntry(Powers power) const;
    PowerTypeEntry const* GetPowerTypeByName(std::string const& name) const;
    uint8 GetPvpItemLevelBonus(uint32 itemId) const;
    uint8 GetMaxPrestige() const;
    static PVPDifficultyEntry const* GetBattlegroundBracketByLevel(uint32 mapid, uint32 level);
    static PVPDifficultyEntry const* GetBattlegroundBracketById(uint32 mapid, BattlegroundBracketId id);
    uint32 GetRewardPackIDForPvpRewardByHonorLevelAndPrestige(uint8 honorLevel, uint8 prestige) const;
    uint32 GetRequiredHonorLevelForPvpTalent(PvpTalentEntry const* talentInfo) const;
    std::vector<PvpTalentEntry const*> const& GetPvpTalentsByPosition(uint32 class_, uint32 tier, uint32 column) const;
    std::vector<QuestPackageItemEntry const*> const* GetQuestPackageItems(uint32 questPackageID) const;
    std::vector<QuestPackageItemEntry const*> const* GetQuestPackageItemsFallback(uint32 questPackageID) const;
    uint32 GetQuestUniqueBitFlag(uint32 questId);
    std::vector<RewardPackXCurrencyTypeEntry const*> const* GetRewardPackCurrencyTypesByRewardID(uint32 rewardPackID) const;
    std::vector<RewardPackXItemEntry const*> const* GetRewardPackItemsByRewardID(uint32 rewardPackID) const;
    uint32 GetRulesetItemUpgrade(uint32 itemId) const;
    SkillRaceClassInfoEntry const* GetSkillRaceClassInfo(uint32 skill, uint8 race, uint8 class_);
    std::vector<SpecializationSpellsEntry const*> const* GetSpecializationSpells(uint32 specId) const;
    static bool IsValidSpellFamiliyName(SpellFamilyNames family);
    std::vector<SpellPowerEntry const*> GetSpellPowers(uint32 spellId, Difficulty difficulty = DIFFICULTY_NONE, bool* hasDifficultyPowers = nullptr) const;
    std::vector<SpellProcsPerMinuteModEntry const*> GetSpellProcsPerMinuteMods(uint32 spellprocsPerMinuteId) const;
    std::vector<TalentEntry const*> const& GetTalentsByPosition(uint32 class_, uint32 tier, uint32 column) const;
    static bool IsTotemCategoryCompatibleWith(uint32 itemTotemCategoryId, uint32 requiredTotemCategoryId);
    bool IsToyItem(uint32 toy) const;
    std::vector<TransmogSetEntry const*> const* GetTransmogSetsForItemModifiedAppearance(uint32 itemModifiedAppearanceId) const;
    std::vector<TransmogSetItemEntry const*> const* GetTransmogSetItems(uint32 transmogSetId) const;
    WMOAreaTableEntry const* GetWMOAreaTable(int32 rootId, int32 adtId, int32 groupId) const;
    uint32 GetVirtualMapForMapAndZone(uint32 mapId, uint32 zoneId) const;
    void Zone2MapCoordinates(uint32 areaId, float& x, float& y) const;
    void Map2ZoneCoordinates(uint32 areaId, float& x, float& y) const;
    static void DeterminaAlternateMapPosition(uint32 mapId, float x, float y, float z, uint32* newMapId = nullptr, DBCPosition2D* newPos = nullptr);

private:
    friend class DB2HotfixGeneratorBase;
    void InsertNewHotfix(uint32 tableHash, uint32 recordId);
    uint32 _maxHotfixId = 0;
};

#define sDB2Manager DB2Manager::Instance()

#endif

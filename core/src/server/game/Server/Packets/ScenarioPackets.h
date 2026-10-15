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

#ifndef ScenarioPackets_h__
#define ScenarioPackets_h__

#include "Packet.h"
#include "PacketUtilities.h"
#include "AchievementPackets.h"

// [LEGIONFORGE FIX #1 - CRASH 2026-10-12] DB2 build 26124 contains scenario
// criteria trees up to 41 nodes deep (log: "must be at least 42"), while the
// old limit was 40 -> ScenarioMgr::LoadDB2Data hit ASSERT and worldserver
// crashed before finishing startup ("Loading scenarios"). Raised to 128:
// the array is a bounded static_vector used only for CMSG_QUERY_SCENARIO_POI,
// so a larger cap costs a few hundred bytes per query packet, rejects nothing
// the 7.3.5 client can legitimately send, and leaves headroom for future
// DB2 updates. See also the graceful check in ScenarioMgr::LoadDB2Data.
#define MAX_ALLOWED_SCENARIO_POI_QUERY_SIZE 128

struct ScenarioPOI;

namespace WorldPackets
{
    namespace Scenario
    {
        struct BonusObjectiveData
        {
            int32 BonusObjectiveID = 0;
            bool ObjectiveComplete = false;
        };

        struct ScenarioSpellUpdate
        {
            uint32 SpellID = 0;
            bool Usable = true;
        };

        class ScenarioState final : public ServerPacket
        {
        public:
            ScenarioState() : ServerPacket(SMSG_SCENARIO_STATE) { }

            WorldPacket const* Write() override;

            int32 ScenarioID = 0;
            int32 CurrentStep = -1;
            uint32 DifficultyID = 0;
            uint32 WaveCurrent = 0;
            uint32 WaveMax = 0;
            uint32 TimerDuration = 0;
            std::vector<WorldPackets::Achievement::CriteriaProgress> CriteriaProgress;
            std::vector<BonusObjectiveData> BonusObjectives;
            std::vector<uint32> PickedSteps;
            std::vector<ScenarioSpellUpdate> Spells;
            bool ScenarioComplete = false;
        };

        class ScenarioProgressUpdate final : public ServerPacket
        {
        public:
            ScenarioProgressUpdate() : ServerPacket(SMSG_SCENARIO_PROGRESS_UPDATE) { }

            WorldPacket const* Write() override;

            WorldPackets::Achievement::CriteriaProgress CriteriaProgress;
        };

        class ScenarioCompleted final : public ServerPacket
        {
        public:
            ScenarioCompleted(uint32 scenarioId) : ServerPacket(SMSG_SCENARIO_COMPLETED, 4), ScenarioID(scenarioId) { }

            WorldPacket const* Write() override;

            uint32 ScenarioID = 0;
        };

        class ScenarioBoot final : public ServerPacket
        {
        public:
            ScenarioBoot() : ServerPacket(SMSG_SCENARIO_BOOT, 4 + 4 + 1) { }

            WorldPacket const* Write() override;

            int32 ScenarioID = 0;
            int32 Unk1 = 0;
            uint8 Unk2 = 0;
        };

        class QueryScenarioPOI final : public ClientPacket
        {
        public:
            QueryScenarioPOI(WorldPacket&& packet) : ClientPacket(CMSG_QUERY_SCENARIO_POI, std::move(packet)) { }

            void Read() override;

            Array<int32, MAX_ALLOWED_SCENARIO_POI_QUERY_SIZE> MissingScenarioPOIs;
        };

        struct ScenarioPOIData
        {
            int32 CriteriaTreeID = 0;
            std::vector<ScenarioPOI> const* ScenarioPOIs = nullptr;
        };

        class ScenarioPOIs final : public ServerPacket
        {
        public:
            ScenarioPOIs() : ServerPacket(SMSG_SCENARIO_POIS) { }

            WorldPacket const* Write() override;

            std::vector<ScenarioPOIData> ScenarioPOIDataStats;
        };
    }
}

#endif // ScenarioPackets_h__

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

#include "ScenarioMgr.h"
#include "DatabaseEnv.h"
#include "DB2Stores.h"
#include "InstanceScenario.h"
#include "Log.h"
#include "Map.h"
#include "ScenarioPackets.h"

ScenarioMgr* ScenarioMgr::Instance()
{
    static ScenarioMgr instance;
    return &instance;
}

InstanceScenario* ScenarioMgr::CreateInstanceScenario(Map const* map, TeamId team) const
{
    auto dbDataItr = _scenarioDBData.find(std::make_pair(map->GetId(), map->GetDifficultyID()));
    // No scenario registered for this map and difficulty in the database
    if (dbDataItr == _scenarioDBData.end())
        return nullptr;

    uint32 scenarioID = 0;
    switch (team)
    {
        case TEAM_ALLIANCE:
            scenarioID = dbDataItr->second.Scenario_A;
            break;
        case TEAM_HORDE:
            scenarioID = dbDataItr->second.Scenario_H;
            break;
        default:
            break;
    }

    auto itr = _scenarioData.find(scenarioID);
    if (itr == _scenarioData.end())
    {
        LF_LOG_ERROR("scenario", "Table `scenarios` contained data linking scenario (Id: %u) to map (Id: %u), difficulty (Id: %u) but no scenario data was found related to that scenario Id.", scenarioID, map->GetId(), map->GetDifficultyID());
        return nullptr;
    }

    return new InstanceScenario(map, &itr->second);
}

void ScenarioMgr::LoadDBData()
{
    _scenarioDBData.clear();

    uint32 oldMSTime = getMSTime();

    QueryResult result = WorldDatabase.Query("SELECT map, difficulty, scenario_A, scenario_H FROM scenarios");

    if (!result)
    {
        LF_LOG_INFO("server.loading", ">> Loaded 0 scenarios. DB table `scenarios` is empty!");
        return;
    }

    do
    {
        Field* fields = result->Fetch();

        uint32 mapId = fields[0].GetUInt32();
        uint8 difficulty = fields[1].GetUInt8();

        uint32 scenarioAllianceId = fields[2].GetUInt32();
        if (scenarioAllianceId > 0 && _scenarioData.find(scenarioAllianceId) == _scenarioData.end())
        {
            LF_LOG_ERROR("sql.sql", "ScenarioMgr::LoadDBData: DB Table `scenarios`, column scenario_A contained an invalid scenario (Id: %u)!", scenarioAllianceId);
            continue;
        }

        uint32 scenarioHordeId = fields[3].GetUInt32();
        if (scenarioHordeId > 0 && _scenarioData.find(scenarioHordeId) == _scenarioData.end())
        {
            LF_LOG_ERROR("sql.sql", "ScenarioMgr::LoadDBData: DB Table `scenarios`, column scenario_H contained an invalid scenario (Id: %u)!", scenarioHordeId);
            continue;
        }

        if (scenarioHordeId == 0)
            scenarioHordeId = scenarioAllianceId;

        ScenarioDBData& data = _scenarioDBData[std::make_pair(mapId, difficulty)];
        data.MapID = mapId;
        data.DifficultyID = difficulty;
        data.Scenario_A = scenarioAllianceId;
        data.Scenario_H = scenarioHordeId;
    }
    while (result->NextRow());

    LF_LOG_INFO("server.loading", ">> Loaded " SZFMTD " instance scenario entries in %u ms", _scenarioDBData.size(), GetMSTimeDiffToNow(oldMSTime));
}

void ScenarioMgr::LoadDB2Data()
{
    _scenarioData.clear();

    std::unordered_map<uint32, std::map<uint8, ScenarioStepEntry const*>> scenarioSteps;
    uint32 deepestCriteriaTreeSize = 0;

    for (ScenarioStepEntry const* step : sScenarioStepStore)
    {
        scenarioSteps[step->ScenarioID][step->OrderIndex] = step;
        if (CriteriaTree const* tree = sCriteriaMgr->GetCriteriaTree(step->Criteriatreeid))
        {
            uint32 criteriaTreeSize = 0;
            CriteriaMgr::WalkCriteriaTree(tree, [&criteriaTreeSize](CriteriaTree const* /*tree*/)
            {
                ++criteriaTreeSize;
            });
            deepestCriteriaTreeSize = std::max(deepestCriteriaTreeSize, criteriaTreeSize);
        }
    }

    // [LEGIONFORGE FIX #1 - CRASH 2026-10-12] This used to be an ASSERT.
    // deepestCriteriaTreeSize comes from external DB2 data (client build),
    // not from core invariants: a newer/larger DB2 must never be able to
    // terminate worldserver during startup. Log an error and continue -
    // scenario POI queries for oversized trees are rejected per-packet by
    // WorldPackets::Array (PacketArrayMaxCapacityException) instead of
    // crashing the whole server. Raise MAX_ALLOWED_SCENARIO_POI_QUERY_SIZE
    // in ScenarioPackets.h if this error ever appears.
    if (deepestCriteriaTreeSize >= MAX_ALLOWED_SCENARIO_POI_QUERY_SIZE)
        LF_LOG_ERROR("scenario", "ScenarioMgr::LoadDB2Data: deepest scenario criteria tree has %u nodes, but MAX_ALLOWED_SCENARIO_POI_QUERY_SIZE is %u. "
            "POI queries for the deepest scenario trees will be rejected. Raise MAX_ALLOWED_SCENARIO_POI_QUERY_SIZE to at least %u.",
            deepestCriteriaTreeSize, uint32(MAX_ALLOWED_SCENARIO_POI_QUERY_SIZE), deepestCriteriaTreeSize + 1);

    for (ScenarioEntry const* scenario : sScenarioStore)
    {
        ScenarioData& data = _scenarioData[scenario->ID];
        data.Entry = scenario;
        data.Steps = std::move(scenarioSteps[scenario->ID]);
    }
}

void ScenarioMgr::LoadScenarioPOI()
{
    uint32 oldMSTime = getMSTime();

    _scenarioPOIStore.clear(); // need for reload case

    uint32 count = 0;
    uint32 invalidPoints = 0;
    uint32 invalidDefinitions = 0;
    constexpr uint32 MaxLoggedInvalidPOIs = 20;

    QueryResult result = WorldDatabase.Query("SELECT CriteriaTreeID, BlobIndex, Idx1, MapID, WorldMapAreaId, Floor, Priority, Flags, WorldEffectID, PlayerConditionID FROM scenario_poi ORDER BY CriteriaTreeID, Idx1");
    if (!result)
    {
        LF_LOG_ERROR("server.loading", ">> Loaded 0 scenario POI definitions. DB table `scenario_poi` is empty.");
        return;
    }

    QueryResult points = WorldDatabase.Query("SELECT CriteriaTreeID, Idx1, X, Y FROM scenario_poi_points ORDER BY CriteriaTreeID DESC, Idx1, Idx2");

    // IDs in SQL need not be dense or positive. Allocate only for valid point rows,
    // rather than resizing a vector to an untrusted CriteriaTreeID or Idx1.
    std::map<std::pair<int32, int32>, std::vector<ScenarioPOIPoint>> poiPoints;
    if (points)
    {
        do
        {
            Field* fields = points->Fetch();
            int32 criteriaTreeId = fields[0].GetInt32();
            int32 index = fields[1].GetInt32();
            if (criteriaTreeId < 0 || index < 0 || !sCriteriaMgr->GetCriteriaTree(uint32(criteriaTreeId)))
            {
                if (invalidPoints++ < MaxLoggedInvalidPOIs)
                    LF_LOG_ERROR("sql.sql", "Invalid scenario_poi_points row: CriteriaTreeID %i, Idx1 %i; skipped.", criteriaTreeId, index);
                continue;
            }

            poiPoints[std::make_pair(criteriaTreeId, index)].emplace_back(fields[2].GetInt32(), fields[3].GetInt32());
        } while (points->NextRow());
    }

    do
    {
        Field* fields = result->Fetch();

        int32 criteriaTreeId = fields[0].GetInt32();
        int32 blobIndex = fields[1].GetInt32();
        int32 index = fields[2].GetInt32();
        int32 mapId = fields[3].GetInt32();
        int32 worldMapAreaId = fields[4].GetInt32();
        int32 floor = fields[5].GetInt32();
        int32 priority = fields[6].GetInt32();
        int32 flags = fields[7].GetInt32();
        int32 worldEffectId = fields[8].GetInt32();
        int32 playerConditionId = fields[9].GetInt32();

        if (criteriaTreeId < 0 || index < 0 || !sCriteriaMgr->GetCriteriaTree(uint32(criteriaTreeId)))
        {
            if (invalidDefinitions++ < MaxLoggedInvalidPOIs)
                LF_LOG_ERROR("sql.sql", "Invalid scenario_poi row: CriteriaTreeID %i, Idx1 %i; skipped.", criteriaTreeId, index);
            continue;
        }

        auto poi = poiPoints.find(std::make_pair(criteriaTreeId, index));
        if (poi == poiPoints.end())
        {
            if (invalidDefinitions++ < MaxLoggedInvalidPOIs)
                LF_LOG_ERROR("sql.sql", "scenario_poi references missing points: CriteriaTreeID %i, BlobIndex %i, Idx1 %i; skipped.", criteriaTreeId, blobIndex, index);
            continue;
        }

        _scenarioPOIStore[criteriaTreeId].emplace_back(blobIndex, mapId, worldMapAreaId, floor, priority, flags, worldEffectId, playerConditionId, poi->second);
        ++count;
    } while (result->NextRow());

    if (invalidPoints || invalidDefinitions)
        LF_LOG_ERROR("server.loading", "Skipped %u invalid scenario POI points and %u definitions (first %u of each logged). Check world SQL and client DB2.",
            invalidPoints, invalidDefinitions, MaxLoggedInvalidPOIs);

    LF_LOG_INFO("server.loading", ">> Loaded %u scenario POI definitions in %u ms", count, GetMSTimeDiffToNow(oldMSTime));
}

ScenarioPOIVector const* ScenarioMgr::GetScenarioPOIs(int32 criteriaTreeID) const
{
    auto itr = _scenarioPOIStore.find(criteriaTreeID);
    if (itr != _scenarioPOIStore.end())
        return &itr->second;

    return nullptr;
}

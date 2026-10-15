/*
 * Copyright (C) 2008-2018 LEGIONFORGE <https://www.legionforge.ru/>
 * Copyright (C) 2005-2009 MaNGOS <http://getmangos.com/>
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

#ifndef LEGIONFORGE_GRIDNOTIFIERSIMPL_H
#define LEGIONFORGE_GRIDNOTIFIERSIMPL_H

#include "GridNotifiers.h"
#include "Corpse.h"
#include "CreatureAI.h"
#include "Player.h"
#include "SpellAuras.h"
#include "UpdateData.h"
#include "WorldPacket.h"
#include "WorldSession.h"

template<class T>
inline void LegionForge::VisibleNotifier::Visit(GridRefManager<T> &m)
{
    for (typename GridRefManager<T>::iterator iter = m.begin(); iter != m.end(); ++iter)
    {
        vis_guids.erase(iter->GetSource()->GetGUID());
        i_player.UpdateVisibilityOf(iter->GetSource(), i_data, i_visibleNow);
    }
}

// SEARCHERS & LIST SEARCHERS & WORKERS

// WorldObject searchers & workers

template<class Check>
void LegionForge::WorldObjectSearcher<Check>::Visit(GameObjectMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_GAMEOBJECT))
        return;

    // already found
    if (i_object)
        return;

    for (GameObjectMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::WorldObjectSearcher<Check>::Visit(PlayerMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_PLAYER))
        return;

    // already found
    if (i_object)
        return;

    for (PlayerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::WorldObjectSearcher<Check>::Visit(CreatureMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_CREATURE))
        return;

    // already found
    if (i_object)
        return;

    for (CreatureMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::WorldObjectSearcher<Check>::Visit(CorpseMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_CORPSE))
        return;

    // already found
    if (i_object)
        return;

    for (CorpseMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::WorldObjectSearcher<Check>::Visit(DynamicObjectMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_DYNAMICOBJECT))
        return;

    // already found
    if (i_object)
        return;

    for (DynamicObjectMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::WorldObjectSearcher<Check>::Visit(AreaTriggerMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_AREATRIGGER))
        return;

    // already found
    if (i_object)
        return;

    for (AreaTriggerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::WorldObjectSearcher<Check>::Visit(SceneObjectMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_SCENEOBJECT))
        return;

    // already found
    if (i_object)
        return;

    for (SceneObjectMapType::iterator itr = m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::WorldObjectSearcher<Check>::Visit(ConversationMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_CONVERSATION))
        return;

    // already found
    if (i_object)
        return;

    for (ConversationMapType::iterator itr = m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::WorldObjectLastSearcher<Check>::Visit(GameObjectMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_GAMEOBJECT))
        return;

    for (GameObjectMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::WorldObjectLastSearcher<Check>::Visit(PlayerMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_PLAYER))
        return;

    for (PlayerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::WorldObjectLastSearcher<Check>::Visit(CreatureMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_CREATURE))
        return;

    for (CreatureMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::WorldObjectLastSearcher<Check>::Visit(CorpseMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_CORPSE))
        return;

    for (CorpseMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::WorldObjectLastSearcher<Check>::Visit(DynamicObjectMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_DYNAMICOBJECT))
        return;

    for (DynamicObjectMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::WorldObjectLastSearcher<Check>::Visit(AreaTriggerMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_AREATRIGGER))
        return;

    for (AreaTriggerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::WorldObjectLastSearcher<Check>::Visit(SceneObjectMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_SCENEOBJECT))
        return;

    for (SceneObjectMapType::iterator itr = m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::WorldObjectLastSearcher<Check>::Visit(ConversationMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_CONVERSATION))
        return;

    for (ConversationMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::WorldObjectListSearcher<Check>::Visit(PlayerMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_PLAYER))
        return;

    for (PlayerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (i_check(itr->GetSource()))
            Insert(itr->GetSource());
}

template<class Check>
void LegionForge::WorldObjectListSearcher<Check>::Visit(CreatureMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_CREATURE))
        return;

    for (CreatureMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (i_check(itr->GetSource()))
            Insert(itr->GetSource());
}

template<class Check>
void LegionForge::WorldObjectListSearcher<Check>::Visit(CorpseMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_CORPSE))
        return;

    for (CorpseMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (i_check(itr->GetSource()))
            Insert(itr->GetSource());
}

template<class Check>
void LegionForge::WorldObjectListSearcher<Check>::Visit(GameObjectMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_GAMEOBJECT))
        return;

    for (GameObjectMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (i_check(itr->GetSource()))
            Insert(itr->GetSource());
}

template<class Check>
void LegionForge::WorldObjectListSearcher<Check>::Visit(DynamicObjectMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_DYNAMICOBJECT))
        return;

    for (DynamicObjectMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (i_check(itr->GetSource()))
            Insert(itr->GetSource());
}

template<class Check>
void LegionForge::WorldObjectListSearcher<Check>::Visit(AreaTriggerMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_AREATRIGGER))
        return;

    for (AreaTriggerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (i_check(itr->GetSource()))
            Insert(itr->GetSource());
}

template<class Check>
void LegionForge::WorldObjectListSearcher<Check>::Visit(SceneObjectMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_SCENEOBJECT))
        return;

    for (SceneObjectMapType::iterator itr = m.begin(); itr != m.end(); ++itr)
        if (i_check(itr->GetSource()))
            Insert(itr->GetSource());
}

template<class Check>
void LegionForge::WorldObjectListSearcher<Check>::Visit(ConversationMapType &m)
{
    if (!(i_mapTypeMask & GRID_MAP_TYPE_MASK_CONVERSATION))
        return;

    for (ConversationMapType::iterator itr = m.begin(); itr != m.end(); ++itr)
        if (i_check(itr->GetSource()))
            Insert(itr->GetSource());
}

// Gameobject searchers

template<class Check>
void LegionForge::GameObjectSearcher<Check>::Visit(GameObjectMapType &m)
{
    // already found
    if (i_object)
        return;

    for (GameObjectMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::GameObjectLastSearcher<Check>::Visit(GameObjectMapType &m)
{
    for (GameObjectMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::GameObjectListSearcher<Check>::Visit(GameObjectMapType &m)
{
    for (GameObjectMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (itr->GetSource()->IsInPhase(_searcher))
            if (i_check(itr->GetSource()))
                Insert(itr->GetSource());
}

// Unit searchers

template<class Check>
void LegionForge::UnitSearcher<Check>::Visit(CreatureMapType &m)
{
    // already found
    if (i_object)
        return;

    for (CreatureMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::UnitSearcher<Check>::Visit(PlayerMapType &m)
{
    // already found
    if (i_object)
        return;

    for (PlayerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::UnitLastSearcher<Check>::Visit(CreatureMapType &m)
{
    for (CreatureMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::UnitLastSearcher<Check>::Visit(PlayerMapType &m)
{
    for (PlayerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::UnitListSearcher<Check>::Visit(PlayerMapType &m)
{
    for (PlayerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (itr->GetSource()->IsInPhase(_searcher))
            if (i_check(itr->GetSource()))
                Insert(itr->GetSource());
}

template<class Check>
void LegionForge::UnitListSearcher<Check>::Visit(CreatureMapType &m)
{
    for (CreatureMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (itr->GetSource()->IsInPhase(_searcher))
            if (i_check(itr->GetSource()))
                Insert(itr->GetSource());
}

// Creature searchers

template<class Check>
void LegionForge::CreatureSearcher<Check>::Visit(CreatureMapType &m)
{
    // already found
    if (i_object)
        return;

    for (CreatureMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::CreatureLastSearcher<Check>::Visit(CreatureMapType &m)
{
    for (CreatureMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::CreatureListSearcher<Check>::Visit(CreatureMapType &m)
{
    for (CreatureMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (itr->GetSource()->IsInPhase(_searcher))
            if (i_check(itr->GetSource()))
                Insert(itr->GetSource());
}

template<class Check>
void LegionForge::PlayerListSearcher<Check>::Visit(PlayerMapType &m)
{
    for (PlayerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
        if (itr->GetSource()->IsInPhase(_searcher))
            if (i_check(itr->GetSource()))
                Insert(itr->GetSource());
}

template<class Check>
void LegionForge::PlayerSearcher<Check>::Visit(PlayerMapType &m)
{
    // already found
    if (i_object)
        return;

    for (PlayerMapType::iterator itr=m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::PlayerLastSearcher<Check>::Visit(PlayerMapType& m)
{
    for (PlayerMapType::iterator itr = m.begin(); itr != m.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(_searcher))
            continue;

        if (i_check(itr->GetSource()))
            i_object = itr->GetSource();
    }
}

template<class Check>
void LegionForge::AreaTriggerListSearcher<Check>::Visit(AreaTriggerMapType& p_AreaTriggerMap)
{
    for (AreaTriggerMapType::iterator itr = p_AreaTriggerMap.begin(); itr != p_AreaTriggerMap.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(i_searcher))
            continue;

        if (i_check(itr->GetSource()))
            m_AreaTriggers.push_back(itr->GetSource());
    }
}

template<class Check>
void LegionForge::AreaTriggerSearcher<Check>::Visit(AreaTriggerMapType& p_AreaTriggerMap)
{
    for (AreaTriggerMapType::iterator itr = p_AreaTriggerMap.begin(); itr != p_AreaTriggerMap.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(i_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::SceneObjectVectorSearcher<Check>::Visit(SceneObjectMapType& p_SceneObjectMap)
{
    for (SceneObjectMapType::iterator itr = p_SceneObjectMap.begin(); itr != p_SceneObjectMap.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(i_searcher))
            continue;

        if (i_check(itr->GetSource()))
            m_SceneObjects.push_back(itr->GetSource());
    }
}

template<class Check>
void LegionForge::SceneObjectSearcher<Check>::Visit(SceneObjectMapType& p_SceneObjectMap)
{
    for (SceneObjectMapType::iterator itr = p_SceneObjectMap.begin(); itr != p_SceneObjectMap.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(i_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Check>
void LegionForge::ConversationVectorSearcher<Check>::Visit(ConversationMapType& p_ConversationMap)
{
    for (ConversationMapType::iterator itr = p_ConversationMap.begin(); itr != p_ConversationMap.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(i_searcher))
            continue;

        if (i_check(itr->GetSource()))
            m_Conversations.push_back(itr->GetSource());
    }
}

template<class Check>
void LegionForge::ConversationSearcher<Check>::Visit(ConversationMapType& p_ConversationMap)
{
    for (ConversationMapType::iterator itr = p_ConversationMap.begin(); itr != p_ConversationMap.end(); ++itr)
    {
        if (!itr->GetSource()->IsInPhase(i_searcher))
            continue;

        if (i_check(itr->GetSource()))
        {
            i_object = itr->GetSource();
            return;
        }
    }
}

template<class Builder>
void LegionForge::LocalizedPacketDo<Builder>::operator()(Player* p)
{
    LocaleConstant loc_idx = p->GetSession()->GetSessionDbLocaleIndex();
    uint32 cache_idx = loc_idx+1;
    WorldPackets::Packet* data;

    // create if not cached yet
    if (i_data_cache.size() < cache_idx + 1 || !i_data_cache[cache_idx])
    {
        if (i_data_cache.size() < cache_idx + 1)
            i_data_cache.resize(cache_idx + 1);

        data = i_builder(loc_idx);

        ASSERT(data->GetSize() == 0);

        data->Write();

        i_data_cache[cache_idx] = data;
    }
    else
        data = i_data_cache[cache_idx];

    p->SendDirectMessage(data->GetRawPacket());
}

template<class Builder>
void LegionForge::LocalizedPacketListDo<Builder>::operator()(Player* p)
{
    LocaleConstant loc_idx = p->GetSession()->GetSessionDbLocaleIndex();
    uint32 cache_idx = loc_idx+1;
    WorldPacketList* data_list;

    // create if not cached yet
    if (i_data_cache.size() < cache_idx+1 || i_data_cache[cache_idx].empty())
    {
        if (i_data_cache.size() < cache_idx+1)
            i_data_cache.resize(cache_idx+1);

        data_list = &i_data_cache[cache_idx];

        i_builder(*data_list, loc_idx);
    }
    else
        data_list = &i_data_cache[cache_idx];

    for (size_t i = 0; i < data_list->size(); ++i)
        p->SendDirectMessage((*data_list)[i]->GetRawPacket());
}

#endif                                                      // LEGIONFORGE_GRIDNOTIFIERSIMPL_H

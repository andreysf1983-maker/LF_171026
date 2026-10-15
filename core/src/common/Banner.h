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

#ifndef LEGIONFORGE_Banner_h__
#define LEGIONFORGE_Banner_h__

#include "Define.h"

namespace LegionForge
{
    namespace Banner
    {
        LF_COMMON_API void Show(char const* applicationName, void(*log)(char const* text), void(*logExtraInfo)());
    }
}

#endif // LEGIONFORGE_Banner_h__

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

#include "Banner.h"
#include "GitRevision.h"
#include "StringFormat.h"

void LegionForge::Banner::Show(char const* applicationName, void(*log)(char const* text), void(*logExtraInfo)())
{
    log(LegionForge::StringFormat("%s (%s)", GitRevision::GetFullVersion(), applicationName).c_str());
    log("<Ctrl-C> to stop.\n");
    log(" __                                         ____");
    log("/\\ \\                     __                /\\  _`\\");
    log("\\ \\ \\         __     __ /\\_\\    ___     ___\\ \\ \\L\\_\\___   _ __    __      __");
    log(" \\ \\ \\  __  /'__`\\ /'_ `\\/\\ \\  / __`\\ /' _ `\\ \\  _\\/ __`\\/\\`'__\\/'_ `\\  /'__`\\");
    log("  \\ \\ \\L\\ \\/\\  __//\\ \\L\\ \\ \\ \\/\\ \\L\\ \\/\\ \\/\\ \\ \\ \\/\\ \\L\\ \\ \\ \\//\\ \\L\\ \\/\\  __/");
    log("   \\ \\____/\\ \\____\\ \\____ \\ \\_\\ \\____/\\ \\_\\ \\_\\ \\_\\ \\____/\\ \\_\\\\ \\____ \\ \\____\\");
    log("    \\/___/  \\/____/\\/___L\\ \\/_/\\/___/  \\/_/\\/_/\\/_/\\/___/  \\/_/ \\/___L\\ \\/____/");
    log("                     /\\____/                                      /\\____/");
    log("                     \\_/__/                                       \\_/__/");
    log("");
    log("                 L E G I O N   7 . 3 . 5   ( b u i l d   2 6 1 2 4 )");
    log("                                                     https://legionforge.ru\n");

    if (logExtraInfo)
        logExtraInfo();
}

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

#ifndef _AUTH_SARC4_H
#define _AUTH_SARC4_H

#include "Define.h"

// Native RC4 (ARC4) implementation — no OpenSSL EVP dependency.
// Required because OpenSSL 3.x moved RC4 to the legacy provider and
// EVP_rc4() returns NULL without it, causing a null-deref crash.
class LF_COMMON_API ARC4
{
    public:
        ARC4(uint32 len);
        ARC4(uint8* seed, uint32 len);
        ~ARC4() = default;
        void Init(uint8* seed);
        void UpdateData(int len, uint8* data);
    private:
        void KSA(uint8* key, uint32 keylen);

        uint8  m_S[256];
        uint32 m_keylen;
        int    m_i;
        int    m_j;
        bool   m_initialized;
};

#endif

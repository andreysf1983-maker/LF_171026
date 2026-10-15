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

// Native RC4 implementation replacing the OpenSSL EVP-based one.
// OpenSSL 3.x moved RC4 to the legacy provider; EVP_rc4() returns NULL
// without it, causing EVP_CIPHER_CTX_set_key_length to crash on a null ctx->cipher.

#include "ARC4.h"
#include <cstring>

// ARC4(uint32 len) — stores key length; state uninitialised until Init() is called.
ARC4::ARC4(uint32 len) : m_keylen(len), m_i(0), m_j(0), m_initialized(false)
{
    std::memset(m_S, 0, sizeof(m_S));
}

// ARC4(uint8* seed, uint32 len) — initialises state immediately with provided seed.
ARC4::ARC4(uint8* seed, uint32 len) : m_keylen(len), m_i(0), m_j(0), m_initialized(false)
{
    std::memset(m_S, 0, sizeof(m_S));
    KSA(seed, len);
}

// Re-initialise the RC4 state with a new seed (same key length as constructed with).
void ARC4::Init(uint8* seed)
{
    KSA(seed, m_keylen);
}

// Key Scheduling Algorithm (KSA).
void ARC4::KSA(uint8* key, uint32 keylen)
{
    for (int idx = 0; idx < 256; ++idx)
        m_S[idx] = static_cast<uint8>(idx);

    int j = 0;
    for (int idx = 0; idx < 256; ++idx)
    {
        j = (j + m_S[idx] + key[idx % keylen]) & 0xFF;
        uint8 tmp  = m_S[idx];
        m_S[idx]   = m_S[j];
        m_S[j]     = tmp;
    }

    m_i = 0;
    m_j = 0;
    m_initialized = true;
}

// Pseudo-Random Generation Algorithm (PRGA) — encrypt/decrypt in-place.
void ARC4::UpdateData(int len, uint8* data)
{
    for (int k = 0; k < len; ++k)
    {
        m_i = (m_i + 1)         & 0xFF;
        m_j = (m_j + m_S[m_i])  & 0xFF;

        uint8 tmp   = m_S[m_i];
        m_S[m_i]    = m_S[m_j];
        m_S[m_j]    = tmp;

        data[k] ^= m_S[(m_S[m_i] + m_S[m_j]) & 0xFF];
    }
}


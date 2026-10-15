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

#ifndef AsioHacksFwd_h__
#define AsioHacksFwd_h__

#include <boost/version.hpp>

/**
  Collection of forward declarations to improve compile time.
  For Boost >= 1.66, include actual headers to avoid template mismatch with new API.
 */
#if BOOST_VERSION >= 106600

// Include full headers - forward declarations no longer match Boost 1.66+ API
#include <boost/asio/io_context.hpp>
#include <boost/asio/steady_timer.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ip/basic_resolver.hpp>

// LEGIONFORGE audit fix:
//  * The core uses boost::asio::steady_timer directly (expires_after + std::chrono).
//    The former alias "using deadline_timer = steady_timer;" conflicted with the
//    real boost::asio::deadline_timer typedef (still present in Boost 1.66 ... 1.9x,
//    pulled in by <boost/asio.hpp>) and broke compilation of TCRest/server_http.h.
//  * io_service was removed in Boost 1.87, so the alias is only declared there.
namespace boost { namespace asio {
#if BOOST_VERSION >= 108700
    using io_service = io_context;
#endif
    namespace ip {
        typedef tcp::resolver tcp_resolver;
    }
} }

#else // BOOST_VERSION < 106600

namespace boost
{
    namespace posix_time
    {
        class ptime;
    }

    namespace asio
    {
        template <typename Time>
        struct time_traits;

        namespace ip
        {
            class address;

            class tcp;

            template <typename InternetProtocol>
            class basic_endpoint;

            typedef basic_endpoint<tcp> tcp_endpoint;
        }

        template <typename TimeType, typename TimeTraits>
        class deadline_timer_service;

        template <typename Time, typename TimeTraits, typename TimerService>
        class basic_deadline_timer;

        typedef basic_deadline_timer<posix_time::ptime, time_traits<posix_time::ptime>, deadline_timer_service<posix_time::ptime, time_traits<posix_time::ptime>>> deadline_timer;

        namespace ip
        {
            template <typename InternetProtocol>
            class resolver_service;

            template <typename InternetProtocol, typename ResolverService>
            class basic_resolver;

            typedef basic_resolver<tcp, resolver_service<tcp>> tcp_resolver;
        }
    }
}

#endif // BOOST_VERSION >= 106600

namespace LegionForge
{
    namespace Asio
    {
        class Strand;
    }
}

#endif // AsioHacksFwd_h__

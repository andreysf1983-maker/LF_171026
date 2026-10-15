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

#include "SslContext.h"
#include "Log.h"
#include "Config.h"

#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/x509.h>

#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

#ifdef _WIN32
#include <Windows.h>
#else
#include <limits.h>
#include <unistd.h>
#endif

// [LEGIONFORGE PATCH 2026-10] -------------------------------------------------
// bnetserver падал сразу после шапки с единственной строкой
//   "Failed to initialize SSL context"
// Причины, которые встречались в поле:
//   1. CertificatesFile/PrivateKeyFile заданы относительными путями
//      ("./bnetserver.cert.pem"), а bnetserver запускается с другим рабочим
//      каталогом (ярлык, планировщик, NSSM, start /D ...) -> файл не находится.
//   2. .pem вообще не скопированы в каталог сборки (build_server.ps1 копировал
//      только *.exe/*.dll).
//   3. Сертификат и ключ от разных пар (обновлён один из файлов).
//   4. Подробная причина логировалась в категорию "server.ssl", которой нет в
//      bnetserver.conf -> в консоль ничего не выводилось.
// Теперь: пути разрешаются по нескольким каталогам, пара cert/key проверяется,
// при отсутствии/рассинхроне генерируется самоподписанная пара (OpenSSL 3.x,
// SHA-256, RSA-2048, 10 лет), а все ошибки OpenSSL печатаются явно.
// -----------------------------------------------------------------------------

namespace
{
    std::string GetExecutableDir()
    {
#ifdef _WIN32
        char path[MAX_PATH] = { };
        if (::GetModuleFileNameA(nullptr, path, MAX_PATH) != 0)
        {
            std::string full(path);
            size_t pos = full.find_last_of("\\/");
            if (pos != std::string::npos)
                return full.substr(0, pos);
        }
#else
        char path[PATH_MAX] = { };
        ssize_t len = ::readlink("/proc/self/exe", path, sizeof(path) - 1);
        if (len > 0)
        {
            path[len] = '\0';
            std::string full(path);
            size_t pos = full.find_last_of('/');
            if (pos != std::string::npos)
                return full.substr(0, pos);
        }
#endif
        return std::string();
    }

    bool FileExists(std::string const& path)
    {
        if (path.empty())
            return false;

        std::ifstream file(path.c_str(), std::ios::binary);
        return file.good();
    }

    std::string JoinPath(std::string const& dir, std::string const& file)
    {
        if (dir.empty())
            return file;

        char const last = dir[dir.size() - 1];
        if (last == '/' || last == '\\')
            return dir + file;

#ifdef _WIN32
        return dir + "\\" + file;
#else
        return dir + "/" + file;
#endif
    }

    std::string BaseName(std::string const& path)
    {
        size_t pos = path.find_last_of("\\/");
        return pos == std::string::npos ? path : path.substr(pos + 1);
    }

    // Пробует найти pem-файл: как задано в конфиге (относительно CWD), рядом с
    // exe, в родительском каталоге и в <root>/server.
    bool ResolvePemPath(std::string& path)
    {
        if (FileExists(path))
            return true;

        std::string const fileName = BaseName(path);
        std::string const exeDir = GetExecutableDir();

        std::vector<std::string> candidates;
        candidates.push_back(fileName);
        if (!exeDir.empty())
        {
            candidates.push_back(JoinPath(exeDir, fileName));
            candidates.push_back(JoinPath(exeDir, path));
            candidates.push_back(JoinPath(JoinPath(exeDir, ".."), fileName));
            candidates.push_back(JoinPath(JoinPath(exeDir, "../server"), fileName));
            candidates.push_back(JoinPath(JoinPath(exeDir, "..\\server"), fileName));
        }

        for (std::string const& candidate : candidates)
        {
            if (FileExists(candidate))
            {
                if (candidate != path)
                    LF_LOG_WARN("server.ssl", "'%s' not found at the configured path, using '%s' instead", path.c_str(), candidate.c_str());

                path = candidate;
                return true;
            }
        }

        return false;
    }

    std::string GetOpenSSLErrors()
    {
        std::string result;
        char buffer[256];
        unsigned long code;
        while ((code = ERR_get_error()) != 0)
        {
            ERR_error_string_n(code, buffer, sizeof(buffer));
            if (!result.empty())
                result += "; ";
            result += buffer;
        }

        return result;
    }

    bool CheckPairMatches(std::string const& certPath, std::string const& keyPath)
    {
        FILE* certFp = fopen(certPath.c_str(), "rb");
        FILE* keyFp = fopen(keyPath.c_str(), "rb");
        if (!certFp || !keyFp)
        {
            if (certFp) fclose(certFp);
            if (keyFp) fclose(keyFp);
            return false;
        }

        X509* cert = PEM_read_X509(certFp, nullptr, nullptr, nullptr);
        EVP_PKEY* pkey = PEM_read_PrivateKey(keyFp, nullptr, nullptr, nullptr);
        fclose(certFp);
        fclose(keyFp);

        if (!cert || !pkey)
        {
            std::string errors = GetOpenSSLErrors();
            LF_LOG_ERROR("server.ssl", "Unable to parse PEM pair (cert='%s', key='%s')%s%s",
                certPath.c_str(), keyPath.c_str(), errors.empty() ? "" : ": ", errors.c_str());
            X509_free(cert);
            EVP_PKEY_free(pkey);
            return false;
        }

        bool const matches = X509_check_private_key(cert, pkey) == 1;
        if (!matches)
            LF_LOG_ERROR("server.ssl", "Certificate '%s' does NOT match private key '%s' - they are from different key pairs",
                certPath.c_str(), keyPath.c_str());

        X509_free(cert);
        EVP_PKEY_free(pkey);
        return matches;
    }

    // Самоподписанная пара: SHA-256 + RSA-2048 (OpenSSL 3.x принимает её без
    // legacy-провайдера), срок 10 лет, CN/SAN не критичны - клиент 7.3.5 не
    // проверяет цепочку доверия для battle.net.
    bool GenerateSelfSignedPair(std::string const& certPath, std::string const& keyPath)
    {
        EVP_PKEY* pkey = nullptr;
#if OPENSSL_VERSION_NUMBER >= 0x30000000L
        pkey = EVP_RSA_gen(2048);
#else
        RSA* rsa = RSA_generate_key(2048, RSA_F4, nullptr, nullptr);
        if (rsa)
        {
            pkey = EVP_PKEY_new();
            if (pkey && EVP_PKEY_assign_RSA(pkey, rsa) != 1)
            {
                EVP_PKEY_free(pkey);
                pkey = nullptr;
                RSA_free(rsa);
            }
        }
#endif
        if (!pkey)
        {
            std::string errors = GetOpenSSLErrors();
            LF_LOG_ERROR("server.ssl", "Failed to generate an RSA key%s%s", errors.empty() ? "" : ": ", errors.c_str());
            return false;
        }

        X509* x509 = X509_new();
        if (!x509)
        {
            EVP_PKEY_free(pkey);
            return false;
        }

        bool ok = true;
        X509_set_version(x509, 2);
        ASN1_INTEGER_set(X509_get_serialNumber(x509), 1);
        X509_gmtime_adj(X509_getm_notBefore(x509), -60 * 60 * 24);
        X509_gmtime_adj(X509_getm_notAfter(x509), 60 * 60 * 24 * 3650);
        ok = ok && X509_set_pubkey(x509, pkey) == 1;

        X509_NAME* name = X509_get_subject_name(x509);
        ok = ok && X509_NAME_add_entry_by_txt(name, "C", MBSTRING_ASC, reinterpret_cast<unsigned char const*>("RU"), -1, -1, 0) == 1;
        ok = ok && X509_NAME_add_entry_by_txt(name, "O", MBSTRING_ASC, reinterpret_cast<unsigned char const*>("LegionForge"), -1, -1, 0) == 1;
        ok = ok && X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, reinterpret_cast<unsigned char const*>("LegionForge Battle.net Server"), -1, -1, 0) == 1;
        ok = ok && X509_set_issuer_name(x509, name) == 1;
        ok = ok && X509_sign(x509, pkey, EVP_sha256()) != 0;

        if (ok)
        {
            FILE* certFp = fopen(certPath.c_str(), "wb");
            if (certFp)
            {
                ok = PEM_write_X509(certFp, x509) == 1;
                fclose(certFp);
            }
            else
                ok = false;
        }

        if (ok)
        {
            FILE* keyFp = fopen(keyPath.c_str(), "wb");
            if (keyFp)
            {
                ok = PEM_write_PrivateKey(keyFp, pkey, nullptr, nullptr, 0, nullptr, nullptr) == 1;
                fclose(keyFp);
            }
            else
                ok = false;
        }

        if (!ok)
        {
            std::string errors = GetOpenSSLErrors();
            LF_LOG_ERROR("server.ssl", "Failed to write the self-signed PEM pair (cert='%s', key='%s')%s%s",
                certPath.c_str(), keyPath.c_str(), errors.empty() ? "" : ": ", errors.c_str());
        }

        X509_free(x509);
        EVP_PKEY_free(pkey);
        return ok;
    }

    std::string GetWritableDir(std::string const& configuredPath)
    {
        std::string exeDir = GetExecutableDir();
        if (!exeDir.empty())
            return exeDir;

        size_t pos = configuredPath.find_last_of("\\/");
        if (pos != std::string::npos && !configuredPath.substr(0, pos).empty())
            return configuredPath.substr(0, pos);

        return ".";
    }
}

bool Battlenet::SslContext::Initialize()
{
    boost::system::error_code err;

    std::string certificateChainFile = sConfigMgr->GetStringDefault("CertificatesFile", "./bnetserver.cert.pem");
    std::string privateKeyFile = sConfigMgr->GetStringDefault("PrivateKeyFile", "./bnetserver.key.pem");
    bool const autoGenerate = sConfigMgr->GetBoolDefault("SSLCertAutoGenerate", true);

    bool const certFound = ResolvePemPath(certificateChainFile);
    bool const keyFound = ResolvePemPath(privateKeyFile);
    bool pairOk = certFound && keyFound && CheckPairMatches(certificateChainFile, privateKeyFile);

    if (!pairOk)
    {
        if (!certFound)
            LF_LOG_ERROR("server.ssl", "Certificate file not found: '%s' (looked in the current directory, next to bnetserver.exe and in ./server)",
                sConfigMgr->GetStringDefault("CertificatesFile", "./bnetserver.cert.pem").c_str());
        if (!keyFound)
            LF_LOG_ERROR("server.ssl", "Private key file not found: '%s'",
                sConfigMgr->GetStringDefault("PrivateKeyFile", "./bnetserver.key.pem").c_str());

        if (!autoGenerate)
        {
            LF_LOG_ERROR("server.ssl", "SSLCertAutoGenerate = 0: refusing to start. Copy a valid bnetserver.cert.pem/bnetserver.key.pem pair next to bnetserver.exe or run tools\\ensure_ssl_cert.ps1");
            return false;
        }

        std::string const dir = GetWritableDir(certificateChainFile);
        certificateChainFile = JoinPath(dir, "bnetserver.cert.pem");
        privateKeyFile = JoinPath(dir, "bnetserver.key.pem");

        LF_LOG_WARN("server.ssl", "Generating a self-signed certificate: '%s' + '%s'", certificateChainFile.c_str(), privateKeyFile.c_str());
        if (!GenerateSelfSignedPair(certificateChainFile, privateKeyFile))
            return false;

        LF_LOG_WARN("server.ssl", "Self-signed pair generated. It is fine for a private realm; replace it with your own pair if you need a trusted certificate.");
    }

#define LOAD_CHECK(fn) do { fn; \
    if (err) \
    { \
        std::string sslErrors = GetOpenSSLErrors(); \
        LF_LOG_ERROR("server.ssl", #fn " failed: %s%s%s", err.message().c_str(), sslErrors.empty() ? "" : " | OpenSSL: ", sslErrors.c_str()); \
        return false; \
    } } while (0)

    LOAD_CHECK(instance().set_options(boost::asio::ssl::context::no_sslv2, err));
    LOAD_CHECK(instance().set_options(boost::asio::ssl::context::no_sslv3, err));
    LOAD_CHECK(instance().use_certificate_chain_file(certificateChainFile, err));
    LOAD_CHECK(instance().use_private_key_file(privateKeyFile, boost::asio::ssl::context::pem, err));

#undef LOAD_CHECK

    LF_LOG_INFO("server.ssl", "SSL context initialized (cert='%s', key='%s', auto-generated=%s)",
        certificateChainFile.c_str(), privateKeyFile.c_str(), pairOk ? "no" : "yes");

    return true;
}

boost::asio::ssl::context& Battlenet::SslContext::instance()
{
    static boost::asio::ssl::context context(boost::asio::ssl::context::sslv23);
    return context;
}

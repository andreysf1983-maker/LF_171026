// [LEGIONFORGE FIX 2026-10] Common.h no longer defines snprintf/vsnprintf as macros on
// VS2015+ (see core/src/common/Common.h), so the ordering below is no longer load-bearing.
// It is kept because OpenSSL first is still the safest order for CRYPTO_RWLOCK and because
// pre-VS2015 toolchains continue to rely on the legacy aliases.
#include <openssl/crypto.h>
#include "Common.h"
#include "World.h"
#include "Log.h"
#include "Database/DatabaseEnv.h"
#include "Configuration/Config.h"
#include "Util.h"

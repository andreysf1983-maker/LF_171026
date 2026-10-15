#include "Define.h"
#include "Errors.h"
#include "Field.h"
#include "Log.h"
#include "MySQLConnection.h"
#include "PreparedStatement.h"
#include "QueryResult.h"
#include "SQLOperation.h"
#include "Transaction.h"
#ifdef _WIN32 // hack for broken mysql.h not including the correct winsock header for SOCKET definition, fixed in 5.7
#include <winsock2.h>
#endif
#include <mysql.h>
// MySQL 8.0.1+ removed my_bool - provide compatibility typedef.
// LEGIONFORGE audit fix: "#ifndef my_bool" was always true (my_bool is a typedef, not a macro),
// which clashed with MySQL 5.7 / MariaDB headers (typedef char my_bool).
#if !defined(MARIADB_VERSION_ID) && !defined(MARIADB_BASE_VERSION) && defined(MYSQL_VERSION_ID) && MYSQL_VERSION_ID >= 80001
typedef bool my_bool;
#endif
#include <string>
#include <vector>

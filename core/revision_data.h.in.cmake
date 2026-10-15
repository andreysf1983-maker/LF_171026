#ifndef __REVISION_DATA_H__
#define __REVISION_DATA_H__
 #define _REVISION                  "@rev_number@"
 #define _HASH                      "@rev_hash@"
 #define _COMMIT                    "@rev_commit@"
 #define _DATE                      "@rev_date@"
 #define _BRANCH                    "@rev_branch@"
 #define _CMAKE_COMMAND             R"(@CMAKE_COMMAND@)"
 #define _CMAKE_VERSION             R"(@CMAKE_VERSION@)"
 #define _CMAKE_HOST_SYSTEM         R"(@CMAKE_HOST_SYSTEM_NAME@ @CMAKE_HOST_SYSTEM_VERSION@)"
 #define _SOURCE_DIRECTORY          R"(@LF_SOURCE_ROOT@)"
 #define _BUILD_DIRECTORY           R"(@BUILDDIR@)"
 #define _MYSQL_EXECUTABLE          R"(@MYSQL_EXECUTABLE@)"
 #define _FULL_DATABASE             "ADB_world_735.00.sql"
 #define _HOTFIXES_DATABASE         "ADB_hotfixes_735.00.sql"
 #define VER_COMPANYNAME_STR        "LegionForge Developers"
 #define VER_LEGALCOPYRIGHT_STR     "(c)2008-2026 LegionForge"
 #define VER_FILEVERSION            7,3,5,@rev_number@
 #define VER_FILEVERSION_STR        "rev.@rev_number@ @rev_date@"
 #define VER_PRODUCTVERSION         VER_FILEVERSION
 #define VER_PRODUCTVERSION_STR     VER_FILEVERSION_STR
#endif // __REVISION_DATA_H__

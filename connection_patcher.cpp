// Simple WoW Legion 7.3.5 connection patcher
// Patches the client exe to connect to 127.0.0.1
// Usage: run from the client folder (back up the exe first)

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static const char* EXES[] = {
    "Wow.exe",
    "Wow-64.exe",
    "Hellgarve.Legion-64.exe",
    "WowB.exe",
    "WowT.exe",
    NULL
};

static const char PATCH_PATTERN[] = "legion.fstorm.eu";
static const char PATCH_REPLACE[] = "127.0.0.1     ";

static int PatchFile(const char* path)
{
    FILE* f = fopen(path, "rb+");
    if (!f)
        return -1;

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t* buf = (uint8_t*)malloc((size_t)size);
    if (!buf)
    {
        fclose(f);
        return -1;
    }

    if (fread(buf, 1, (size_t)size, f) != (size_t)size)
    {
        free(buf);
        fclose(f);
        return -1;
    }

    int patched = 0;
    size_t plen = strlen(PATCH_PATTERN);
    size_t rlen = strlen(PATCH_REPLACE);
    for (long i = 0; i + (long)plen <= size; ++i)
    {
        if (memcmp(buf + i, PATCH_PATTERN, plen) == 0)
        {
            memcpy(buf + i, PATCH_REPLACE, rlen);
            patched = 1;
        }
    }

    if (patched)
    {
        fseek(f, 0, SEEK_SET);
        fwrite(buf, 1, (size_t)size, f);
        printf("[OK] Patched %s to 127.0.0.1\n", path);
    }

    free(buf);
    fclose(f);
    return patched;
}

int main(int argc, char** argv)
{
    if (argc > 1)
    {
        int r = PatchFile(argv[1]);
        if (r < 0)
        {
            printf("[!] Could not open %s\n", argv[1]);
            return 1;
        }
        if (r == 0)
            printf("[!] Pattern not found in %s (already patched or different build)\n", argv[1]);
        return 0;
    }

    int any = 0;
    for (int i = 0; EXES[i]; ++i)
    {
        int r = PatchFile(EXES[i]);
        if (r > 0)
            any = 1;
    }

    if (!any)
        printf("[!] No client exe patched. Run this from the folder that contains Wow.exe / Wow-64.exe.\n");
    return 0;
}

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main (int argc, char *argv[])
{
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "%s %s %.15s", "/bin/bash", 
             "/ups/control.sh", ((argc > 1) ? argv[1] : ""));
    setuid (0);
    return system(cmd);
}

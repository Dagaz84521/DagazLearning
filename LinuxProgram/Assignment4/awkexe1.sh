#!/bin/bash

awk -F: 'BEGIN {
    printf "%-20s \n", "List of Users"
    print "------------------------------------------------------------"
}
{
    username = $1
    groupname = $4
    shellpath = $7

    printf "%-20s %-20s %-20s\n", username, groupname, shellpath

    shell_count[shellpath]++
}
END {
    print "------------------------------------------------------------"
    printf "Shell Path Statistics:\n"
    for (path in shell_count) {
        printf "%s: %d\n", path, shell_count[path]
    }
}' /etc/passwd > awk1.out


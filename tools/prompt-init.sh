# prompt-init.sh
if [ "$SHLVL" -gt 1 ] || [ "$BASH_SUBSHELL" -gt 0 ]; then
    PC1="\033[1;32m"
    PC2="\033[1;37m"
    PC3="\033[1;31m"
    NC="\033[0m"

    PS1="$PC1[\u@\h:\w]$PC2 $SHLVL.$BASH_SUBSHELL $PC3\$$NC\] "
else
    PS1="\u@\h:\w\$ "
fi

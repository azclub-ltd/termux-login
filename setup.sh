#!/bin/bash
# Define colors
colors=(
    [BLACK]='\033[30m'
    [RED]='\033[31m'
    [GREEN]='\033[32m'
    [YELLOW]='\033[33m'
    [BLUE]='\033[34m'
    [MAGENTA]='\033[35m'
    [CYAN]='\033[36m'
    [WHITE]='\033[37m'
    [LIGHT_RED]='\033[1;31m'
    [LIGHT_GREEN]='\033[1;32m'
    [LIGHT_YELLOW]='\033[1;33m'
    [LIGHT_BLUE]='\033[1;34m'
    [LIGHT_MAGENTA]='\033[1;35m'
    [LIGHT_CYAN]='\033[1;36m'
    [LIGHT_WHITE]='\033[1;37m'
    [NC]='\033[0m'
)
# Necessary functions
function binChecker() {
    # Check if bin file already exist
    if [ -e "$PREFIX/bin/terlog" ]; then
        # bin found
        isBinFound=true
        # Check read permission
        if [ -r "$PREFIX/bin/terlog" ]; then
            hasReadPermission=true
        else
            hasReadPermission=false
        fi
        # Check write permission
        if [ -w "$PREFIX/bin/terlog" ]; then
            hasWritePermission=true
        else
            hasWritePermission=false
        fi
        # Check execute permission
        if [ -x "$PREFIX/bin/terlog" ]; then
            hasExecutePermission=true
        else
            hasExecutePermission=false
        fi
    else
        # bin not found
        isBinFound=false
    fi
}
function createBinFile() {
    # Create bin File
    if cat bin/.termux-binary.sh >"terlog"; then
        echo -e "${colors[LIGHT_GREEN]}Binary created${colors[NC]}"
        if chmod +x terlog; then
            echo -e "${colors[LIGHT_GREEN]}Execute permission given${colors[NC]}"
            if mv terlog "$PATH"; then
                echo -e "${colors[LIGHT_GREEN]}now ${colors[MAGENTA]}terlog${colors[NC]} command is available globally${colors[NC]}"
            else
                echo -e "${colors[LIGHT_RED]}Failed to make terlog as global command. It will only work inside this directory${colors[NC]}"
                exit 1
            fi
            echo -e "Use \"${colors[MAGENTA]}terlog --help${colors[NC]}\" for detailed info"
            echo -e "use \"${colors[MAGENTA]}terlog user-setup${colors[NC]}\" to setup login system"
        fi
    else
        echo -e "${colors[LIGHT_RED]}Failed to create binary file${colors[NC]}"
        exit 1
    fi
}
function manageBinPermission() {
    if $isBinFound; then
        # ensure library permission
        if $hasReadPermission; then
            chmod a-r "$PREFIX/bin/terlog"
        fi
        if $hasWritePermission; then
            chmod -w "$PREFIX/bin/terlog"
        fi
        if ! $hasExecutePermission; then
            chmod +x "$PREFIX/bin/terlog"
        fi
    else
        createBinFile
    fi
}
function installRequiredPackage() {
    # install required pacakges
    if ! command -v openssl passwd >/dev/null 2>&1; then
        echo -e "${colors[CYAN]}Installing required package..${colors[NC]}"
        if pkg install openssl-tool -y >/dev/null 2>&1; then
            echo -e "${colors[LIGHT_GREEN]}Successfully installed${colors[NC]}"
        else
            echo -e "${colors[RED]}There was an error installing package${colors[NC]}"
        fi
    fi
}
function setup() {
    # Execute binary checker
    binChecker
    # Manage binary permission
    manageBinPermission && installRequiredPackage # Install required dependency
}
setup
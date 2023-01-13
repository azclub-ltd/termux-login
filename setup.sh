#!/bin/bash
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
        echo "Binary created"
        if chmod +x terlog; then
            echo "Execute permission given"
            if mv terlog "$PATH"; then
                echo "now 'terlog' command is available globally"
            fi
        fi
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
        echo "Installing required package.."
        if pkg install openssl-tool -y >/dev/null 2>&1; then
            echo "Successfully installed"
        else
            echo "There was an error installing package"
        fi
    fi
}
function setup() {
    # Execute binary checker
    binChecker
    # Manage binary permission
    manageBinPermission
    # Install required dependency
    installRequiredPackage
    echo 'Use "terlog --help" for details info'
    echo 'use "terlog setup" to setup login system'
}
setup

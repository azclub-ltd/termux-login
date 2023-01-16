#!/bin/bash
# Global variable
shadowFile=$PREFIX/etc/shadow
passwdFile=$PREFIX/etc/passwd
loginFile=$PREFIX/etc/termux-login.sh
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
# All necessary function written here
function checkExistingCredentialFile() {
    if [ -e "$passwdFile" ] || [ -e "$shadowFile" ]; then
        credFileFound=true
        # check whether credential is in both file
        if [ -e "$passwdFile" ] && [ -e "$shadowFile" ]; then
            credFileFoundCode=0
        elif [ -e "$passwdFile" ]; then
            credFileFoundCode=1
        elif [ -e "$shadowFile" ]; then
            credFileFoundCode=2
        fi
    else
        credFileFound=false
    fi
}
function showECFStatus() {
    if [ "$credFileFoundCode" -eq 0 ]; then
        credFileFoundMsg="Both passwd and shadow file found"
    elif [ "$credFileFoundCode" -eq 1 ]; then
        credFileFoundMsg="passwd file found"
    elif [ "$credFileFoundCode" -eq 2 ]; then
        credFileFoundMsg="shadow file found"
    fi
    echo -e "${colors[LIGHT_YELLOW]}$credFileFoundMsg${colors[NC]}"
    echo -e "${colors[MAGENTA]}In order to setup login system we recommend you to remove existing credential.${colors[NC]}"
    echo "Do you agree?(y/n) [n will stop further execution] "
}
function actionForECF() {
    local confirm1
    read -r confirm1
    if [ "$confirm1" == "y" ] || [ "$confirm1" == "yes" ]; then
        local removeSuccessMsg removeFailedMsg
        removeSuccessMsg="Successfully removed"
        removeFailedMsg="Failed to remove"
        if [ "$credFileFoundCode" -eq 0 ]; then
            if rm "$passwdFile" "$shadowFile"; then
                echo -e "${colors[LIGHT_GREEN]}$removeSuccessMsg${colors[NC]}"
            else
                echo -e "${colors[RED]}$removeFailedMsg${colors[NC]}"
            fi
        elif [ "$credFileFoundCode" -eq 1 ]; then
            if rm "$passwdFile"; then
                echo -e "${colors[LIGHT_GREEN]}$removeSuccessMsg${colors[NC]}"
            else
                echo -e "${colors[RED]}$removeFailedMsg${colors[NC]}"
            fi
        elif [ "$credFileFoundCode" -eq 2 ]; then
            if rm "$shadowFile"; then
                echo -e "${colors[LIGHT_GREEN]}$removeSuccessMsg${colors[NC]}"
            else
                echo -e "${colors[RED]}$removeFailedMsg${colors[NC]}"
            fi
        fi
    elif [ "$confirm1" == "n" ] || [ "$confirm1" == "no" ]; then
        echo "Terminating..."
        exit 1
    else
        echo "Invalid option. Type (y/n)"
        actionForECF
    fi
}
function handleExistingCredentialFile() {
    if $credFileFound; then
        showECFStatus
        actionForECF
    else
        touch "$shadowFile" && echo -e "${colors[LIGHT_GREEN]}Necessary storing file Created.${colors[NC]}"
    fi
}
function unInstallTerlog() {
    # Remove credential file
    echo -e "${colors[CYAN]}Removing credentials..${colors[NC]}"
    checkExistingCredentialFile
    if $credFileFound; then
        if [ "$credFileFoundCode" -eq 0 ]; then
            rm "$passwdFile" "$shadowFile"
        elif [ "$credFileFoundCode" -eq 1 ]; then
            rm "$passwdFile"
        elif [ "$credFileFoundCode" -eq 2 ]; then
            rm "$shadowFile"
        fi
    fi
    # Remove login script
    echo -e "${colors[CYAN]}Removing login script..${colors[NC]}"
    local tempFile
    tempFile=$PREFIX/tmp/termux-login.tmp
    sed '/^#/!{/terlog login-user/d;}' "$loginFile" >"$tempFile" && mv "$tempFile" "$loginFile"
    # Remove binary file
    echo -e "${colors[CYAN]}Uninstalling Terlog..${colors[NC]}"
    if [ -e "$PATH"/terlog ]; then
        rm "$PATH"/terlog
    fi
    echo "${colors[LIGHT_GREEN]}Process Done.${colors[NC]}"
}
function promtUninstall() {
    local confirmDel
    confirmDel=$1
    if [ "$confirmDel" == "-y" ]; then
        # start uninstallation
        unInstallTerlog
    else
        echo -e "${colors[LIGHT_YELLOW]}It will uninstall terlog packages and credentials from termux${colors[NC]}"
        echo "Are you sure to uninstall? Type (y/yes) to confirm"
        read -r confirmDel
        if [ "$confirmDel" == "y" ] || [ "$confirmDel" == "yes" ]; then
            unInstallTerlog
        else
            echo "Not uninstalled"
        fi
    fi
}
function ensureRequiredPackage() {
    # ensuring required pacakges
    if ! command -v openssl passwd >/dev/null 2>&1; then
        echo -e "${colors[CYAN]}Installing required package..${colors[NC]}"
        if pkg install openssl-tool -y >/dev/null 2>&1; then
            echo -e "${colors[LIGHT_GREEN]}Successfully installed${colors[NC]}"
        else
            echo -e "${colors[RED]}There was an error installing package, Stopping..${colors[NC]}"
        fi
    fi
}
function storeCredential() {
    local generatedCredential
    generatedCredential=$1
    echo "$generatedCredential" >>"$shadowFile"
}
function generateCredential() {
    # local variable that will store argument(user-name and password )
    local uname upass
    uname=$1
    upass=$2
    # local variable that will be used to generate credential
    local current_unix_time days_since_epoch min_pass_age max_pass_age warning_period inactive_period expiration_date
    # default and dynamic values assigened bottom
    current_unix_time=$(date +%s)
    days_since_epoch=$(echo "$current_unix_time / 86400" | awk '{print $1}')
    min_pass_age=0
    max_pass_age=99999
    warning_period=7
    inactive_period=""
    expiration_date=""

    # local variable that will be used to encrypt password
    local hash_type salt final_pass generatedCredential
    hash_type=6
    # Generate a 6 character long salt
    salt=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 6 | head -n 1)

    # Create final pass
    final_pass=$(openssl passwd -$hash_type -salt "$salt" "$upass")
    # concat all values along with colon as the seperator
    generatedCredential=$(printf "%s:%s:%d:%d:%d:%d:%s:%s:" "$uname" "$final_pass" "$days_since_epoch" $min_pass_age $max_pass_age $warning_period "$inactive_period" "$expiration_date")
    storeCredential "$generatedCredential"
}
function checkUserName() {
    # local variables
    local userName querifiedUserFound userInDB
    userName=$1
    querifiedUserFound=false
    # Check every line for user
    while read -r line; do
        # get user name
        read -r userInDB <<<"$(cut -d: -f1 <<<"$line")"
        # Test if the user from current line matches the actual user
        if [ "$userInDB" == "$userName" ]; then
            querifiedUserFound=true
            break
        fi
    done <"$shadowFile"
    if $querifiedUserFound; then
        return 0
    else
        return 1
    fi
}
function enterPasswordAndConfirm() {
    # Hold the user name
    local user_name user_pass confirm_pass
    user_name=$1
    # Do main job
    echo "Enter password for ${user_name}:"
    read -r -s user_pass
    if [ ${#user_pass} -gt 48 ]; then
        echo -e "${colors[LIGHT_RED]}Error: Password must be no longer than 48 characters.${colors[NC]}"
        enterPasswordAndConfirm "$user_name"
    else
        echo "Confirm your Password:"
        read -r -s confirm_pass
        if [ "$user_pass" == "$confirm_pass" ]; then
            generateCredential "$user_name" "$user_pass"
        else
            echo -e "${colors[LIGHT_RED]}Password doesn't match${colors[NC]}"
            enterPasswordAndConfirm "$user_name"
        fi
    fi

}
function enterUserName() {
    echo "Enter your UserName:"
    local user_name
    read -r user_name
    if [[ "$user_name" =~ ^[a-z][a-z0-9_]{2,8}$ ]]; then
        if ! checkUserName "$user_name"; then
            enterPasswordAndConfirm "$user_name"
        else
            echo -e "${colors[RED]}Error: User Already Exist, choose another user name${colors[NC]}"
            enterUserName
        fi
    else
        echo -e "${colors[RED]}User name must contain only lowercase letters, digits, and underscores, must not start with a number, and must be 3 to 8 characters long.${colors[NC]}"
        enterUserName
    fi
}
function comparePassword() {
    local user_name user_pass user_pass_encrypted userPointer userArray
    user_name=$1
    user_pass=$2
    while read -r eachLine; do
        # Get the line by user name
        read -r userPointer <<<"$(cut -d: -f1 <<<"$eachLine")"
        if [ "$userPointer" == "$user_name" ]; then
            read -ra userArray <<<"$(cut -d: -f1- --output-delimiter=' ' <<<"$eachLine")"
            break
        fi
    done <"$shadowFile"
    local passArray hash_type salt
    # Now extract password
    read -ra passArray <<<"$(cut -d$ -f1- --output-delimiter=' ' <<<"${userArray[1]}")"
    hash_type=${passArray[0]}
    hash_type=$((hash_type + 0)) # type casted to number
    salt=${passArray[1]}
    user_pass_encrypted=$(openssl passwd -$hash_type -salt "$salt" "$user_pass")
    # Compare password
    if [ "$user_pass_encrypted" == "${userArray[1]}" ]; then
        echo "Now the stage is yours"
        return 0
    else
        return 1
    fi
}
function addUser() {
    ensureRequiredPackage
    enterUserName
}
function overrideConfirmFunc() {
    local confirmOverride logScript
    logScript="terlog login"
    read -r confirmOverride
    if [ "$confirmOverride" == "yes" ] || [ "$confirmOverride" == "y" ]; then
        # proceed with overriding
        echo "$logScript" >"$loginFile"
        return 0
    elif [ "$confirmOverride" == "safe" ] || [ "$confirmOverride" == "s" ]; then
        # proceed with safe mode
        sed -i "1s/^/${logScript}\n/"
        return 0
    elif [ "$confirmOverride" == "no" ] || [ "$confirmOverride" == "n" ]; then
        # Cancel process
        echo -e "${colors[CYAN]}Cancelling${colors[NC]}"
        return 1
    else
        echo -e "${colors[LIGHT_RED]}Invalid option${colors[NC]}"
        overrideConfirmFunc
    fi
}
function inject() {
    # Check previous script
    if [ -e "$loginFile" ]; then
        # Check if at least one user is found
        if [ "$(wc -l <"$loginFile")" -gt 0 ]; then
            # Detect older/other script
            local boilerText sysText
            boilerText=$(
                cat <<EOF
##
## This script is sourced by /data/data/com.termux/files/usr/bin/login before executing shell.
##
EOF
            )
            sysText=$(<"$loginFile")
            if [ "$sysText" == "$boilerText" ] || [ "$sysText" == "" ]; then
                echo "terlog login" >"$loginFile"
            else
                echo "Already some login script found do you want to Override it?(y/s/n)"
                echo 'Type "y/yes" to override'
                echo 'Type "s/safe" to add safely at the top (recommended)'
                echo 'Type "n/no" to prevent override and cancel installation'
                if overrideConfirmFunc; then
                    echo "Done, give a try by restarting Termux"
                else
                    exit
                fi
            fi
        fi
    else
        touch "$loginFile"
    fi
    # finally inject script

}
function startSetup() {
    checkExistingCredentialFile
    handleExistingCredentialFile
    addUser
}
function loginUser() {
    ensureRequiredPackage
    # promt user for username
    local user_name
    echo "Enter your user name:"
    read -r user_name
    if checkUserName "$user_name"; then
        echo "Welcome ${user_name}"
        echo "Enter your password:"
        local user_pass
        read -r -s user_pass
        comparePassword "$user_name" "$user_pass"
    else
        echo -e "${colors[LIGHT_RED]}No user Found${colors[NC]}"
        loginUser
    fi
}
function helpUser() {
    cat <<EOF
terlog [option]
possible options are:-
user-setup      : setup for first time
user-add        : add a new user
user-login      : log a user in (used by the system)
uninstall       : uninstall terlog
uninstall-np    : uninstall without showing confirmation promt
-h              : show help
--help          : same as -h

Description:-
'user-setup' option is for first time setup only. It eventually delete previous login details if exist.
'user-add' option is to add a new user to the database. It doesn't delete previous login details.
'user-login' option is to log a user in. This option is used by system at starting.
'uninstall' option is to uninstall this(terlog) package.
EOF
}
# Main code starts here
if [ $# -eq 0 ]; then
    echo 'Please provide at least one argument or pass "-h" for help'
    exit 1
elif [ $# -gt 1 ]; then
    echo 'Please provide only one argument or pass "-h" for help'
    exit 1
else
    if [ "$1" == "user-setup" ]; then
        startSetup
    elif [ "$1" == "user-add" ]; then
        addUser
    elif [ "$1" == "user-login" ]; then
        loginUser
    elif [ "$1" == "uninstall" ]; then
        promtUninstall ""
    elif [ "$1" == "uninstall-np" ]; then
        promtUninstall "-y"
    elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        helpUser
    else
        echo -e "Invalid Command. Try \"${colors[MAGENTA]}terlog -h${colors[NC]}\" for help."
    fi
fi

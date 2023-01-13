#!/bin/bash
# Global variable
shadowFile=$PREFIX/etc/shadow
passwdFile=$PREFIX/etc/passwd
loginFile=$PREFIX/etc/termux-login.sh

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
function handleExistingCredentialFile() {
    if $credFileFound; then
        if [ "$credFileFoundCode" -eq 0 ]; then
            credFileFoundMsg="Both passwd and shadow file found"
        elif [ "$credFileFoundCode" -eq 1 ]; then
            credFileFoundMsg="passwd file found"
        elif [ "$credFileFoundCode" -eq 2 ]; then
            credFileFoundMsg="shadow file found"
        fi
        echo "$credFileFoundMsg"
        echo "In order to setup login system we recommend you to remove existing credential."
        echo "Do you agree?(y/n) [n will terminate the process] "
        read -r confirm1
        if [ "$confirm1" == "y" ] || [ "$confirm1" == "yes" ]; then
            if [ "$credFileFoundCode" -eq 0 ]; then
                if rm "$passwdFile" "$shadowFile"; then
                    removeMsg="Successfully removed"
                else
                    removeMsg="Failed to remove"
                fi
            elif [ "$credFileFoundCode" -eq 1 ]; then
                if rm "$passwdFile"; then
                    removeMsg="Successfully removed"
                else
                    removeMsg="Failed to remove"
                fi
            elif [ "$credFileFoundCode" -eq 2 ]; then
                if rm "$shadowFile"; then
                    removeMsg="Successfully removed"
                else
                    removeMsg="Failed to remove"
                fi
            fi
            echo "$removeMsg"
        else
            echo "Terminating..."
            kill -9 $PPID
        fi
    else
        touch "$shadowFile"
        echo "Good to go."
    fi
}
function unInstallTerlog() {
    echo "Removing credentials.."
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

    echo "Removing login script.."
    local tempFile
    tempFile=$PREFIX/tmp/termux-login.tmp
    sed '/^#/!{/terlog login-user/d;}' "$loginFile" >"$tempFile" && mv "$tempFile" "$loginFile"

    echo "Uninstalling Terlog.."
    if [ -e "$PATH"/terlog ]; then
        rm "$PATH"/terlog
    fi
    echo "Successfully Uninstalled."
}
function promtUninstall() {
    local confirmDel
    confirmDel=$1
    if [ "$confirmDel" == "-y" ]; then
        # start uninstallation
        unInstallTerlog
    else
        echo "It will uninstall terlog packages and credentials from termux"
        echo "Are you sure to uninstall?(y/n)"
        read -r confirmDel
        if [ "$confirmDel" == "y" ] || [ "$confirmDel" == "yes" ]; then
            unInstallTerlog
        fi
    fi
}
function ensureRequiredPackage() {
    # ensuring required pacakges
    if ! command -v openssl passwd >/dev/null 2>&1; then
        echo "Installing required package.."
        if pkg install openssl-tool -y >/dev/null 2>&1; then
            echo "Successfully installed"
        else
            echo "There was an error installing package, Exiting"
            kill -9 $PPID
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
        echo "Error: Password must be no longer than 48 characters."
        enterPasswordAndConfirm "$user_name"
    else
        echo "Confirm your Password:"
        read -r -s confirm_pass
        if [ "$user_pass" == "$confirm_pass" ]; then
            generateCredential "$user_name" "$user_pass"
        else
            echo "Password doesn't match"
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
            echo "User Already Exist. Choose another user name"
            enterUserName
        fi
    else
        echo "User name must contain only lowercase letters, digits, and underscores, must not start with a number, and must be 3 to 8 characters long."
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
    echo "$user_pass_encrypted"
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
        echo "Cancelling"
        return 1
    else
        echo "Invalid option"
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
            boilerText='##
## This script is sourced by /data/data/com.termux/files/usr/bin/login before executing shell.
##'
            sysText=$(<"$loginFile")
            if [ "$sysText" == "$boilerText" ]; then
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
        echo "No user Found"
        loginUser
    fi
}
function helpUser() {
    local helpText
    helpText="terlog [option]
possible options are:-
user-setup      : setup for first time
user-add        : add a new user
user-login      : log a user in
uninstall       : uninstall terlog
-h              : show help
--help          : same as -h

Description:-
'user-setup' option is for first time setup only. It eventually delete previous login details if exist.
'user-add' option is to add a new user to the database. It doesn't delete previous login details.
'user-login' option is to log a user in. This option is used by system at starting.
'uninstall' option is to uninstall this(terlog) package.
More options will be available soon.
"
    printf "\n"
    echo "$helpText"
    printf "\n\n"
}
# Main code starts here
if [ "$1" == "user-setup" ]; then
    startSetup
elif [ "$1" == "user-add" ]; then
    addUser
elif [ "$1" == "user-login" ]; then
    loginUser

elif [ "$1" == "uninstall" ]; then
    if [ "$2" == "-y" ]; then
        promtUninstall "-y"
    else
        promtUninstall
    fi
elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    helpUser
else
    echo 'Invalid Command. Try "terlog -h" for help.'
fi

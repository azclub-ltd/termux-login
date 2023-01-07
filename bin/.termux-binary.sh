#!/bin/bash
# Global variable
shadowFile=$PREFIX/etc/shadow

# check existing Credential
function checkExistingCredentialFile() {
    if [ -e "$PREFIX/etc/passwd" ] || [ -e "$shadowFile" ]; then
        credFileFound=true
        # check whether credential is in both file
        if [ -e "$PREFIX/etc/passwd" ] && [ -e "$shadowFile" ]; then
            credFileFoundCode=0
        elif [ -e "$PREFIX/etc/passwd" ]; then
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
                if rm "$PREFIX/etc/passwd" "$shadowFile"; then
                    removeMsg="Successfully removed"
                else
                    removeMsg="Failed to remove"
                fi
            elif [ "$credFileFoundCode" -eq 1 ]; then
                if rm "$PREFIX/etc/passwd"; then
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
        echo "Good to go."
        touch "$PREFIX"/etc/shadow
    fi
}
function ensureRequiredPackage() {
    local packPath
    packPath=$(which openssl)
    if [ "$packPath" == "" ]; then
        # package install
        echo "Installing missing package"
        pkg install -y openssl >/dev/null
    fi
}
# store credential function here
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
            read -ra userArray <<<"$(cut -d: -f- <<<"$eachLine")"
            break
        fi
    done <"$shadowFile"
    local passArray hash_type salt
    # Now extract password
    read -r passArray <<<"$(cut -d$ -f- <<<"${userArray[1]}")"
    hash_type=${passArray[0]}
    salt=${passArray[1]}
    user_pass_encrypted=$(openssl passwd -"$hash_type" -salt "$salt" "$upass")
    # Compare password
    if [ "$user_pass_encrypted" == "${userArray[1]}" ]; then
        echo "Now the stage is yours"
        exit 0
    fi
}
function addUser() {
    ensureRequiredPackage
    enterUserName
}
# create a function named inject
function inject() {
    if diff -q bin/non-modified "$PREFIX"/etc/termux-login.sh >/dev/null; then
        echo "terlog login" >"$PREFIX"/etc/termux-login.sh
    else
        echo "Already some login script found do you want to Override it?(y/n)"
    fi
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

    echo "function is under construction"
}
function helpUser() {
    local helpText
    helpText="terlog [option]
possible options are:-
setup           : setup for first time
add-user        : add a new user
login-user      : log a user in
-h              : show help
--help          : same as -h

Description:-
'setup' option is for first time setup only. It eventually delete previous login details if exist.
'add-user' option is to add a new user to the database. It doesn't delete previous login details.
'login-user' option is to log a user in. This option is used by system at starting.

More options will be available soon.
"
    printf "\n"
    echo "$helpText"
    printf "\n\n"
}
# Main code starts here
if [ "$1" == "setup" ]; then
    startSetup
elif [ "$1" == "add-user" ]; then
    addUser
elif [ "$1" == "login-user" ]; then
    loginUser
elif [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "" ]; then
    helpUser
fi

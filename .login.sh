#!/bin/sh
# Termux Login System
validatePass() {
  echo "Enter your Password:"
  read tpass
  if [[ $tpass == "pass" ]]; then
    clear
    echo "Welcome Sir, Now the stage is your"
  else
    echo "Password doesn't match"
    echo "Do you want to exit?(Y/n)"
    read cnfm
    if [[ $cnfm == "n" || $cnfm == "no" ]]; then
      echo "Try Re-logging"
      validateUser
    else
      echo "Exiting"
      kill -9 $PPID
    fi
  fi
}
validateUser() {
  echo "Enter Username: "
  read tuser
  if [[ $tuser == "root" ]]; then
    echo "Welcome root"
    validatePass
  else
    echo "No user found"
    echo "Do you want to exit?(Y/n)"
    read cnfm
    if [[ $cnfm == "n" || $cnfm == "no" ]]; then
      echo "Try Re-logging"
      validateUser
    else
      echo "Exiting"
      kill -9 $PPID
    fi
  fi
}
validateUser

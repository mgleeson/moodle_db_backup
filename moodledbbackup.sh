#!/bin/bash
######
# moodledbbackup.sh
# A Moodle MySQL database backup script
# which can gather db auth details from
# a specified Moodle config.php
# autotmatically and outputs date/time
# stampted sql files (optionally zipped)
# ideal for automation with cron
# @author: Matt Gleeson <matt@mattgleeson.net>
# @version: 1.03
# @license: GPL2
######

version="version: 1.03"

############
# Usage
usage="\
Usage: moodledbbackup [-h] [--help] [--moodlepath=PATH] [--backuppath=PATH][--sendemail=YES/NO]  
       [--emailaddress=email@domain][--version]"

		

##### ROOT CHECK
# must run as root
Check_if_root ()
{
if [ "$(id -u)" != "0" ]; then
    echo "current UID = $(id -u) -- Root UID = 0"
     echo "Must be root to run this script."
     exit 1
  fi
}

Check_if_root
##### END ROOT CHECK





#### Check for previous moodle config vars file
if [ -e ~/mdl_conf.sh ]; then
        rm -f ~/mdl_conf.sh
		echo "existing mdl_conf removed [OK]"
fi




##### PARAMETERS/ARGUMENTS PARSER
for PARAMS in "$@"
do
case $PARAMS in
    -m=*|--moodlepath=*)
    MOODLEPATH="${i#*=}"
    shift # past argument=value
    ;;
    -b=*|--backuppath=*)
    BACKUPPATH="${i#*=}"
    shift # past argument=value
    ;;
    -s=*|--sendemail=*)
    SENDEMAIL="${i#*=}"
    shift # past argument=value
    ;;
    --version | --v* )
         show_version=yes; shift ;;
      -- )     # Stop option processing
        shift; break ;;
      - )	# Use stdin as input.
        break ;;
      -* )
        echo "${usage}" 1>&2; exit 1 ;;
      * )
        break ;;

esac
done
echo "MOODLE PATH     = ${MOODLEPATH}"
echo "BACKUP PATH     = ${BACKUPPATH}"
echo "SENDING EMAIL?  = ${SENDEMAIL}"


if [[ -n $1 ]]; then
    echo "email1 specified: $1"
fi
if [[ -n $2 ]]; then
    echo "email2 specified: $1"
fi
if [[ -n $3 ]]; then
    echo "email3 specified: $1"
fi
##### END PARAMETERS/ARGUMENTS PARSER

##### check to see if email address specified if email set to yes
if [[ ! -n ${SENDEMAIL} ]]; then
	if [ ! -n "$1" ]; then
			echo "mysql_install() requires the root pass as its first argument"
			return 1;
		fi
fi


## Get the config details from the Moodle config.php file and put in temp file
grep -P -o '(?<=^\$CFG->)(\w*)\s*=\s?(?:\x27)(.*)(?:\x27)(?=\;)' ${MOODLEPATH}/config.php | sed 's/\s//g' | sed 's/\x27/"/g' >> ~/mdl_conf.sh
. ~/mdl_conf.sh


### 
_now=$(date +%Y-%m-%d--%H%M%S)
_file="${BACKUPPATH}${dbname}_backup_${_now}.sql"
_zipfile="${BACKUPPATH}${_file}.tar.gz"
_host=

#${mysqlpath}mysqldump -u ${dbuser} -p${dbpass} ${dbname} > "$_file"
#${mysqlpath}mysqldump -u ${mysqlUsername} -p${mysqlPasswd} ${mysqlDbName} > "$_file"


echo "backing up database with name: ${dbname}"
# TODO: test for mysqldump - eg which mysqldump
mysqldump -u ${dbuser} -p${dbpass} ${dbname} > "$_file"
tar -zcf ${_zipfile} ${_file} && rm -f $_file # remove sql file on zip complete if successful TODO: implement proper check for zip success
# optionally email file?

echo "${HOSTNAME} Moodle DB backup for ${dbname} at ${_now}" >> ~/msg.txt
echo "attempting to email backup using file: ${_zipfile}"

# TODO: test for mutt - eg which mutt
mutt -s "${HOSTNAME} Moodle DB backup for ${dbname} at ${_now}" -a ${_zipfile} -- $1 < ~/msg.txt

### Get rid of mdl_conf when finished
if [ -e ~/mdl_conf.sh ]; then
        rm -f ~/mdl_conf.sh
		echo "existing mdl_conf removed [OK]"
fi

### Get rid of msg.txt when finished
if [ -e ~/msg.txt ]; then
        rm -f ~/msg.txt.sh
		echo "existing msg.txt removed [OK]"
fi

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
# @version: 1.1
# @license: GPL2
######

# set -u # disabling for the moment to let some tests function



versionno="version: 1.1"

############
# Usage
usage="\
Usage: 	moodledbbackup [-h] [--help] [-m][--moodlepath=PATH] [-b][--backuppath=PATH] 
		[-e][--email=EMAILADDRESS] [--version]"

		
##### for when stuff go wrong
function err_exit
{
	echo ""
	echo "$@" 1>&2
	echo -e "[${red}error${rst}] at line: ${LINENO}"
	exit 1
}		

## For OK and ERROR output colouring
red='\033[01;31m'
blue='\033[01;34m'
green='\033[01;32m'
rst='\033[00m'
		
##### ROOT CHECK
# must run as root
Check_if_root ()
{
if [ "$(id -u)" != "0" ]; then
    echo "current UID = $(id -u) -- Root UID = 0"
     echo -e "[${red}ERROR!${rst}] Must be root to run this script."
     err_exit
  fi
}

Check_if_root
##### END ROOT CHECK



#### Check for previous moodle config vars file
if [ -e ~/mdl_conf.sh ]; then
        rm -f ~/mdl_conf.sh || err_exit
		echo -e "existing mdl_conf removed [${green}OK${rst}]"
fi


EMAILADDRESS=" " # setting default

##### PARAMETERS/ARGUMENTS PARSER
for PARAMS in "$@"
do
case $PARAMS in
    -m=*|--moodlepath=*)
    MOODLEPATH="${PARAMS#*=}"
	MOODLEPATH=${MOODLEPATH%/}
    shift 
    ;;
    -b=*|--backuppath=*)
    BACKUPPATH="${PARAMS#*=}"
	BACKUPPATH=${BACKUPPATH%/}
    shift 
    ;;
    -e=*|--email=*)
    EMAILADDRESS="${PARAMS#*=}"
    shift 
    ;;
    --version|-v*)
         echo ${versionno}; shift ;;
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

echo && echo
echo "MOODLE PATH     = ${MOODLEPATH}"
echo "BACKUP PATH     = ${BACKUPPATH}"
echo && echo


if [ ! -n "${MOODLEPATH}" ]; then
			 echo -e "[${red}ERROR!${rst}] no moodle path specified?"
			 err_exit;
fi
if [ ! -n "${BACKUPPATH}" ]; then
			 echo -e "[${red}ERROR!${rst}] no backup path specified?"
			 err_exit;
fi

if [ ! -d "${MOODLEPATH}" ]; then
			 echo -e "[${red}ERROR!${rst}] Moodle path does not exist!"
			 err_exit;
fi

if [ ! -d "${BACKUPPATH}" ]; then
			 echo -e "[${red}ERROR!${rst}] Backup path does not exist!"
			 err_exit;
fi

##### END PARAMETERS/ARGUMENTS PARSER



## Get the config details from the Moodle config.php file and put in temp file
grep -P -o '(?<=^\$CFG->)(\w*)\s*=\s?(?:\x27)(.*)(?:\x27)(?=\;)' ${MOODLEPATH}/config.php | sed 's/\s//g' > ~/mdl_conf.sh || err_exit
. ~/mdl_conf.sh


### 
export MYSQL_PWD="${dbpass}"  # <--- so we don't get that damn warning
_sitename=`echo "SELECT shortname FROM ${prefix}course WHERE sortorder = 1" | mysql ${dbname} -u ${dbuser} -h ${dbhost} -s -N | tr '/' '-' | tr ' ' '_'`
_now=$(date +%Y-%m-%d--%H%M%S)
_file="${BACKUPPATH}/${_sitename}_DB_${dbname}_backup_${_now}.sql"
_zipfile="${_file}.tar.gz"



#${mysqlpath}mysqldump -u ${dbuser} -p${dbpass} ${dbname} > "$_file"
#${mysqlpath}mysqldump -u ${mysqlUsername} -p${mysqlPasswd} ${mysqlDbName} > "$_file"

echo ""
echo "backing up database with name: ${dbname}"
# TODO: test for mysqldump - eg which mysqldump
mysqldump --max_allowed_packet=2G --skip-extended-insert --net_buffer_length=50000 -h ${dbhost} -u ${dbuser} ${dbname} > "${_file}"
     if [ $? -eq 0 ]; then # if OK
          echo -e "mysqldump [${green}OK${rst}]"
     else
          if [ $? != 127 ]; then
               echo -e "[${red}ERROR!${rst}] mysqldump operation failed for some reason"
               err_exit
          fi
     fi

echo "${_zipfile} ${_file}"
	 
## zip the sql file
tar -zcf ${_zipfile} ${_file} 
     if [ $? -eq 0 ]; then # if OK
          echo -e "tar [${green}OK${rst}]"
		  # remove sql file on zip complete if successful
		  rm -f ${_file} || err_exit
     else
               echo -e "[${red}ERROR!${rst}] something went wrong with tar"
               err_exit
          
     fi


echo ""

## optionally email dump file
if [[ ${EMAILADDRESS} != " " ]] ; then
	validemailregex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
	if [[ ${EMAILADDRESS} =~ ${validemailregex} ]] ; then
		echo -e "valid email address [${green}OK${rst}]"
		echo "${HOSTNAME} Moodle DB backup for ${dbname} at ${_now}" >> ~/msg.txt
		echo "attempting to email backup using file: ${_zipfile}"

		whichmutt=`which mutt`
		whichmutt=$?
		if [ $whichmutt != 0 ]
			then
				echo -e "[${red}ERROR!${rst}] Mutt is required for sending emails"
				echo "Please install if you wish to use email function"
				echo "On Debian based systems:"
				echo "sudo apt-get install mutt"
				echo "On RHEL based systems:"
				echo "yum install mutt"
				err_exit
			else
				mutt -s "${HOSTNAME} Moodle DB backup for ${dbname} at ${_now}" -a ${_zipfile} -- ${EMAILADDRESS} < ~/msg.txt || err_exit
		fi
	else
		echo -e "[${red}ERROR!${rst}] the supplied email address, ${EMAILADDRESS} is not a valid email address"
		err_exit
	fi
fi
### END EMAIL


### Get rid of mdl_conf when finished
if [ -e ~/mdl_conf.sh ]; then
        rm ~/mdl_conf.sh 
			if [ $? -eq 0 ]; then # if OK
			  echo -e "mdl_conf removed [${green}OK${rst}]"
			else
			   err_exit
			fi
fi
			


### Get rid of msg.txt when finished
if [ -e ~/msg.txt ]; then
        rm ~/msg.txt.sh
		if [ $? -eq 0 ]; then # if OK
			echo -e "existing msg.txt removed [${green}OK${rst}]"
		else
		   err_exit
		fi
		
fi

echo "done."

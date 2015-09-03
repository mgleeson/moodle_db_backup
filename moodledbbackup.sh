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
# @version: 1.05
# @license: GPL2
######

# set -u # disabling for the moment to let some tests function



versionno="version: 1.05"

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
	echo "error at line: ${LINENO}"
	exit 1
}		
		
##### ROOT CHECK
# must run as root
Check_if_root ()
{
if [ "$(id -u)" != "0" ]; then
    echo "current UID = $(id -u) -- Root UID = 0"
     echo "Must be root to run this script."
     err_exit
  fi
}

Check_if_root
##### END ROOT CHECK



#### Check for previous moodle config vars file
if [ -e ~/mdl_conf.sh ]; then
        rm -f ~/mdl_conf.sh || err_exit
		echo "existing mdl_conf removed [OK]"
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
			 echo "no moodle path specified?"
			 err_exit;
fi
if [ ! -n "${BACKUPPATH}" ]; then
			 echo "no backup path specified?"
			 err_exit;
fi
##### END PARAMETERS/ARGUMENTS PARSER



## Get the config details from the Moodle config.php file and put in temp file
grep -P -o '(?<=^\$CFG->)(\w*)\s*=\s?(?:\x27)(.*)(?:\x27)(?=\;)' ${MOODLEPATH}/config.php | sed 's/\s//g' | sed 's/\x27/"/g' > ~/mdl_conf.sh || err_exit
. ~/mdl_conf.sh


### 
_sitename=`echo "SELECT shortname FROM ${prefix}course WHERE sortorder = 1" | mysql ${dbname} -u ${dbuser} -p${dbpass} -s -N`
_now=$(date +%Y-%m-%d--%H%M%S)
_file="${BACKUPPATH}/${_sitename}_${dbname}_backup_${_now}.sql"
_zipfile="${_file}.tar.gz"
#_host=  # todo: allow for hosts other than localhost

#${mysqlpath}mysqldump -u ${dbuser} -p${dbpass} ${dbname} > "$_file"
#${mysqlpath}mysqldump -u ${mysqlUsername} -p${mysqlPasswd} ${mysqlDbName} > "$_file"

echo ""
echo "backing up database with name: ${dbname}"
# TODO: test for mysqldump - eg which mysqldump
mysqldump -u ${dbuser} -p${dbpass} ${dbname} > "${_file}"
     if [ $? -eq 0 ]; then # if OK
          echo "mysqldump [OK]"
     else
          if [ $? != 127 ]; then
               echo "ERROR! mysqldump not found?"
               err_exit
          fi
     fi

echo "${_zipfile} ${_file}"
	 
## zip the sql file
tar -zcf ${_zipfile} ${_file} 
     if [ $? -eq 0 ]; then # if OK
          echo "tar [OK]"
		  # remove sql file on zip complete if successful
		  rm -f ${_file} || err_exit
     else
               echo "ERROR! something went wrong with tar"
               err_exit
          
     fi


echo ""

## optionally email dump file
if [[ ${EMAILADDRESS} != " " ]] ; then
	validemailregex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
	if [[ ${EMAILADDRESS} =~ ${validemailregex} ]] ; then
		echo "valid email address [OK]"
		echo "${HOSTNAME} Moodle DB backup for ${dbname} at ${_now}" >> ~/msg.txt
		echo "attempting to email backup using file: ${_zipfile}"

		whichmutt=`which mutt`
		whichmutt=$?
		if [ $whichmutt != 0 ]
			then
				echo "Mutt is required for sending emails"
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
		echo "the supplied email address, ${EMAILADDRESS} is not a valid email address"
		err_exit
	fi
fi
### END EMAIL


### Get rid of mdl_conf when finished
if [ -e ~/mdl_conf.sh ]; then
        rm -f ~/mdl_conf.sh 
			if [ $? -eq 0 ]; then # if OK
			  echo "mdl_conf removed [OK]"
			else
			   err_exit
			fi
fi
			


### Get rid of msg.txt when finished
if [ -e ~/msg.txt ]; then
        rm -f ~/msg.txt.sh
		if [ $? -eq 0 ]; then # if OK
			echo "existing msg.txt removed [OK]"
		else
		   err_exit
		fi
		
fi

echo "done."

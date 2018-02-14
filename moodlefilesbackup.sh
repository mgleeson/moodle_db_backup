#!/bin/bash
######
# moodlefilesbackup.sh
# @author: Matt Gleeson <matt@mattgleeson.net>
# @version: 1.01
# @license: GPL2
######
versionno="version: 1.02"

# set -u

. /root/scripts/checkerr.inc.sh


############
## Usage
usage="\
Usage:  moodlefilesbackup [-h] [--help] [-m][--moodlepath=PATH] [-b][--backuppath=PATH]
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

which pv
checkerr "$_" "$?"

## must run as root
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

################################
## PARAMETERS/ARGUMENTS PARSER
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
        -d|--debug)
    DEBUG="TRUE"
        shift
    ;;
    --version|-v*)
         echo ${versionno}; shift ;;
      -- )     # Stop option processing
        shift; break ;;
      - )       # Use stdin as input.
        break ;;
      -* )
        echo "${usage}" 1>&2; exit 1 ;;
      * )
        break ;;

esac
done


if [ ! -n "${MOODLEPATH}" ]; then
                         echo "no moodle path specified?"
                         err_exit;
fi
if [ ! -n "${BACKUPPATH}" ]; then
                         echo "no backup path specified?"
                         err_exit;
fi


##### END PARAMETERS/ARGUMENTS PARSER

#############
## Get the config details from the Moodle config.php file and put in temp file
grep -P -o '(?<=^\$CFG->)(\w*)\s*=\s?(?:\x27)(.*)(?:\x27)(?=\;)' ${MOODLEPATH}/config.php | sed 's/\s//g' | sed 's/\x27/"/g' > ~/mdl_conf.sh || err_exit
. ~/mdl_conf.sh


#############
## vars
_sitename=`echo "SELECT shortname FROM ${prefix}course WHERE sortorder = 1" | mysql -h ${dbhost} ${dbname} -u ${dbuser} -p${dbpass} -s -N | tr '/' '-' | tr ' ' '_'`
_now=$(date +%Y-%m-%d--%H%M%S)
_files_zipfile="${BACKUPPATH}/${_sitename}_files_backup_${_now}.tar.gz"
_data_zipfile="${BACKUPPATH}/${_sitename}_moodledata_backup_${_now}.tar.gz"
## moodles such as bitnami stack moodles specify wwwroot programatically so this fails on them
# sitename="`echo ${wwwroot} | sed -e 's/^http:\/\///g' -e 's/^https:\/\///g' | tr '/' '-'`"
## end vars
#############



if [[ ${DEBUG} = "TRUE" ]] ; then
        echo || echo
        echo "DEBUG = ${DEBUG}"
        echo && echo
        echo "MOODLE PATH:                              ${MOODLEPATH}"
        echo "BACKUP PATH:                              ${BACKUPPATH}"
        echo "Site Name:                                        ${_sitename}"
        echo "Timestamp:                                        ${_now}"
        echo "Moodle files archive file:        ${_files_zipfile}"
        echo "Moodle data archive file:         ${_data_zipfile}"
        echo || echo
        echo "mdl_conf dump:"
        cat ~/mdl_conf.sh
        echo || echo
        echo -e "${warn} Note: backup has not occurred, omit debug parameter to execute backup"
        echo || echo
else
        ###################
        # start the backup
        # backup the moodle files
        echo -e "${info} Starting backup of ${MOODLEPATH} directory of site ${_sitename} timestamped at datetime $_now"
        #tar -vczf ${_files_zipfile} ${MOODLEPATH}
        tar zcf - ${MOODLEPATH} -P | pv -s $(du -sb ${MOODLEPATH} | awk '{print $1}') | gzip > ${_files_zipfile}
        checkerr "$_" "$?"

        echo || echo

        # backup moodledata
        echo -e "${info} Starting backup of ${dataroot} Moodle data directory of site ${_sitename} timestamped at datetime $_now"
        #tar -vczf ${_data_zipfile} ${dataroot}
        tar zcf - ${dataroot} -P | pv -s $(du -sb ${dataroot} | awk '{print $1}') | gzip > ${_data_zipfile}
        checkerr "$_" "$?"

        echo || echo

        # end of backup
        echo -e "${info} Ending backup of site ${_sitename} timestamped at datetime $_now"
        echo -e "_________________________________________________"
fi

### Get rid of mdl_conf when finished
if [ -e ~/mdl_conf.sh ]; then
        rm -f ~/mdl_conf.sh
                        if [ $? -eq 0 ]; then # if OK
                          echo "mdl_conf removed [OK]"
                        else
                           err_exit
                        fi
fi

## Clean up old backups
# echo
# echo deleting all .tar.gz files in ${BACKUPPATH} older than 5 days
# find ${BACKUPPATH} -type f -mtime +5 -exec rm *.tar.gz {} \;
# echo done.

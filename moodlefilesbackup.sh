#!/bin/bash
######
# moodlefilesbackup.sh
# @author: Matt Gleeson <matt@mattgleeson.net>
# @version: 1.2.1
# @license: GPL2
######
versionno="version: 1.2.1"

# set -u

############
## Usage
usage="\
Usage:  moodlefilesbackup [-h] [--help] [-m][--moodlepath=PATH] [-b][--backuppath=PATH]
                [-e][--email=EMAILADDRESS] [--version]"


##########################################################################
## ERR HANDLING & GENERAL PURPOSE GOODNESS

_date=$(date +%Y-%m-%d)

##### for when stuff go wrong and we have nowhere else to go
##### ...for the night is dark and full of errors
err_exit () 
{
	echo ""
	echo "$@" 1>&2
	echo -e "[\033[01;31m error \033[00m] at line: ${LINENO}"
	exit 1
}

#### where are we?
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${DIR}" ]]; then DIR="${PWD}"; fi


## TODO: do check/download function for other dependencies also 

#### include for error checker function and output colouring
load_checkerr ()
{
## is checkerr here?
if [ -e ${DIR}/checkerr.inc.sh ]; then
	echo -e "[\033[01;32m  OK  \033[00m]     checkerr found"
	. "${DIR}/checkerr.inc.sh"
else
	echo -e "[\033[01;31m  WARNING  \033[00m]     checkerr not found"
	echo -e "${info} don't worry, I get it for you... getting..."
	wget -O checkerr.inc.sh https://gist.githubusercontent.com/mgleeson/80876fd2a7779d9f96ca4a11996681f0/raw/checkerr.inc.sh
	. "${DIR}/checkerr.inc.sh"
	if [[ "${checkerr_loaded}" == "true" ]] 
		then
		echo -e "${ok} checkerr downloaded and loaded"
	else
		echo -e "[\033[01;31m  ERROR  \033[00m]      dependency not downloaded and not loaded: checkerr.inc.sh"
		err_exit
	fi
	
fi
}

load_checkerr
## TODO: make checker universal and pass script name via argument

## END ERR HANDLING
##########################################################################



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
        tar -vczf ${_files_zipfile} ${MOODLEPATH}
        checkerr "$_" "$?"

        echo || echo

        # backup moodledata
        echo -e "${info} Starting backup of ${dataroot} Moodle data directory of site ${_sitename} timestamped at datetime $_now"
	cache="${dataroot}/cache"
        datatemp="${dataroot}/temp"
	trashdir="${dataroot}/trashdir"
        echo -e "${info} Excluding ${cache}, ${datatemp}, and ${trashdir} from dataroot backup."
        tar --exclude=${cache} --exclude=${datatemp} --exclude=${trashdir} -vczf ${_data_zipfile} ${dataroot}
        checkerr "$_" "$?"

        echo || echo

        # end of backup
        echo -e "${info} Ending backup of site ${_sitename} timestamped at datetime $_now"
        echo -e "_________________________________________________"
fi

### Get rid of mdl_conf when finished
if [ -e ~/mdl_conf.sh ]; then
        rm ~/mdl_conf.sh
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

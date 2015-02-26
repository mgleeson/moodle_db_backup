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
# @version: 0.01
# @lastmodified: 04/02/2015 - not finished yet
# @license: GPL2
######
set -o nounset
set -o errexit

exit # remove this when complete - safety catch to prevent possible inadvertent abuse of your pets, loved ones, and general catastrophe

#todo check for root

# todo: check for exist of mdl_conf?  create and ensure root readable only? then include into this file, delele at end
# or dump output of command into this file? what is best practice?

# todo: do a getops thing to grab input for location of moodle install - use getops if more than one input neeted?  or just use $1 $2? Decisions...

# enter relevant values for the 3 variables below
mysqlUsername=""
mysqlPasswd="" # leave blank like this if you wish to be prompted for password instead
mysqlDbName=""
pathToMoodleConfig=""
#^ getting this from the below:

grep -P -o '(?<=^\$CFG->)(\w*)\s*=\s?(?:\x27)(\w*)(?:\x27)(?=\;)' ${pathToMoodleConfig}/config.php | sed 's/\s//g' | sed 's/\x27/"/g' >> ~/mdl_conf.sh
#^ if using dump to a file for this and not dumping to tmp or root home or something, make sure to have script check for where it is so that is not in insecure location

mysqlpath=""
backuppath=""
#^ need to get this from input and/or set from defaults...doing later

###
_now=$(date +%Y-%m-%d--%H%M%S)
_file="${backuppath}${mysqlDbName}_backup_$_now.sql"
${mysqlpath}mysqldump -u ${mysqlUsername} -p${mysqlPasswd} ${mysqlDbName} > "$_file"
tar -zcf ${_file}.tar.gz ${_file} 
#todo: delete .sql after tgz confirmed success
#todo: optionally email file?


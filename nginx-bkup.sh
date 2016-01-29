#!/bin/bash
# Webdirectory backup script by DecentM
# This script creates a compressed tarball from your webroot and your databases
# To be able to backup databases, you need a mysql user with these global privileges: SELECT, SHOW DATABASES, LOCK TABLES, RELOAD
####################################################################################################

add_option() {
        eval "$1="$2""
        optionsc=$(($optionsc + 1))
}
add_option "optionsc" "1";

#############################
## CONFIG START ## DO EDIT ##
#############################

## ! You must only edit the second argument in each of the add_option lines ! ##

## This is the date format, which will be used in backup names
add_option "bkupdate" '$(date +""%Y.%m.%d-%H%M.%S"")'

## The UNIX user the backups will be chown-ed to
## Default: root
add_option "bkupuser" 'root'

## The UNIX group the backups will be chown-ed to
## Default: root
add_option "bkupgroup" 'root'

## The UNIX file permission the backups will be chmod-ed to
## Default: 400
add_option "bkupmode" '400'

## The directory to store the backups in
## Default: /usr/share/nginx/backups
add_option "bkuproot" '/usr/share/nginx/backups'

## The directory that will be backed up
## Default: /usr/share/nginx/html
add_option "webroot" '/usr/share/nginx/html'

## How old should the latest backup be before it's deleted (days)
## Default: 7
add_option "filemage" '7'

## Gzip compression level. 1-9
## For example: 1 is fast, but produces bigger files, and 9 is slow, but produces smaller files
## Default: 9
add_option "gziplv" '9'

## The database user that will take the backup, and has the privileges listed on the top
add_option "dbus" 'database_username'

## The password for the database user
add_option "dbpw" 'database_password'

## List of databases that won't be backed up, delimited by an escaped pipe | character
## Default: Database\|information_schema\|performance_schema
add_option "ignoredbs" "Database\|information_schema\|performance_schema"

## Note: Later, I'd like to make all the options be loaded from an external textfile
###################################
## END OF CONFIG ## STOP EDITING ##
###################################

## SCRIPT START ## DO NOT EDIT ##
# Debug level can go from 0 to 5, and is set from the first argument
if [ -f $1 ]; then
        add_option "debuglv" "0";
else
        add_option "debuglv" "$1";
fi

# Save the current UNIX timestamp to be able to measure approximate run time
add_option "bkupstart" '$(date +""%s"")'

# Concatenate a random string to the backup filenames, so that even if the script is ran multiple times each second,
# the chance of overwriting files is minimal at best
add_option "bkupid" "$bkupdate-\#$RANDOM"

## Backup name
add_option "bkupfilename" "$bkupdate_backup_$bkupid"

# Define debugging functions
# If the debug level is more than 2, we pause at dbgps calls
dbgps() {
        if [ "$debuglv" -gt 2 ]; then
                read -n1 -r -p "Press any key to continue..."
                printf "\n"
        fi
}
# Return true if the debug level is more than 0
is_debug() {
        if [ "$debuglv" -gt 0 ]; then
                return $(true);
        else
                return $(false);
        fi
}
# Print all arguements if is_debug is true (used for verbose logging)
debuglog() {
        if is_debug; then
                echo $@
        fi
}
debuglog "Functions done"
dbgps

# Get the last part (delimeted by "/") of the webroot string to be used in filenames
bkupdir="$(echo $webroot | rev | cut -d "/" -f1 | rev)"

# Print all set variables by the script if the debig level is 5 or more
if is_debug; then
        ( set -o posix ; set ) | less | tail -$optionsc
        if [ $debuglv -gt 4 ]; then
                printf "Exiting, because debug level is $debuglv\n"
                exit
        fi
fi
debuglog "Passed all debug steps"
dbgps

echo "Backup ID is $bkupid"
printf "\n"
dbgps

# Switch to the backup root directory, so we don't have to use absolute paths every time
printf "Switching directory to "
cd $bkuproot
pwd
printf "\n"
dbgps

# Create a tarball with the previously defined ID and the webroot directory name
echo "Recursively backing up the following folders and files in $webroot:"
tar -cvf "$bkupid_$bkupdir-backup.tar" $webroot | cut -d "/" -f6 | uniq | sort
dbgps

# Use gzip to compress the created tarball using the strength set in the config
printf "\nCompressing it..."
gzip -$gziplv $bkupdir-backup_$bkupid.tar
debuglog "Gzip complete"
printf "\n"
debuglog "$webroot done"
dbgps

# Back up databases
# Note: Planned feature: if no database username is specified, skip this step
printf "\nBacking up database(s)...\n"

# Get all database names from the mysql server, and run the loop for every not skipped database
for I in $(mysql -u$dbus -p$dbpw -e 'show databases' -s --skip-column-names | grep -Ev "($ignoredbs)"); do
        dbgps

        # Dump the current database...
        echo "Dumping ${I}..."
        mysqldump -u$dbus -p$dbpw $I > "${I}_database-backup_$bkupid.sql";

        # ...and use gzip with the appropriate compression level
        echo "Compressing it..."
        gzip -$gziplv $bkupid\_database-backup_${I}.sql;
done
debuglog "Databases done"
dbgps

# Set permissions and ownership defined in the variable, recursively. (using full path & restricted to .gz files, as a precaution)
printf "\n"
echo "Setting permissions..."
chmod -R $bkupmode $bkuproot/*.gz
dbgps

# Remove files that are older then the config allows. (using full path & restricted to .gz files, as a precaution)
echo "Deleting these files from $bkuproot, that are older than a week..."
find $bkuproot/*.gz -mtime +$filemage -type f
find $bkuproot/*.gz -mtime +$filemage -type f -delete
echo "Done"
dbgps

# List the backup driectory, so that if the output is sent by mail, the recipient will have a good understanding on how many files there are
printf "\nPost-backup directory listing of backups/:\n"
ls -lt --block-size=MB
printf "\n"
dbgps

# Use "cd -" to switch back to the directory the user was at before running the script
echo "Switching back"
cd -
dbgps

# Finally, subtract the saved UNIX timestamp from the current one, and print it
printf "\n"
echo "Script took $(($(date +""%s"")-$bkupstart)) seconds to run"
dbgps
## END OF SCRIPT ##

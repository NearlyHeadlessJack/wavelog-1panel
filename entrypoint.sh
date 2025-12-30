#!/bin/bash

set -e

# Note: we don't just use "apache2ctl" here because it itself is just a shell-script wrapper around apache2 which provides extra functionality like "apache2ctl start" for launching apache2 in the background.
# (also, when run as "apache2ctl <apache args>", it does not use "exec", which leaves an undesirable resident shell process)

: "${APACHE_CONFDIR:=/etc/apache2}"
: "${APACHE_ENVVARS:=$APACHE_CONFDIR/envvars}"
if test -f "$APACHE_ENVVARS"; then
        . "$APACHE_ENVVARS"
fi

# Apache gets grumpy about PID files pre-existing
: "${APACHE_RUN_DIR:=/var/run/apache2}"
: "${APACHE_PID_FILE:=$APACHE_RUN_DIR/apache2.pid}"
rm -f "$APACHE_PID_FILE"

# create missing directories
# (especially APACHE_RUN_DIR, APACHE_LOCK_DIR, and APACHE_LOG_DIR)
for e in "${!APACHE_@}"; do
        if [[ "$e" == *_DIR ]] && [[ "${!e}" == /* ]]; then
                # handle "/var/lock" being a symlink to "/run/lock", but "/run/lock" not existing beforehand, so "/var/lock/something" fails to mkdir
                #   mkdir: cannot create directory '/var/lock': File exists
                dir="${!e}"
                while [ "$dir" != "$(dirname "$dir")" ]; do
                        dir="$(dirname "$dir")"
                        if [ -d "$dir" ]; then
                                break
                        fi
                        absDir="$(readlink -f "$dir" 2>/dev/null || :)"
                        if [ -n "$absDir" ]; then
                                mkdir -p "$absDir"
                        fi
                done

                mkdir -p "${!e}"
        fi
done

printenv
echo $DB_HOST

# Configure installation files from 1Panel
sed -i  's/<input type="text" id="db_hostname" placeholder="localhost" class="form-control" name="db_hostname" \/>/<input type="text" id="db_hostname" value="'${DB_HOST}'" class="form-control" name="db_hostname" \/>/' ./install/index.php
sed -i  's/<input type="text" id="db_name" placeholder="wavelog" class="form-control" name="db_name" \/>/<input type="text" id="db_name" value="'${DATABASE}'" class="form-control" name="db_name" \/>/' ./install/index.php
sed -i  's/<input type="text" id="db_username" placeholder="waveloguser" class="form-control" name="db_username" \/>/<input type="text" id="db_username" value="'${DATABASE_USERNAME}'" class="form-control" name="db_username" \/>/' ./install/index.php
sed -i  's/<input type="password" id="db_password" placeholder="supersecretpassword" class="form-control" name="db_password" \/>/<input type="password" id="db_password" value="'${DATABASE_PASSWORD}'" class="form-control" name="db_password" \/>/' ./install/index.php

printenv

service cron start

exec apache2 -DFOREGROUND "$@"


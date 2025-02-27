#! /bin/sh 

set -e

rm /var/www/html/include/ost-config.php
cp /var/www/html/include/container_config/ost-config.php /var/www/html/include/ost-config.php
chmod 0666 /var/www/html/include/ost-config.php

# Run the installer if the server config is not valid.
if kubectl get secret ${RELEASE_NAME} -o jsonpath='{@.data.ost\-config\.php}' | base64 -d | grep -q CONFIG-SIRI
then

    apachectl start || /bin/true
    sleep 2 

    # Wait for the MySQL instance to respond.
    while ! mysql --user="$MYSQL_USER" -h $MYSQL_PRIMARY_HOST -P $MYSQL_PRIMARY_PORT --password="$MYSQL_PASSWORD"  -e "show databases" > /dev/null
    do 
        echo "Waiting for MySQL"
        sleep 5
    done

    if ! mysql --user="$MYSQL_USER" -h $MYSQL_PRIMARY_HOST -P $MYSQL_PRIMARY_PORT --password="$MYSQL_PASSWORD"  -e "select * from ${MYSQL_DB}.ost_user" > /dev/null 
    then
        echo "Starting installer."
        curl -c /tmp/cookies.txt -X POST \
            -F s=prereq \
            http://localhost:80/setup/install.php

        echo "Running installer."
        curl -c /tmp/cookies.txt -X POST \
            -F s=install \
            -F name="$OST_NAME" \
            -F email="$OST_EMAIL" \
            -F fname="$OST_ADMIN_FIRST_NAME" \
            -F lname="$OST_ADMIN_LAST_NAME" \
            -F admin_email="$OST_ADMIN_EMAIL" \
            -F username="$OST_ADMIN_USERNAME" \
            -F passwd="$OST_ADMIN_PASSWORD" \
            -F passwd2="$OST_ADMIN_PASSWORD" \
            -F prefix="ost_" \
            -F dbhost="$OST_MYSQL_HOST" \
            -F dbname="$MYSQL_DB" \
            -F dbuser="$MYSQL_USER" \
            -F dbpass="$MYSQL_PASSWORD" \
            -F timezone="$OST_TIMEZONE" \
            http://localhost:80/setup/install.php

        echo "All done. Saving config."

        # Create or overwrite the saved config.
        kubectl create secret generic ${RELEASE_NAME}-installer-config --from-file=/var/www/html/include/ost-config.php -o yaml --dry-run=client \
            | kubectl apply -f -

    else
        # Restore the saved configuration to the file. 
        echo "Database already installed. Restoring saved configuration."
        kubectl get secret ${RELEASE_NAME}-installer-config -o jsonpath='{@.data.ost\-config\.php}' | base64 -d > /var/www/html/include/ost-config.php 
    fi

    # Overwrite the existing configmap. This is the deployed configuration.
    kubectl create secret generic ${RELEASE_NAME} --from-file=/var/www/html/include/ost-config.php -o yaml --dry-run=client \
        | kubectl apply -f -

else
    echo "Already installed."
fi

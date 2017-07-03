#!/bin/bash

function checkForFail() {
    if [ ! $? -eq 0 ]; then
        echo "command failed"
        exit 1
    fi
}

# Create a log pipe so non root can write to stdout
mkfifo -m 600 /tmp/logpipe
cat <> /tmp/logpipe 1>&2 &


# Disable Strict Host checking for non interactive git clones
mkdir -p -m 0700 /root/.ssh
echo -e "Host *\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

if [ ! -z "$SSH_KEY" ]; then
    echo $SSH_KEY > /root/.ssh/id_rsa.base64
    base64 -d /root/.ssh/id_rsa.base64 > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
    unset SSH_KEY
fi

if [ -z "$PRESERVE_PARAMS" ]; then
    if [ -f /var/www/html/app/config/parameters.yml.dist ]; then
        echo "    k8s_build_id: $PS_BUILD_ID" >> /var/www/html/app/config/parameters.yml.dist
    fi

    # Composer
    if [ -f /var/www/html/composer.json ]; then
cat > /var/www/html/app/config/config_prod.yml <<EOF
imports:
    - { resource: config.yml }
monolog:
    handlers:
        main:
            type: stream
            path:  "/tmp/logpipe"
            level: error
EOF

        if [ ! -z "$PS_ENVIRONMENT" ]; then
cat > /var/www/html/app/config/parameters.yml <<EOF
parameters:
    consul_uri: $PS_CONSUL_FULL_URL
    consul_sections:
        - 'parameters/base/common.yml'
        - 'parameters/base/$PS_APPLICATION.yml'
        - 'parameters/$PS_ENVIRONMENT/common.yml'
        - 'parameters/$PS_ENVIRONMENT/$PS_APPLICATION.yml'
    env(PS_ENVIRONMENT): $PS_ENVIRONMENT
    env(PS_APPLICATION): $PS_APPLICATION
    env(PS_BUILD_ID): $PS_BUILD_ID
    env(PS_BUILD_NR): $PS_BUILD_NR
    env(PS_BASE_HOST): $PS_BASE_HOST
    env(NEW_RELIC_API_URL): $NEW_RELIC_API_URL
EOF
        fi

        cd /var/www/html
        mkdir -p /var/www/html/var
        /usr/bin/composer run-script build-parameters --no-interaction
        checkForFail

        if [ -f /var/www/html/bin/console ]; then
            /var/www/html/bin/console cache:clear --no-warmup --env=prod
            checkForFail
            /var/www/html/bin/console cache:warmup --env=prod
            checkForFail
        fi
    fi

fi

if [ -z "$1" ]
then
    trap : TERM INT; sleep infinity & wait
else
    eval $@
fi

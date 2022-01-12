FROM debian:stretch-slim

ENV php_conf /etc/php/7.1/cli/php.ini
ENV DEBIAN_FRONTEND noninteractive
ENV composer_hash 669656bab3166a7aff8a7506b8cb2d1c292f042046c5a994c43155c0be6190fa0355160742ab2e1c88d40d5be660b410

RUN apt-get update && apt-get install -y -q --no-install-recommends \
    apt-transport-https \
    lsb-release \
    gnupg2 \
    wget \
    tzdata \
    curl \
    apt-utils \
    ca-certificates \
    dirmngr


### Install .NET 5. Instructions taken from: https://docs.microsoft.com/en-us/dotnet/core/install/linux-debian#debian-9-

RUN wget -O - https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.asc.gpg && \
    mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/ && \
    wget https://packages.microsoft.com/config/debian/9/prod.list && \
    mv prod.list /etc/apt/sources.list.d/microsoft-prod.list && \
    chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg && \
    chown root:root /etc/apt/sources.list.d/microsoft-prod.list

RUN apt-get update && apt-get install -y -q --no-install-recommends \
    apt-transport-https \
    dotnet-sdk-5.0



RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ stretch main" > /etc/apt/sources.list.d/php.list

RUN echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list && \
    wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add -

RUN apt-get update && apt-get install -y -q --no-install-recommends \
    php7.1-cli \
    php7.1-mysql \
    php7.1-bcmath \
    php7.1-gd \
    php7.1-curl \
    php7.1-json \
    php7.1-mcrypt \
    php7.1-cli \
    php7.1-apcu \
    php7.1-imagick \
    php7.1-intl \
    php7.1-opcache \
    php7.1-mongodb \
    php7.1-mbstring \
    php7.1-xml \
    php7.1-zip \
    php7.1-igbinary \
    net-tools \
    supervisor \
    openssh-client \
    newrelic-php5 \
    newrelic-sysmond \
    git \
    librabbitmq-dev \
    make \
    php-pear \
    php7.1-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* \
    && yes '' | pecl install amqp

RUN mkdir -p /var/log/supervisor

ADD conf/supervisord.conf /etc/supervisord.conf

#RUN useradd -ms /bin/bash worker

# tweak php and php-cli config
RUN sed -i \
    -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" \
    -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" \
    -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" \
    -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" \
    -e "s/;error_log\s*=\s*syslog/error_log = \/dev\/stdout/g" \
    -e "s/memory_limit\s*=\s*128M/memory_limit = 3072M/g" \
    -e "s/;date.timezone\s*=/date.timezone = Europe\/Oslo/g" \
    -e "s/max_execution_time\s*=\s*30/max_execution_time = 300/g" \
    -e "s/max_input_time\s*=\s*60/max_input_time = 300/g" \
    -e "s/default_socket_timeout\s*=\s*60/default_socket_timeout = 300/g" \
    ${php_conf}

# Cleanup some files and remove comments
RUN find /etc/php/7.1/cli/conf.d -name "*.ini" -exec sed -i -re '/^[[:blank:]]*(\/\/|#|;)/d;s/#.*//' {} \; && \
    find /etc/php/7.1/cli/conf.d -name "*.ini" -exec sed -i -re '/^$/d' {} \;

# Configure php opcode cache
RUN echo "opcache.enable=1" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.enable_cli=1" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.consistency_checks=0" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.file_cache_consistency_checks=0" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.file_cache=/var/tmp" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.validate_timestamps=0" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.max_accelerated_files=1000000" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.memory_consumption=1024" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.interned_strings_buffer=8" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.revalidate_freq=60" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "extension=amqp.so" >> /etc/php/7.1/cli/php.ini

# tweak php-cli and php-fpm config
RUN sed -i \
    -e "s/memory_limit\s*=.*/memory_limit=12G/g" \
    /etc/php/7.1/cli/php.ini

RUN composer_hash=$(wget -q -O - https://composer.github.io/installer.sig) && \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === '${composer_hash}') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php --install-dir=/usr/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    apt-get update \
    && apt-get install -y -q --no-install-recommends \
    wget \
    net-tools \
    vim \
    tmux \
    tzdata \
    locales \
    localepurge \
    nano

# Install no locale
RUN sed -i 's/# nb_NO.UTF-8 UTF-8/nb_NO.UTF-8 UTF-8/' /etc/locale.gen && \
    ln -sf /etc/locale.alias /usr/share/locale/locale.alias && \
    locale-gen nb_NO.UTF-8

RUN sed -i "s|USE_DPKG|#USE_DPKG|" /etc/locale.nopurge && localepurge

# Add Scripts
ADD scripts/start.sh /start.sh
RUN chmod 755 /start.sh

CMD ["/start.sh"]
ENTRYPOINT ["/start.sh"]
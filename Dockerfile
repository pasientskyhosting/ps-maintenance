FROM pasientskyhosting/ps-worker
MAINTAINER Andreas Krüger <ak@patientsky.com>

RUN composer_hash=$(wget -q -O - https://composer.github.io/installer.sig) && \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === '${composer_hash}') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php --install-dir=/usr/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    apt-get update \
    && apt-get install -y -q --no-install-recommends \
    wget \
    vim \
    nano

ADD scripts/start.sh /start.sh
RUN chmod 755 /start.sh

CMD ["/start.sh"]

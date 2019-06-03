FROM php:7.2-cli-stretch as clearinghouse-base

ARG container_version=1.0
ARG container_maintainer=roger.mahler@umu.se
ARG container_build_date=2019-06-01

RUN apt-get update && \
    apt-get install -y \
       apt-transport-https \
       lsb-release ca-certificates \
       libpq-dev && \
	docker-php-ext-install pdo pdo_pgsql

FROM clearinghouse-base as builder-base

RUN apt-get install -y  \
       wget \
       curl \
       gnupg \
       unzip \
       git

RUN curl -sL https://deb.nodesource.com/setup_11.x  | bash - && \
    apt-get -y install nodejs

RUN mkdir -p /tmp/deploy /tmp/deploy/public && \
    cd /tmp && \
    git clone https://github.com/humlab/sead_clearinghouse.git && \
    rm -rf ./sead_clearinghouse/src/vendor && \
    cd /tmp/sead_clearinghouse/src && \
    wget -q -O ./composer.phar https://getcomposer.org/composer.phar && \
    php ./composer.phar install && \
    php ./composer.phar dump-autoload -o

RUN cd /tmp/sead_clearinghouse && \
    npm install && \
    npx webpack --mode production --config webpack.config.js --no-color

RUN mkdir -p /tmp/deploy && \
    cp -r /tmp/sead_clearinghouse/public /tmp/deploy/public && \
    cp -r /tmp/sead_clearinghouse/src/api /tmp/deploy/public/ && \
    cp -r /tmp/sead_clearinghouse/src/vendor /tmp/deploy/public/ && \
    mkdir -p /tmp/deploy/public/api/api-cache

FROM clearinghouse-base

LABEL maintainer="${clearinghouse_maintainer}"
LABEL build_date="${container_build_date}"

WORKDIR /

RUN mkdir -p /home/clearinghouse/

COPY --from=builder-base /tmp/deploy/* /home/clearinghouse/

RUN groupadd -r clearinghouse_group && \
    useradd -r -g clearinghouse_group clearinghouse_user && \
    chown -R clearinghouse_group:clearinghouse_user /home/clearinghouse

WORKDIR /home/clearinghouse/public

EXPOSE 8060

CMD exec php -S 0.0.0.0:8060 -t .


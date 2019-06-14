FROM php:7.2-cli-stretch

ENV WEB_PORT=88
ENV XDEBUG_PORT=9000

RUN apt-get update && \
    apt-get install -y \
       apt-transport-https \
       lsb-release ca-certificates \
       libpq-dev && \
	docker-php-ext-install pdo pdo_pgsql

COPY ./dev-entry-point.bash /usr/bin/dev-entry-point.bash

RUN chmod +x /usr/bin/dev-entry-point.bash

EXPOSE $WEB_PORT $XDEBUG_PORT

CMD [ "/bin/bash", "/usr/bin/dev-entry-point.bash" ]

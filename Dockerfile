FROM alpine:latest

COPY ./content /workdir/

ENV CONF_FILE_NAME=""
ENV UPDATE_TIME=""
ENV INSTALL_VERSION="latest"
ENV UPDATE_GEODATA="true"
ENV TZ="UTC"

RUN apk add --no-cache curl runit tzdata \
    && chmod +x /workdir/*.sh /workdir/service/*/run \
    && /workdir/install.sh \
    && /workdir/install_geodata.sh \
    && ln -s /workdir/service/* /etc/service/

VOLUME /config

ENTRYPOINT ["sh","-c","/workdir/entrypoint.sh"]
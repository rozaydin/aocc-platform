FROM alpine:3.23
RUN apk add --no-cache pgbouncer \
    && adduser -D -H -s /sbin/nologin pgbouncer \
    && mkdir -p /etc/pgbouncer \
    && chown -R pgbouncer:pgbouncer /etc/pgbouncer
COPY --chown=pgbouncer:pgbouncer pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY --chown=pgbouncer:pgbouncer entrypoint.sh /entrypoint.sh
USER pgbouncer
ENTRYPOINT ["/entrypoint.sh"]

FROM postgres:13

ADD https://github.com/adempiere/adempiere/releases/download/3.9.4/adempiere_ui_postgresql_seed.tar.gz /tmp/adempiere_postgresql_seed.tar.gz

COPY --chown=1 initdb.sh /docker-entrypoint-initdb.d
COPY --chown=1 after_run/*.sql /tmp/after_run/

RUN chmod +x /docker-entrypoint-initdb.d/initdb.sh && \
	tar -xvf /tmp/adempiere_postgresql_seed.tar.gz && \
	rm /tmp/adempiere_postgresql_seed.tar.gz

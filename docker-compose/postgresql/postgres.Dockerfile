FROM postgres:13

# The File will be downloaded directly. Not need to do it manually.
# ADD https://github.com/adempiere/adempiere/releases/download/3.9.4/adempiere_ui_postgresql_seed.tar.gz /tmp/adempiere_postgresql_seed.tar.gz

# Command "wget" will be used for downloading the standard Adempiere Database in initdb.sh, instead of copying it into the container.
RUN echo 'Update APT package handling utility'
RUN  apt-get update
RUN echo 'Install wget'
RUN apt-get install -y wget
RUN echo 'wget installed'

COPY --chown=1  initdb.sh /docker-entrypoint-initdb.d
#COPY --chown=1  after_run /tmp/after_run
#RUN chmod +x /docker-entrypoint-initdb.d/initdb.sh && \
#	tar -xvf /tmp/adempiere_postgresql_seed.tar.gz && \
#	rm /tmp/adempiere_postgresql_seed.tar.gz

RUN chmod +x /docker-entrypoint-initdb.d/initdb.sh

FROM jpuhlman/koji-base-clear:latest 
STOPSIGNAL SIGTERM
RUN mkdir -p /usr/share/koji-docker
COPY builder-scripts/setup-builder.sh  \
     /usr/share/koji-docker/
RUN mkdir -p /usr/sbin/
COPY install-scripts/hostenv.sh /usr/sbin/
RUN mkdir -p /etc/mock
COPY configs/mock/* /etc/mock/
RUN chmod 755 /usr/bin/hostenv.sh
RUN chmod 755 /usr/share/koji-docker/*.sh
RUN sed -i  /usr/lib/python2.7/site-packages/koji/daemon.py -e 's,maxload\ =\ 4.0,maxload\ =\ 8.0,'
CMD [ "/usr/share/koji-docker/setup-builder.sh" ]

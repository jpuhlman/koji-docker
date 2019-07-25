FROM clearlinux:latest
ENV container docker
RUN swupd bundle-add sudo koji lua-basic
STOPSIGNAL SIGRTMIN+3
RUN mkdir -p /tmp/rpms/
COPY rpms/*.rpm /tmp/rpms/
RUN rpm -ihv --nodeps /tmp/rpms/*.rpm
RUN rm -rf /tmp/rpms/ 
RUN mkdir -p /usr/share/koji-docker
COPY bootstrap-build.sh  \
     deploy-koji-builder.sh \
     deploy-koji-docker.sh \
     gencert.sh \
     globals.sh \
     parameters.sh \
     app.list \
     package-add.sh \
       /usr/share/koji-docker/
RUN chmod 755 /usr/share/koji-docker/*.sh
RUN mkdir -p /etc/systemd/system/
COPY koji-setup.service /etc/systemd/system/
RUN systemctl enable koji-setup
RUN echo "root:$(echo 'password' | openssl passwd -1 -stdin):18099::::::" >> /etc/shadow
CMD [ "/sbin/init" ]

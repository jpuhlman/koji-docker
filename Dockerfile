FROM clearlinux:latest
ENV container docker
RUN swupd bundle-add sudo koji lua-basic
STOPSIGNAL SIGRTMIN+3
RUN mkdir -p /tmp/rpms/
RUN echo "If this next step fails, run ./build-scripts/build-rpm.sh"
COPY rpms/*.rpm /tmp/rpms/
RUN rpm -ihv --nodeps /tmp/rpms/*.rpm
RUN rm -rf /tmp/rpms/ 
RUN mkdir -p /usr/share/koji-docker
COPY install-scripts/bootstrap-build.sh  \
     install-scripts/deploy-koji-builder.sh \
     install-scripts/deploy-koji-docker.sh \
     install-scripts/gencert.sh \
     install-scripts/globals.sh \
     install-scripts/parameters.sh \
     install-scripts/package-add.sh \
     install-scripts/deploy-mash.sh \
     install-scripts/mash.sh \
     configs/app.list \
     /usr/share/koji-docker/
RUN mkdir -p /usr/sbin/
COPY install-scripts/hostenv.sh /usr/sbin/
RUN chmod 755 /usr/bin/hostenv.sh
RUN chmod 755 /usr/share/koji-docker/*.sh
RUN mkdir -p /etc/systemd/system/
COPY container-services/koji-setup.service /etc/systemd/system/
RUN systemctl enable koji-setup
RUN echo "root:$(echo 'password' | openssl passwd -1 -stdin):18099::::::" >> /etc/shadow
CMD [ "/sbin/init" ]

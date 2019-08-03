FROM clearlinux:latest
ENV container docker
RUN swupd bundle-add sudo koji lua-basic inotify-tools
STOPSIGNAL SIGRTMIN+3
RUN mkdir -p /tmp/rpms/
RUN echo "If this next step fails, run ./build-scripts/build-rpm.sh"
COPY rpms/*.rpm /tmp/rpms/
RUN rpm -ihv --nodeps /tmp/rpms/*.rpm
RUN rm -rf /tmp/rpms/ 
RUN swupd bundle-add diffutils
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
     install-scripts/watch-*.sh \
     install-scripts/add-hosts.sh \
     install-scripts/user-add.sh \
     configs/app.list \
     configs/user.list \
     /usr/share/koji-docker/
RUN mkdir -p /usr/sbin/
COPY install-scripts/hostenv.sh /usr/sbin/
RUN chmod 755 /usr/bin/hostenv.sh
RUN chmod 755 /usr/share/koji-docker/*.sh
RUN mkdir -p /etc/systemd/system/
COPY container-services/koji-setup.service \
     container-services/watch*.service \
     /etc/systemd/system/
RUN systemctl enable koji-setup
RUN systemctl disable swupd-update
RUN mkdir -p /etc/sudoers.d/
RUN echo "kojiadmin  ALL=NOPASSWD: /usr/bin/hostenv.sh" | tee -a /etc/sudoers.d/visudo
RUN echo "root:$(echo 'password' | openssl passwd -1 -stdin):18099::::::" >> /etc/shadow
CMD [ "/sbin/init" ]

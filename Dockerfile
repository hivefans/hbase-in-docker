FROM ubuntu

WORKDIR /root/install

COPY ./install /root/install/

RUN bash /root/install/scripts/setup-prerequisites.sh

RUN mkdir -p /data && chmod a+w /data
RUN bash /root/install/scripts/install-hadoop.sh
RUN bash /root/install/scripts/install-hbase.sh
RUN rm -rf /root/install/archives
RUN bash /root/install/scripts/setup-autostart.sh

ENV container=docker

CMD ["/sbin/init"]

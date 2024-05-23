FROM alpine:latest

RUN apk --update --no-cache add ipset iptables iptables-legacy wget bash tzdata
RUN ln -sf /proc/1/fd/1 /var/log/block.log

COPY scripts/block_init.sh /
COPY scripts/block.sh /

ENTRYPOINT ["/block_init.sh"]
CMD ["/block.sh", "start"]

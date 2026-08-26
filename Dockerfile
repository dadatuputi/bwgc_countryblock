# Pinned to a branch rather than :latest so a rebuild is reproducible and a
# major version bump is a reviewable change. Security patches within the branch
# still arrive automatically: rebuild-on-updates.yml rebuilds when packages fall
# behind, and check-base-image-support.yml warns before the branch leaves
# support.
FROM alpine:3.24

RUN apk --update --no-cache add ipset iptables iptables-legacy curl bash tzdata
RUN ln -sf /proc/1/fd/1 /var/log/block.log

COPY scripts/block_init.sh /
COPY scripts/block.sh /

ENTRYPOINT ["/block_init.sh"]
CMD ["/block.sh", "start"]

# Pinned to a branch rather than :latest so a rebuild is reproducible and a
# major version bump is a reviewable change. Security patches within the branch
# still arrive automatically: rebuild-on-updates.yml rebuilds when packages fall
# behind, and check-base-image-support.yml warns before the branch leaves
# support.
FROM alpine:3.24

# apk upgrade first: the base image's own packages (apk-tools, for one) can lag
# the repository index, and the nightly rebuild only helps if it brings them up
# to date too.
RUN apk upgrade --no-cache && apk add --no-cache ipset iptables iptables-legacy curl bash tzdata
RUN ln -sf /proc/1/fd/1 /var/log/block.log

COPY scripts/block_init.sh /
COPY scripts/block.sh /

ENTRYPOINT ["/block_init.sh"]
CMD ["/block.sh", "start"]

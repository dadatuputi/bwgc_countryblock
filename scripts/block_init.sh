#! /bin/sh

LOG=/var/log/block.log

sed -i "/bash \\/block\\.sh update/d" /etc/crontabs/root
printf "Removing any existing crontab entries for block.sh\n" >> $LOG
echo "$COUNTRYBLOCK_SCHEDULE bash /block.sh update" >> /etc/crontabs/root
printf "Adding block.sh crontab entry (%b)\n" "$COUNTRYBLOCK_SCHEDULE" >> $LOG
crond -d 8
printf "Starting the cron daemon\n" >> $LOG

# Execute the entrypoint
exec "$@"

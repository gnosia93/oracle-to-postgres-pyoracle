#! /bin/bash
PRIVATE_IP_ADDR=`aws ec2 describe-instances --region=ap-northeast-2 \
--filters "Name=tag:Name,Values=tf_oracle_11xe" \
--query "Reservations[*].Instances[*].{PrivateIpAddress:PrivateIpAddress}" \
--output=text`

sed -i "s/<your-oracle-private-ip>/$PRIVATE_IP_ADDR/g" $ORACLE_HOME/tnsnames.ora
sqlplus system/manager@xe @create-schema.sql
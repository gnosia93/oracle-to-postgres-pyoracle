#! /bin/bash
function find_replace_oracle_ip() {
  #grep $ORACLE_HOME/tnsnames.ora -e '<your-oracle-private-ip>'
  echo "find and replace oracle ip ... $1 $2 $3"
  grep $1 -e $2
  if [ $? == 0 ]; then
    echo "finding oracle ec2 private ip ...."
    PRIVATE_IP_ADDR=`aws ec2 describe-instances --region=ap-northeast-2 \
    --filters "Name=tag:Name,Values=${3}" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].{PrivateIpAddress:PrivateIpAddress}" \
    --output=text`

    sed "s/$2/$PRIVATE_IP_ADDR/g" $1 > $1.bak
    mv $1.bak $1
  fi
}

find_replace_oracle_ip $ORACLE_HOME/tnsnames.ora "<11xe-oracle-private-ip>" tf_oracle_11xe
find_replace_oracle_ip $ORACLE_HOME/tnsnames.ora "<19c-oracle-private-ip>" tf_oracle_19c

sqlplus system/manager@xe @oracle-schema-11xe.sql
sqlplus system/manager@pdb1 @oracle-schema-19c.sql

cp config.ini.ec2 config.ini
find_replace_oracle_ip /home/ec2-user/pyoracle/config.ini "<11xe-oracle-private-ip>" tf_oracle_11xe
find_replace_oracle_ip /home/ec2-user/pyoracle/config.ini "<19c-oracle-private-ip>" tf_oracle_19c



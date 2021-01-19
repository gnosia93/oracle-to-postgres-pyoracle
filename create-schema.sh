aws ec2 describe-instances --region=ap-northeast-2 --filters "Name=Instance,Values=tf_oracle_11xe"

sqlplus system/manager @create-schema.sql
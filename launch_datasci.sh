#!/bin/bash 

#launch_datasci.sh
#by Joe Hahn, jmh.datasciences@gmail.com, 9 August 2017.
#
#launch the datasci instance that hosts the jupyter dashboard
#
#To execute:    ./launch_datasci.sh


#m3.xlarge (4cpu & 15Gb) costs $6.38/day=$190/month
#m4.2xlarge (8cpu & 32Gb) costs $10.34/day=$310/month
#using EMR bumps cost up by 23%
#athena and s3 charges are negligible

#launch one datasci instance as a single-node emr cluster
aws emr create-cluster \
    --profile "oneoff" \
    --auto-scaling-role EMR_AutoScaling_DefaultRole \
    --ec2-attributes '{"KeyName":"datasci","InstanceProfile":"EMR_EC2_DefaultRole","SubnetId":"subnet-087c7641"}' \
    --service-role EMR_DefaultRole \
    --enable-debugging \
    --release-label emr-5.7.0 \
    --log-uri "s3n://spark-one-off/datasci/" \
    --name "datasci" \
    --tags "Name=datasci" \
    --instance-groups '[{"InstanceCount":1,"InstanceGroupType":"MASTER","InstanceType":"m3.xlarge","Name":"Master - 1"}]' \
    --region "us-west-2" \
    --bootstrap-action Path="s3://spark-one-off/scripts/bootstrap.sh" \
    --steps Type=CUSTOM_JAR,Name=CustomJAR,ActionOnFailure=CONTINUE,Jar=s3://us-west-2.elasticmapreduce/libs/script-runner/script-runner.jar,Args=["s3://spark-one-off/scripts/provision_datasci.sh"] \
    --no-auto-terminate \
    --no-termination-protected

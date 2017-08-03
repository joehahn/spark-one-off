#!/bin/bash 
#
#piggyback.sh
#by Joe Hahn, jmh.datasciences@gmail.com, 3 August 2017.
#this is then executed on master after hadoop is launched.
#
#To execute:    ./piggyback.sh

echo 'running piggyback.sh...'
echo $(whoami)
echo $(pwd)

#install git
echo 'installing git...'
sudo yum install -y git-all

#install and setup locate
echo 'installing locate...'
sudo yum install -y mlocate
sudo updatedb

#unpack the spark-one-off repo, with permissions set so that user=jupyter
#can write notebooks to this directory
echo 'installing spark-one-off...'
bucket_name="spark-one-off"
aws s3 cp s3://$bucket_name/spark-one-off.tar.gz /home/hadoop/.
cd /home/hadoop
gunzip --force spark-one-off.tar.gz
tar -xvf spark-one-off.tar
chmod 777 spark-one-off
cd spark-one-off

#copy data from s3 to hdfs

#execute spark job
logj4="spark.driver.extraJavaOptions=-Dlog4j.configuration=file:./log4j.properties"
#spark-submit --master yarn --conf "$logj4" mlp.py

#this copies hdfs output to s3 and then plops an athena table schema on that data
#./make_athena_tables.sh

##setup & start jupyter inside screen session, see https://jupyter-notebook.readthedocs.io/en/stable/public_server.html
##jupyter's password=mlp
#export PATH=/emr/miniconda2/bin:$PATH
#jupyter notebook --generate-config
#cp jupyter_notebook_config.json /home/hadoop/.jupyter/.
#screen -dmS jupyter_sesh jupyter notebook --ip 0.0.0.0 --no-browser --port 8765

#done
echo 'piggyback.sh done!'

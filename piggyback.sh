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

#unpack the spark-one-off repo, with permissions set so that user=jupyter
#can read & write notebooks to this directory
echo 'installing spark-one-off repo...'
bucket_name="spark-one-off"
aws s3 cp s3://$bucket_name/spark-one-off.tar.gz /home/hadoop/.
cd /home/hadoop
gunzip --force spark-one-off.tar.gz
tar -xvf spark-one-off.tar
chmod 777 spark-one-off
cd spark-one-off
chmod 777 *.ipynb

#create training data and store in hdfs
echo 'generating training data...'
echo "working directory = $(pwd)"
/emr/miniconda2/bin/python ./make_training_data.py
hdfs dfs -rm -R -f -skipTrash data
hdfs dfs -mkdir -p data/train
hdfs dfs -put -f data/train.txt data/train/train.txt

#use spark to fit mlp models to training data, and map those models' decision surfaces
#executing on four m4.2xlarge instances having 8cpus 32Gb each
echo 'executing mlp.py...'
logj4="spark.driver.extraJavaOptions=-Dlog4j.configuration=file:./log4j.properties"
PYSPARK_PYTHON=/emr/miniconda2/bin/python spark-submit --master yarn --conf "$logj4" \
    --num-executors 29 --executor-cores 4 --executor-memory 4G --driver-memory 2G mlp.py
hdfs dfs -cat data/grid/*.csv | wc

#copy hdfs input & output data to s3
echo 'copying hdfs data to s3...'
aws s3 rm --recursive s3://spark-one-off/data
hadoop distcp data s3a://spark-one-off/data
aws s3 ls --recursive s3://spark-one-off/data

#get aws access keys from s3, and forward-slash-encode any slashes in the secret key...crap doesnt work :(
echo "getting aws access keys from s3..."
mkdir private
aws s3 cp s3://spark-one-off/accessKeys.csv private/accessKeys.csv

#plop athena table schemas on s3 datasets
./athena_tables.sh

##uncomment to run jupyter dashboard on master node
##create user jupyter
#echo "creating user jupyter..."
#sudo adduser jupyter
#
##prep & start jupyter inside of a screen session, as user=jupyter
##jupyter's password=oneoff, see https://jupyter-notebook.readthedocs.io/en/stable/public_server.html
#echo 'starting jupyter...'
#sudo -u jupyter /emr/miniconda2/bin/jupyter notebook --generate-config
#sudo -u jupyter cp jupyter_notebook_config.json /home/jupyter/.jupyter/.
#sudo -u jupyter screen -dmS jupyter_sesh /emr/miniconda2/bin/jupyter notebook --ip 0.0.0.0 --no-browser --port 8765

#update locates database
echo 'updating locate...'
sudo updatedb

#sleep for 15 minutes, then cluster terminates
echo 'piggyback sleeping for 15 minutes...'
echo $(date)
sleep 900
echo $(date)

#done
echo 'piggyback.sh done!'

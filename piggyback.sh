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
echo 'installing spark-one-off...'
bucket_name="spark-one-off"
aws s3 cp s3://$bucket_name/spark-one-off.tar.gz /home/hadoop/.
cd /home/hadoop
gunzip --force spark-one-off.tar.gz
tar -xvf spark-one-off.tar
chmod 777 spark-one-off
cd spark-one-off
chmod 777 *.ipynb

#create training data
/emr/miniconda2/bin/python ./make_training_data.py

#copy training data to hdfs and s3
hdfs dfs -mkdir -p data
hdfs dfs -put -f data/train.txt data/train.txt
aws s3 cp data/train.txt s3://spark-one-off/data/train/train.txt

#execute spark job
logj4="spark.driver.extraJavaOptions=-Dlog4j.configuration=file:./log4j.properties"
#spark-submit --master yarn --conf "$logj4" mlp.py

#this copies hdfs output to s3 and then plops an athena table schema on that data
#./make_athena_tables.sh

#create user jupyter
echo "creating user jupyter..."
sudo adduser jupyter

#prep & start jupyter inside of a screen session, as user=jupyter
#jupyter's password=oneoff, see https://jupyter-notebook.readthedocs.io/en/stable/public_server.html
echo 'starting jupyter...'
sudo -u jupyter /emr/miniconda2/bin/jupyter notebook --generate-config
sudo -u jupyter cp jupyter_notebook_config.json /home/jupyter/.jupyter/.
sudo -u jupyter screen -dmS jupyter_sesh /emr/miniconda2/bin/jupyter notebook --ip 0.0.0.0 --no-browser --port 8765

#update locate's database
echo 'updating locate...'
sudo updatedb

#done
echo 'piggyback.sh done!'

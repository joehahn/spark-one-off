#!/bin/bash 

#provision_datasci.sh
#by Joe Hahn, jmh.datasciences@gmail.com, 9 August 2017.
#
#install software on the datasci instance and launch the jupyter dashboard
#
#To execute:    ./provision_datasci.sh

echo 'running provision_datasci.sh...'
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

#copy aws access keys from s3 > private folder
echo "getting aws access keys from s3..."
mkdir private
aws s3 cp s3://spark-one-off/accessKeys.csv private/accessKeys.csv

#create user jupyter
echo "creating user jupyter..."
sudo adduser jupyter

#prep & start jupyter inside of a screen session, as user=jupyter
#jupyter's password=oneoff, see https://jupyter-notebook.readthedocs.io/en/stable/public_server.html
echo 'starting jupyter...'
sudo -u jupyter /emr/miniconda2/bin/jupyter notebook --generate-config
sudo -u jupyter cp jupyter_notebook_config.json /home/jupyter/.jupyter/.
sudo -u jupyter screen -dmS jupyter_sesh /emr/miniconda2/bin/jupyter notebook --ip 0.0.0.0 --no-browser --port 8765

#done
echo 'provision_datasci.sh done!'

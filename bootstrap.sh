#!/bin/bash 

#bootstrap.sh
#
#by Joe Hahn, jmh.datasciences@gmail.com, 3 August 2017.
#this bootstrap script runs on all nodes prior to launching EMR 
#
#To execute:    ./bootstrap.sh

echo 'running bootstrap.sh...'

#install git
echo 'installing git...'
sudo yum install -y git-all

#install and setup locate
echo 'installing locate...'
sudo yum install -y mlocate
sudo updatedb

#install minicoda plus other python libraries
echo 'installing anaconda...'
wget https://repo.continuum.io/miniconda/Miniconda2-latest-Linux-x86_64.sh
chmod +x ./Miniconda2-latest-Linux-x86_64.sh
./Miniconda2-latest-Linux-x86_64.sh -b -p /emr/miniconda2
export PATH=/emr/miniconda2/bin:$PATH
conda install -y ipython
conda install -y scipy
conda install -y pandas
conda install -y matplotlib
conda install -y seaborn
conda install -y scikit-learn
conda install -y jupyter
conda install -y jupyter_dashboards -c conda-forge
pip install plotly --upgrade                  #this installs plotly v2.0.6
pip install PyAthenaJDBC
#conda install -y -c conda-forge pyspark       #needed for jupyter to talk to pyspark
#conda install -y -c conda-forge -y awscli

echo 'bootstrap.sh done!'

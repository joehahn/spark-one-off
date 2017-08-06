#athena_tables.sh
#
#by Joe Hahn, jmh.datasciences@gmail.com, 6 August 2017.
#plop athena table schemas on top of data stored in s3.
#
#To execute:    ./athena_tables.sh

echo 'running athena_tables.sh...'

#download and install JDBC driver so beeline can talk to Athena
echo 'installing Athena JDBC driver...'
aws s3 cp s3://athena-downloads/drivers/AthenaJDBC41-1.1.0.jar .
sudo cp AthenaJDBC41-1.1.0.jar /usr/lib/spark/jars/.

#get aws access keys from s3, and forward-slash-encode any slashes in the secret key...crap doesnt work :(
echo "getting aws access keys from s3..."
mkdir private
aws s3 cp s3://spark-one-off/accessKeys.csv private/accessKeys.csv
IFS=, read -r access_key secret_key < <(tail -n1 private/accessKeys.csv)
#echo $access_key
#echo $secret_key
secret_key_encoded="$(echo $secret_key | sed 's/\//\\\//g')"
#echo $secret_key_encoded

#check connection string...dammit I cant get secret_key_encoded passed to athena due to the / or +
#in the secret key...am punting by hard-coding the secret_key into connect_str bad bad bad!!!
connect_str="jdbc:awsathena://athena.us-west-2.amazonaws.com:443?s3_staging_dir=s3://spark-one-off/athena/&user=$access_key&password=iGpon+WNmDDxhI2CtCoIUHCqzAZAQ0q4QBgM7Wm3"
echo "JDBC connection string:"
echo $connect_str
/usr/lib/spark/bin/beeline -u "$connect_str" -e "show databases"

#create athena table
query_str="drop table if exists oneoff.train"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="drop database if exists oneoff"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="create database oneoff"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="show databases"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "show databases"
query_str="""
    create external table oneoff.train (
            id int, ran_num double, class string, Xscore double, Oscore double, Bscore double, 
            x0 double, y0 double, x double, y double
        ) row format delimited
        fields terminated by '|'
        location 's3://spark-one-off/data/train'
"""
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"

#check table
query_str="select * from oneoff.train limit 5"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="select count(*) from oneoff.train"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
hdfs dfs -cat data/train/train.txt | wc

#done
echo 'make_athena_tables.sh done.'

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

#check connection string...dammit I cant get secret_key_encoded passed to athena due to the / or +
#in the secret key...am punting by hard-coding the secret_key into connect_str bad bad bad!!!
connect_str="jdbc:awsathena://athena.us-west-2.amazonaws.com:443?s3_staging_dir=s3://spark-one-off/athena/&user=$access_key&password=iGpon+WNmDDxhI2CtCoIUHCqzAZAQ0q4QBgM7Wm3"
echo "JDBC connection string:"
echo $connect_str
/usr/lib/spark/bin/beeline -u "$connect_str" -e "show databases"

#create athena database
query_str="drop table if exists oneoff.train"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="drop table if exists oneoff.grid"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="drop database if exists oneoff"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="create database oneoff"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="show databases"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "show databases"

#create train table
query_str="""
    create external table oneoff.train (
            id int, ran_num double, class string, Xscore double, Oscore double, Bscore double, 
            x0 double, y0 double, x double, y double
        ) row format delimited
        fields terminated by '|'
        location 's3://spark-one-off/data/train'
"""
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="select * from oneoff.train limit 5"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="select count(*) as N from oneoff.train"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
hdfs dfs -cat data/train/*.txt | wc

#create grid table
query_str="""
    create external table oneoff.grid (
            x double, y double, class_pred string, N_hidden int
        ) row format delimited
        fields terminated by '|'
        location 's3://spark-one-off/data/grid'
"""
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="select * from oneoff.grid limit 5"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="select count(*) as N from oneoff.grid"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
hdfs dfs -cat data/grid/*.csv | wc

#done
echo 'athena_tables.sh done!'

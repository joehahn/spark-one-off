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
aws s3 cp s3://mlp-demo/accessKeys.csv private/accessKeys.csv
IFS=, read -r access_key secret_key < <(tail -n1 private/accessKeys.csv)
#echo $access_key
#echo $secret_key
secret_key_encoded="$(echo $secret_key | sed 's/\//\\\//g')"
#echo $secret_key_encoded

#check connection string...dammit I cant get secret_key_encoded passed to athena due to the / or +
#in the secret key...am punting by hard-coding the secret_key into connect_str bad bad bad!!!
connect_str="jdbc:awsathena://athena.us-west-2.amazonaws.com:443?s3_staging_dir=s3://mlp-demo/athena/&user=$access_key&password=GII3FEKH3x+Rarg5hCAx8GKYQAZ/VKvhl/ookG7i"
echo "JDBC connection string:"
echo $connect_str
/usr/lib/spark/bin/beeline -u "$connect_str" -e "show databases"

#create athena table
query_str="drop table if exists mlp.predictions"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="drop database if exists mlp"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="create database mlp"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="show databases"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "show databases"
query_str="""
    create external table mlp.predictions (
            customer_id string, transaction_id int, checkin string, num_rentals int, 
            rent_interval_days double, rent_interval_days_pred double, rent_interval_bin int,
            years_member double, checkin_year double, duration double, payment double, resource_units int,
            membership_points int, mean_rent_interval_days double, gender string, state_province string, 
            customer_purpose string, customer_segment string, customer_style string, 
            elite_status string, leisure_business string,
            hotel_class string, dist_chain string, addon_purchase string, payment_mode string, 
            account_code string, checkin_day string, checkin_month string
        ) row format delimited
        fields terminated by '|'
        location 's3://mlp-demo/data/predictions'
"""
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"

#check table
query_str="select * from mlp.predictions limit 5"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
query_str="select count(*) from mlp.predictions"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"
hdfs dfs -cat mlp-demo/data/predictions/*.csv | wc
query_str="select sum(payment)/1.0e6 as mega_dollars from mlp.predictions"
/usr/lib/spark/bin/beeline -u "$connect_str" -e "$query_str"

#done
echo 'make_athena_tables.sh done.'

## spark-one-off 

by Joe Hahn,<br />
jmh.datasciences@gmail.com,<br />
3 August 2017<br />
git branch=master

###Intro:

Browse the Jupyter dashboard at

        http://54.202.254.48:8765/notebooks/dashboard.ipynb?dashboard


with password=oneoff


###Technical Notes:

The following notes will be useful to those wishing to dig deeper:

1 To install and configure awscli on your laptop (this assumes you have installed anaconda or minicondo
on your laptop):

    conda install -c conda-forge -y awscli


Then configure aws-cli by adding the following lines to ~/.aws/config on your laptop:

    [profile oneoff]
    region = us-west-2


(keeping in mind that athena is not available in all AWS regions). Then tell aws-cli to use your aws access keys:

    cat private/accessKeys.csv
    aws configure --profile oneoff


2 Launch this single-node EMR cluster by executing the following on your laptop: 

        ./launch_cluster.sh


and note the ClusterID that will resemble

        ClusterId=j-GEKI6R5CC8ZZ


and browse the cluster's EMR dashboard at

        https://us-west-2.console.aws.amazon.com/elasticmapreduce/home?region=us-west-2#cluster-details:j-GEKI6R5CC8ZZ


and use that plus the EC2 console to infer the master node's public IP, which will resemble:

        master=54.202.254.48


All cluster instances are named oneoff in the AWS/EC2 console.
This cluster will cycle through Starting and Bootstrapping phases
(during which is the EMR cluster launches, fires up Hadoop, and then installs additional libraries),
then Running (where a Spark code is executed in parallel across the cluster's 8 worker nodes,
this is the code that fits a predictive neural network model to the data),
then Terminating (here the cluster is automatically shut down after demo output is stored in S3).

If you want this cluster to persist rather than terminate, change --auto-terminate in
launch_cluster.sh to --no-auto-terminate


3 Then ssh into the master node as user=hadoop:

        ssh -i private/datasci.pem hadoop@$master


4 Monitor the log that is generated by the * and * scripts that execute on
this cluster's master node:

        tail -f /mnt/var/log/hadoop/steps/s-*/stdout


These logs are also stored in s3 at

        mlp-demo/elasticmapreduce/$ClusterId/steps/s-something


5 To clone and push to this repo on master, with permissions adjusted so that 
jupyter can also save its notebooks in this directory:

        git config --global user.email "jmh.datasciences@gmail.com"
        git config --global user.name "joehahn"
        git clone https://github.com/joehahn/spark-one-off.git
        chmod 777 spark-one-off
        cd spark-one-off
        chmod 777 *.ipynb


6 To regenerate the training data and store in hdfs:

        /emr/miniconda2/bin/python ./make_training_data.py
        hdfs dfs -rm -R -f -skipTrash data
        hdfs dfs -mkdir -p data/train
        hdfs dfs -put -f data/train.txt data/train/train.txt


7 To train MLP model on the XO dataset, and to map its decision surface:

        logj4="spark.driver.extraJavaOptions=-Dlog4j.configuration=file:./log4j.properties"
        PYSPARK_PYTHON=/emr/miniconda2/bin/python spark-submit --master yarn --conf "$logj4" \
            --num-executors 29 --executor-cores 4 --executor-memory 4G --driver-memory 2G mlp.py


8 To export input & output data to s3:

        aws s3 rm --recursive s3://spark-one-off/data
        hadoop distcp data s3a://spark-one-off/data


7 To rebuild the athena tables:

        mkdir private
        aws s3 cp s3://spark-one-off/accessKeys.csv private/accessKeys.csv
        ./athena_tables.sh


8 To view any of the cluster's UIs, first establish an ssh tunnel into the master node:

        ssh -i private/datasci.pem hadoop@$master -CD 8157


Also install the SwitchyOmega extension in chrome and configure per 
https://www.cloudera.com/documentation/director/2-2-x/topics/director_security_socks.html
with the contents of pac.script copied into the PAC Script box


9 While the mlp.py spark job is executing, you can monitor that job by
browsing Yarn's resource manager on port 8088 of the master's private IP,
which will resemble:

        http://10.0.0.223:8088



7 The Jupyter dashboard is running inside a screen session
on the master instance; use the EC2 console to get that machine's
public IP then browse

        http://54.202.254.48:8765


Note that this Jupyter UI is password-protected but visible to the world,
and this process is owned by user=hadoop who has sudo privledges. Not good practice for
production work, but is ok enuf for a demo running on a throwaway
instance. Doing this properly likely requires creating a non-sudo'able user
and having that user launch the Jupyter dashboards.


10 To construct the launch_cluster.sh script, first build the EMR cluster manually via
AWS console > EMR > Advanced options using these settings:

    Advanced options
    release=emr-5.7.0
    create vpc > with single public subnet:
        vpc name=spark-one-off
        VPC ID=vpc-b78721d1 | spark-one-off
        Subnet ID=subnet-087c7641 | Public subnet
    cluster name=spark-one-off
    logging s3 folder=s3://spark-one-off/elasticmapreduce/
    no termination protection
    scale down: terminate at task completion
    Tag: Name=spark-one-off
    ec2 key pair=datasci


Then click AWS CLI export, copy to launch_cluster.sh, and then adapt. To enable ssh access,
use the EC2 console to add this inbound rule to the ElasticMapReduce-master security group: 

        ssh, tcp, 22, anywhere


and then add this rule to the same security group:

        custom tcp, tcp, 8765, anywhere


to allow anyone to browse the cluster's password-protected Jupyter UI from anywhere.
Opening port 8765 like this probably isn't best practice, but will have to be good enuf
for now...


8 To terminate this cluster using laptop's aws-cli:

        aws emr terminate-clusters --cluster-ids $ClusterId --profile oneoff


After the cluster is terminated then it is safe to delete the s3 bucket:

        aws s3 rb s3://spark-one-off --force --profile oneoff


and use AWS > Athena > Catalog Manager > drop the oneoff database.

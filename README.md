## spark-one-off 

by Joe Hahn,<br />
jmh.datasciences@gmail.com,<br />
3 August 2017<br />
git branch=master

### Intro:


The following uses a suite of bash and python scripts to launch a throwaway EMR cluster
in the Amazon AWS cloud. And once that cluster is up and ready, a Spark job is then
executed in parallel across that cluster's worker nodes. When that Spark job is complete,
its output is stored in S3 and then the EMR cluster terminates. And while that is happening,
a persistent datascience instance is also launched in AWS; that datascience instance
hosts a Jupyter dashboard that uses the Athena service to query that S3 data
and visualize those queries. The purpose of this repo is to provide a template
for getting  a computation performed in parallel on a throwaway Spark EMR cluster,
exporting output to S3, and then visualizing that output via a persistent Jupyter dashboard.
Storing output in S3 and terminating the EMR cluster after the Spark job completes
also keeps compute costs very low. This workflow is also illustrated by the
following architecture diagram, which shows how all of these AWS components interact:

(architecture diagram)

Other users are invited to use this template in their own work, and that would require
_(i.)_ replacing the references to make_training_data.py (which is called by piggyback.sh
and generates some mock data) and mlp.py (which fits a neural network model to that mock data)
to your desired Spark codes, _(ii.)_ changing the lines in piggyback.sh that
export data to your desired folder in S3, and _(iii.)_ modifying the script athena_tables.sh
(which lands some Athena table schemas on the S3 folders) for your use-case.

To launch the throwaway EMR cluster, first confirm that you satisfy the Requirements that are noted below,
and then execute

        ./launch_cluster.sh

which in 20 minutes will: launch the EMR cluster and the datasci instance, install various libraries
there, execute the Spark job on the EMR cluster, export output to S3, and launch a Jupyter dashboard that
visualizes that output.

To browse that Jupyter dashboard, first use the AWS EC2 console to determine the public IP
address of the datasci instance and then browse

        http://54.202.212.90:8765/notebooks/dashboard.ipynb?dashboard

keeping in mind that you will need to update the IP address in the above URL, and
log in using password=oneoff. On first visit, refresh that dashboard via

        Kernel > Restart & Run All

which unfortunately take about a minute to complete. The bottleneck appears to be the PyAthenaJDBC
library that the dashboard uses to communicate with Athena; replacing that library with 
more efficient code will likely speed up that dashboard's refresh rate. To see the
python code that generates the dashboard's visuals, click View > Notebook.


### Spark Job:

This repo's main goal is to template the workflow just described: have Spark perform
a computation on an EMR cluster and export its output to S3 where it is later
be queried and visualized by a Jupyter dashboard. This line in the piggyback script
generates the mock XO dataset:

        /emr/miniconda2/bin/python ./make_training_data.py

which also labels each record in the XO dataset as a member of the green X,
red O, or blue B background classes, depending upon where each record's x,y coordinates
reside, see dashboard.

![](https://github.com/joehahn/spark-one-off/blob/master/figs/xy.png)

This training dataset is then stored in HDFS,
and then the pyspark code mlp.py trains a Multi Layer Perceptron (MLP) classifier
on that data. An MLP model is a fairly simple neural network model, and the
quality of its predictions depends on the number of neurons used
in the model's hidden layer. To explore this, the mlp.py code actually fits
10 different neural nets to the training data, and those models use 5 < N < 600 neurons
in their hidden layers. To determine the optimal number
of neurons N, the mlp.py code uses these trained MLP classifiers
to map each model's predicted decision boundaries, and the dashboard shows that N=30
is the optimal number of neurons in the MLP model's hidden layer.

![](https://github.com/joehahn/spark-one-off/blob/master/figs/decision_surface.png)


### Requirements:

Launching the EMR cluster will require the following:

- You have access to an AWS account with sufficient permission to launch EC2 instances,
write data to S3, and execute Athena queries.

- The following presumes that all other confidential info (ssh and aws keys etc) is
stored locally on your laptop in the private folder and not pushed to this github repo.
Your AWS access keys should be stored in file private/accessKeys.csv

- Anaconda python and aws-cli are installed and configured on your laptop per Notes #1, below.

Note that after the following successfully executes once, only a browser is needed
to view the dashboard.


### Technical Notes:

The following notes will be useful to those wishing to dig deeper:

1 To install and configure awscli on your laptop (this assumes you have installed anaconda or miniconda
on your laptop):

    conda install -c conda-forge -y awscli

Then configure aws-cli by adding the following lines to ~/.aws/config on your laptop:

    [profile oneoff]
    region = us-west-2

(keeping in mind that athena is not available in all AWS regions). Then tell aws-cli to use your aws access keys:

    cat private/accessKeys.csv
    aws configure --profile oneoff

2 Launch the EMR Hadoop cluster by executing the following on your laptop: 

        ./launch_cluster.sh

and note the two ClusterIDs reported, the first ClusterID is for the EMR cluster where the spark job
will be executed, that ClusterID will resemble

        ClusterId=j-BS4RH7H8YON6

and is used to browse the EMR cluster's dashboard at

        https://us-west-2.console.aws.amazon.com/elasticmapreduce/home?region=us-west-2#cluster-details:j-BS4RH7H8YON6

Use that dashboard plus the EC2 console to infer the master node's public IP, which will resemble:

        masterIP=54.244.33.196

All cluster instances are named oneoff in the AWS/EC2 console.
This cluster will cycle through Starting and Bootstrapping phases
(during which is the EMR cluster launches, fires up Hadoop, and then installs additional libraries),
then Running (where the Spark code mlp.py is executed in parallel across the cluster's 4 worker nodes,
this is the code that fits the predictive neural network model to the mock data),
then Terminating (here the cluster is automatically shut down after the output is stored in S3).

If you want this cluster to persist rather than terminate, change --auto-terminate in
launch_cluster.sh to --no-auto-terminate

3 Then ssh into the master node as user=hadoop:

        ssh -i private/datasci.pem hadoop@$masterIP

4 When the EMR dashboard reports that the cluster is Bootstrapping, the cluster is executing
the bootstrap script on all oneoff instances, and then it installs Hadoop across this cluster,
this takes about 8 minutes to complete.

5 And when the EMR cluster is Running, it is executing the piggyback script on the master node,
that script launches the spark job mlp.py that is this cluster's main purpose, 
that script take about 8 minutes to complete, and you can monitor its progress by tailing this log:

        tail -f /mnt/var/log/hadoop/steps/s-*/stdout

These logs are also stored in s3 at

        mlp-demo/elasticmapreduce/$ClusterId/steps/s-something

6 The final task in piggyback.sh is to sleep for 10 minutes, after which the cluster auto
terminates, so if you need to ssh into the master node to debug any issues, you have 10 minutes to do so

7 Meanwhile, the launch_cluster script also calls launch_datasci which launches the 
persistent datasci instance that hosts the jupyter dashboard. Use the AWS console to get
its public IP and ssh into datasci:

        datasciIP=54.202.212.90
        ssh -i private/datasci.pem hadoop@$datasciIP

8 The piggyback and provision_datasci scripts are executed on the datasci instance, with
provision_datasci setting up the jupyter dashboard, check its logs via

        tail -f /mnt/var/log/hadoop/steps/s-*/stdout

9 User=jupyter owners the Jupyter session that is running inside a screen session
on the datasci instance. Use the EC2 console to get that machine's
public IP and then browse

        http://54.202.212.90:8765

and enter password=oneoff.

10 To clone from (and also push to) this repo, with permissions adjusted so that 
jupyter can also save its notebooks in a directory owned by user=hadoop:

        git config --global user.email "jmh.datasciences@gmail.com"
        git config --global user.name "joehahn"
        git clone https://github.com/joehahn/spark-one-off.git
        chmod 777 spark-one-off
        cd spark-one-off
        chmod 777 *.ipynb
        mkdir private
        aws s3 cp s3://spark-one-off/accessKeys.csv private/accessKeys.csv

11 To regenerate the training data on the EMR's master node and store in hdfs:

        /emr/miniconda2/bin/python ./make_training_data.py
        hdfs dfs -rm -R -f -skipTrash data
        hdfs dfs -mkdir -p data/train
        hdfs dfs -put -f data/train.txt data/train/train.txt

12 To train MLP model on the XO dataset & map its decision surface, on master:

        logj4="spark.driver.extraJavaOptions=-Dlog4j.configuration=file:./log4j.properties"
        PYSPARK_PYTHON=/emr/miniconda2/bin/python spark-submit --master yarn --conf "$logj4" \
            --num-executors 29 --executor-cores 4 --executor-memory 4G --driver-memory 2G mlp.py

13 To export input & output data to s3, on master:

        aws s3 rm --recursive s3://spark-one-off/data
        hadoop distcp data s3a://spark-one-off/data

14 To rebuild the athena tables, on master:

        mkdir private
        aws s3 cp s3://spark-one-off/accessKeys.csv private/accessKeys.csv
        ./athena_tables.sh

15 To view any of the cluster's UIs, first establish an ssh tunnel into the master node:

        ssh -i private/datasci.pem hadoop@$masterIP -CD 8157

Also install the SwitchyOmega extension in chrome and configure per 
https://www.cloudera.com/documentation/director/2-2-x/topics/director_security_socks.html
with the contents of pac.script copied into the PAC Script box

16 While the mlp.py spark job is executing, you can monitor that job by
browsing Yarn's resource manager on port 8088 of the master's private IP,
which will resemble:

        http://10.0.0.174:8088

Note that this Jupyter UI is password-protected but visible to the world,
and this process is owned by user=jupyter who does not have sudo privledges. Not good practice for
production work, but is ok for a demo running on a throwaway instance.

17 To construct the launch_cluster.sh script, first build the EMR cluster manually via
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
Opening port 8765 to the world is not best practice, but will have to be good enuf
for now...

18 To terminate this cluster using laptop's aws-cli:

        aws emr terminate-clusters --cluster-ids $ClusterId --profile oneoff

and do the same or use the EMR console to kill the datasci instance.
After the EMR clusters are terminated then it is safe to delete the s3 bucket:

        aws s3 rb s3://spark-one-off --force --profile oneoff

and use AWS > Athena > Catalog Manager to drop the oneoff database.


### Known Issues:

1 To launch the datasci instance, the aws-cli command "aws emr create-cluster" is used to create
a single-node emr cluster. For convenience only, since that easily gets the bootstrap and
provision_datasci scripts executed on the datasci node. The downside is the additional EMR charge
of about $2/hour. The preferred way to launch is via the "aws ec2 run-instances" command,
which will avoid the EMR charge. But that is not used here since I don't know how to tell
this new instance how to use the desired subnet and security groups and execute additional scripts.
I'm sure that it is straightforward to launch this instance correctly, but I myself don't know how
to do so...

2 My AWS secret key is hard-coded into athena_tables.sh. This is a consequence of not
having good enough bash-fu to deal with keys that have special characters (+/) in them,
this is insecure and needs to be fixed... Fortunately my access key is not exposed in this
repo, so this issue is only a partial rather than total security fail...

3 The jupyter dashboard is protected only by a weak password. Note that Jupyter also gives
viewers commandline access to the datasci node. I don't know how to fix this particular security
weakness...wrap a VPN around the datasci instance?

4 Bash + aws-cli is used to launch, provision, and execute all of the above. Which is kinda
tedious to develop and debug. I suspect that using ansible would be a better way to do this,
but I'm not ansible-savvy.

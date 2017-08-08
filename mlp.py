#mlp.py
#
#by Joe Hahn, jmh.datasciences@gmail.com, 7 August 2017.
#
#train an MLP model on the XO dataset, and map its decision surface

#to execute in pyspark's ipython shell:
#    PYSPARK_DRIVER_PYTHON=/emr/miniconda2/bin/ipython pyspark
#to run locally on master node:
#    PYSPARK_PYTHON=/emr/miniconda2/bin/python spark-submit --master local[*] --conf "spark.driver.extraJavaOptions=-Dlog4j.configuration=file:./log4j.properties" mlp.py
#to submit spark job to yarn:
#    PYSPARK_PYTHON=/emr/miniconda2/bin/python spark-submit --master yarn --conf "spark.driver.extraJavaOptions=-Dlog4j.configuration=file:./log4j.properties" mlp.py

#set debug=True to display debugging info
debug = True

#set seed for random number generator
rn_seed = 51

#get starting time
import time
time_start = time.time()

#create SparkSession
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('train_model').getOrCreate()

#read training data into spark dataframe
print 'reading training data...'
from pyspark.sql.types import StructType, StructField
from pyspark.sql.types import DoubleType, IntegerType, StringType
schema = StructType([
    StructField("id", IntegerType()),
    StructField("ran_num", DoubleType()),
    StructField("class", StringType()),
    StructField("Xscore", DoubleType()),
    StructField("Oscore", DoubleType()),
    StructField("Bscore", DoubleType()),
    StructField("x0", DoubleType()),
    StructField("y0", DoubleType()),
    StructField("x", DoubleType()),
    StructField("y", DoubleType()),
])
hdfs_file = 'data/train/train.txt'
format_src = 'com.databricks.spark.csv'
train = spark.read.format(format_src).schema(schema).options(header='false', delimiter='|')\
    .load(hdfs_file).cache()
if (True):
    print train.dtypes
    train.show(5)
    print '    number of records = ', train.count()

#convert X,O,B > 0,1,2
class2num = {'X':0, 'O':1, 'B':2}
from pyspark.sql.functions import when
class2num = when(train['class'] == 'X', 0.0).otherwise(when(train['class'] == 'O', 1.0).otherwise(2.0))
train_class = train.withColumn('class_num', class2num)
train_class.show(10)

#select features that the model will be trained on, noting that the number of neurons
#in the neural network's hidden layer = N_features
feature_cols = ['x', 'y']
N_features = len(feature_cols)

#target column that is to be predicted
target_col = 'class_num'

#generate a list of all possible classes, noting that the number of neurons in the
#neural net's output layer = N_classes
classes = train_class.select(target_col).distinct()
N_classes = classes.count()
classes.show()
print 'number of classes = ', N_classes

#set number of neurons in the neural net's only hidden layer,
#this should be adjusted to avoid under/over fitting
#N_hidden = 5 #very underfitted
#N_hidden = 15 #ok
#N_hidden = 50 #good
N_hidden = 100 #?
#N_hidden = 150 #very good

#specify number of neurons in each layer 
layers = [N_features, N_hidden, N_classes]
print 'layers = ', layers

#assemble features into a column of feature-vectors plus a target column
print 'assembling features vectors...'
from pyspark.ml.feature import VectorAssembler
assembler = VectorAssembler(inputCols=feature_cols, outputCol='features')
train_assembled = assembler.transform(train_class)
train_assembled.show(5, truncate=False)

#train a MultilayerPerceptronClassifier
print 'training MLP model...'
from pyspark.ml.classification import MultilayerPerceptronClassifier
mlp = MultilayerPerceptronClassifier(maxIter=100, layers=layers, seed=rn_seed, labelCol=target_col, \
    featuresCol='features')
model = mlp.fit(train_assembled)

#create a grid of (x,y) points, for mapping the model's decision surface
print 'generating grid for mapping prediction boundaries...'
xy_max = 5.0
delta = 0.05
import numpy as np
xy_axis = np.arange(-xy_max, xy_max + delta, delta)
Nxy = len(xy_axis)
id = np.arange(Nxy**2)
import pandas as pd
grid_pd = pd.DataFrame(id, columns=['id'])
grid_pd['y_idx'] = grid_pd['id']//Nxy
grid_pd['x_idx'] = grid_pd['id'] - grid_pd['y_idx']*Nxy
grid_pd['y'] = (grid_pd['y_idx'] - Nxy/2)*delta
grid_pd['x'] = (grid_pd['x_idx'] - Nxy/2)*delta
grid = spark.createDataFrame(grid_pd[['x', 'y']])
grid.show(5)

#generate predictions across the grid
print 'computing predictions across grid...'
grid_assembled = assembler.transform(grid)
grid_assembled.show(5, truncate=False)
grid_predict = model.transform(grid_assembled)
grid_predict.show(5, truncate=False)

#convert numerical predictions into X,O,B
num2class = when(grid_predict['prediction'] == 0.0, 'X')\
    .otherwise(when(grid_predict['prediction'] == 1.0, 'O').otherwise('B'))
grid_class = grid_predict.withColumn('class_pred', num2class)
grid_class.show(10)

#write predictions to hdfs
print 'writing predictions to hdfs...'
cols = ['x', 'y', 'class_pred']
grid_write = grid_class.select(cols)
print grid_write.dtypes
print grid_write.show(10)
grid_write.write.csv('data/grid', mode='overwrite', sep='|', header='false')
import os
os.system('hdfs dfs -ls data/grid')
N_grid = grid_write.count()
print 'number of records in grid = ', N_grid

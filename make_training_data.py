#!/usr/bin/env python

#make_training_data.py
#by Joe Hahn, jhh.datasciences.org, 6 August 2017.
#
#this python script generates the synthetic xo data that an MLP model
#will be trained on

#to execute:    /emr/miniconda2/bin/python ./make_training_data.py

#number of dots in training dataset
N_train = 12000

#half-thickness of the x
x_half_width = 0.5

#radius of the O
radius = 3.5

#box half-width before 45 degree rotation
box_half_width = 7.1

#set jitter=scale of the gaussian noise, to make the class boundaries slightly fuzzy
jitter = 0.4

#set seed for random number generator
rn_seed = 13

#set debug=True to see debugging output
debug =  False

#generate the xo dataset
print 'generating xo data...'
from xo_data import *
initial_id = 0
train = make_xo_data(N_train, initial_id, x_half_width, radius, box_half_width, jitter, rn_seed, debug)
print 'number of training records = ', len(train)

#save training data as csv file
import pandas as pd
pd.set_option('display.expand_frame_repr', False)
print train.head(5)
train.to_csv('data/train.txt', sep='|', index=False, header=False)

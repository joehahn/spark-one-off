#make_xo_data.py.py
#by Joe Hahn, jhahn6@csc.com, 29 June 2017.
#
#helper functions generates the xo dataset
#

def make_xo_data(N_dots, initial_id, x_half_width, radius, box_half_width, jitter, rn_seed, debug):
    
    #generate dataframe and initialize records' ids
    import pandas as pd
    df = pd.DataFrame()
    df.index.name = 'idx'
    import numpy as np
    df['id'] = initial_id + np.arange(N_dots)
    
    #generate random x,y positions
    rn_state = np.random.RandomState(seed=rn_seed)
    df['x'] = np.random.uniform(low=-box_half_width, high=box_half_width, size=N_dots)
    df['y'] = np.random.uniform(low=-box_half_width, high=box_half_width, size=N_dots)
    df['r'] = np.sqrt(df.x**2 + df.y**2)

    #classify dots as members of X, O, or B=background classes
    df['class'] = 'B'
    idx = df['r'] < radius
    df.loc[idx, 'class'] = 'O'
    idx = (df.x.abs() < x_half_width) | (df.y.abs() < x_half_width)
    df.loc[idx, 'class'] = 'X'
    idx_x = df['class'] == 'X'
    idx_o = df['class'] == 'O'
    idx_not = df['class'] == 'B'
    
    #class scores
    df.loc[idx_x, 'Xscore'] = 1.0
    df.loc[idx_x, 'Oscore'] = 0.0
    df.loc[idx_x, 'Bscore'] = 0.0
    df.loc[idx_o, 'Xscore'] = 0.0
    df.loc[idx_o, 'Oscore'] = 1.0
    df.loc[idx_o, 'Bscore'] = 0.0
    df.loc[idx_not, 'Xscore'] = 0.0
    df.loc[idx_not, 'Oscore'] = 0.0
    df.loc[idx_not, 'Bscore'] = 1.0

    #rotate coordinate system by 45 degrees = pi/4 radians
    phi = np.pi/4.0
    c = np.cos(phi)
    s = np.sin(phi)
    df['xr'] =  df.x*c + df.y*s
    df['yr'] = -df.x*s + df.y*c
    
    #add gaussian noise/jitter to dots' (x,y) positions:
    df['xrn'] = df.xr + np.random.normal(scale=jitter, size=N_dots)
    df['yrn'] = df.yr + np.random.normal(scale=jitter, size=N_dots)
    
    #add a column of random numbers 
    df['ran_num'] = np.random.uniform(size=N_dots)
    if (debug):
        print df.head(5)
    
    #return selected columns
    cols = ['id', 'ran_num', 'class', 'Xscore', 'Oscore', 'Bscore', 'xr', 'yr', 'xrn', 'yrn']
    df_select = df[cols]
    if (debug):
        print df_select.head(5)
    return df_select


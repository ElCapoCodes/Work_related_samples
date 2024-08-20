#!/usr/bin/env python
#coding: utf-8
#
# <h2>Price Comparison</h2>
#      Author: Marlon Roa
#
# <h3>IN:</h3> 
#     Gold, Silver, All_pons price lists, All leadtimes and Partner quote<br>
#     
# <h3>OUT:</h3> 
#     A file with gold/silver/list & status per PON.<br>
#      
# <h3>OBJ:</h3> 
#     Validate NewProd-related quote pricing. It also does all company products as its legacy function<br>
# 
# # FYI: New names
# * ./Input/Gold_list.xlsx
# * ./Input/Silver_list.xlsx
# * ./Input/NewProd_list.xlsx
# * ./Input/All_PONs_list.xlsx
# 
#
import pandas as pd    
import numpy as np
import scipy.stats as stats
import re
import datetime
from datetime import datetime, date, time, timedelta
#
from sys import argv
#
import os
import shutil

def read_gold_silver (fname, gold0_slv1):
    in_fname = fname 
    xls = pd.ExcelFile(in_fname) 
    df = pd.read_excel(xls, engine="openpyxl")
    #
    if (gold0_slv1 == 3):        
        df = df[['Product Code','Product Status', 'Agile Status','PON Price', 'Product Type', 'Lead Time in Weeks', 'Product Description']]
        df.rename(columns={'Product Code':'Product', 'Agile Status':'AStatus', 'Lead Time in Weeks':'ALtimes', 
            'Product Description':'Description', 'Product Type':'PType'}, inplace=True)
        df = df[df['Product Status'].notna()] 
    #./.
    #
    if (gold0_slv1 == 4):
        df.rename(columns={'Product Code':'Product'}, inplace=True)    
    #
    df['Product'] = df.Product.astype(str)
    df['Product'] = df['Product'].str.upper()
    #
    if (gold0_slv1 < 3):
        plabel = 'Price'
        df.rename(columns={'Price':plabel}, inplace=True)
    # ./. Eo if
    #
    return(df)
#./. def
#
#
# F: Merge using Product on total_df only. Hence, unmtached reff_df are ignored.
#    Need to call reff_df in an specific orde: gold->silve->tp
def merge_pricing(total_df, reff_df, option):
    #
    plabel = 'PriceG' 
    if (option == 1): plabel = 'PriceS'  
    if (option == 2): plabel = 'PriceX' 
    if (option == 3): plabel = 'PriceA'
    #
    # Merge using Product on total_df only. Hence, unmtached reff_df are ignored
    total_df = pd.merge(total_df, reff_df, how="left", on='Product')    
    #
    if(option == 0):
        total_df = total_df[['Product', 'Quantity', 'Description', 'PriceC','Price', 'Status']]
        total_df.rename(columns={'Price':plabel}, inplace=True)
        
    elif(option == 1):
        total_df = total_df[['Product', 'Quantity', 'Description_x', 'PriceC', 'PriceG', 'Price', 'Status_x']]
        total_df.rename(columns={'Price':plabel,'Description_x':'Description', 'Status_x':'Status'}, inplace=True)
        
    elif(option == 2):  # New pricing (temp until prod is GA, then Allpons should include New-Prod)
        total_df = total_df[['Product', 'Quantity', 'Description_y', 'PriceC', 'PriceG', 'PriceS', 'Price', 'Status_y', 'Product Type']]
        total_df.rename(columns={'Price':plabel,'Description_y':'Description', 'Status_y':'Status', 'Product Type':'PType'}, inplace=True)

    elif(option == 3):
        total_df = total_df[['Product', 'Quantity', 'Description_y', 'PriceC', 'PriceG', 'PriceS', 'PriceX', 'Status', 'AStatus', 'ALtimes', 'PON Price','PType_y']]
        total_df.rename(columns={'PON Price':plabel,  'PType_y':'PType', 'Description_y':'Description'}, inplace=True)
        
    #./.
    #
    total_df[plabel] = total_df[plabel].fillna(0)
    return  (total_df)
# ./. eo def merge_pricing
#
#
in_fname = "./Input/Customer_list.xlsx"
print ("\nI: Read ", in_fname, " as partner file to add data to.\n")
xls = pd.ExcelFile(in_fname)
total_df = pd.read_excel(xls, engine="openpyxl")
#
total_df = total_df[['Product', 'Price', 'Quantity']]
#
print ("\t-- Rename columns, PON uppercase, rm duplicates if any.")
total_df.rename(columns={'Price':'PriceC'}, inplace=True)
#
# Set product to all upper case
total_df['Product'] = total_df.Product.astype(str) # Added to protect numbered PONs (ex: 179.398)
total_df['Product'] = total_df['Product'].str.upper() 
#
if (len(total_df['Product'])-len(total_df['Product'].drop_duplicates()) != 0):
    print ("\t-- Removing duplicates.")
    total_df.drop_duplicates(subset=['Product'], inplace=True)
#./. eo if
total_df = total_df[['Product', 'Quantity', 'PriceC']]

print ("I: Read all pricing reff files: Gold, Silver, New_prod pre_GA,  All PONs & my Leadtime file.")
#
# I: Lists tobe added need to have header on row 0, "Product" & 'Price' col name must exist in all except Allpons,
#    & 'product' col needs to have no duplicate elements
gold_df    = read_gold_silver("./InputReff/Gold_list.xlsx", 0)
silver_df  = read_gold_silver("./InputReff/Silver_list.xlsx", 1)
xr_df      = read_gold_silver("./InputReff/NewProd_list.xlsx", 2)
allpons_df = read_gold_silver("./InputReff/All_PONs_list.xlsx",3)
#
#
print ("\nI: Add all pricing, status, description & leadtimes to the Partner quote")
#
print("\t-- Add Gold pricing")
total_df = merge_pricing(total_df, gold_df,0)
print("\t-- Add Silver pricing")
total_df = merge_pricing(total_df, silver_df,1)
print("\t-- Add NewProd pricing")
total_df = merge_pricing(total_df, xr_df,2)
print("\t-- Add List pricing")
total_df = merge_pricing(total_df, allpons_df,3)

for ix in list(total_df.index):    
    if(pd.isnull(total_df['Description'].loc[ix])):        
        for ap in list(allpons_df.index):
            if (total_df['Product'].loc[ix] == allpons_df['Product'].loc[ap]):
                total_df.at[ix, 'Description'] = allpons_df['Description'].loc[ap]                
#
print ("\t-- Compare Customer vs. SFDC pricing ")
total_df['PvsX'] = np.where(total_df['PriceC'] > total_df['PriceA'], 'C_gt_A', 'C_lte_A')
total_df['Status'] = total_df['Status'].fillna(0)
#
total_df = total_df[['Product',  'Quantity', 'Description', 'PriceC','PriceX', 'PriceG', 'PriceS', 'PriceA', 'PvsX', 'Status', 'AStatus', 'PType']] 
#
print ("\nI: Printing output file: price_compare_quote.xlsx")
total_df.to_excel("./Output/price_compare_quote.xlsx", sheet_name='Sheet', index=False)
#
total_df.columns
print ("\n./. Script Done ./.\n")
#
#./.





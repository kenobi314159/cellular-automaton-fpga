#!/usr/bin/python3
#-------------------------------------------------------------------------------
# PROJECT: CELLULAR AUTOMATON FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

from argparse import ArgumentParser
def next_comb(comb):
    ones = 0
    for i in range(len(comb)):
        if (comb[i]=="0"):
            break
        ones += 1
    i0 = -1
    i1 = -1
    for i in range(len(comb)):
        if (comb[i]=='0'):
            i0 = i
        elif (i0!=-1 and comb[i]=='1'):
            i1 = i
            break
    if (i0==-1 or i1==-1):
        return False
    comb = "0"*(i0-ones)+"1"*(ones)+"1"+comb[i0+1:i1]+"0"+comb[i1+1:]
    return comb

def write_comb(comb,f,s0,s1):
    c = comb[:4]+s0+comb[4:]
    f.write(" ".join(c)+" : "+s1+"\n")

f = open("a.tab","w")

f.write("""
################################
# 9-connection Game of Life
################################

################
# 0 -> 1 when exactly 3 neighbours
################

""")
comb = "00000111"
while (comb):
    write_comb(comb,f,"0","1")
    comb = next_comb(comb)

f.write("""
################

################
# 1 -> 0 when less than 2 neighbours or more than 3 neighbours
################

""")
combs = ["00000000","00000001","00001111","00011111","00111111","01111111","11111111"]
for c in combs:
    comb = c
    while (comb):
        write_comb(comb,f,"1","0")
        comb = next_comb(comb)

f.write("""
################

################################
""")
f.close()

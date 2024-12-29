#!/usr/bin/python3
#-------------------------------------------------------------------------------
# PROJECT: CELLULAR AUTOMATON FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

from argparse         import ArgumentParser
from time             import sleep,time

from wishbone         import *
from sys_module       import *
from cellular_automat import *

# Define parameters
parser = ArgumentParser()

parser.add_argument("--port",default="COM4",help="Target device serial port name (default: COM4)")

# Parse arguments
args = parser.parse_args()

# Init objects
wb = wishbone(args.port)

sys_mod = sys_module(wb)
sys_mod.report()

cell_auto = cellular_automat(wb,0x8000)

# Init FPGA Automaton
cell_auto.reset()
cell_auto.print_cell_states()

# TEST 1
# Run first few steps of calculation
print("============")
cell_auto.reset()
for e in range(1,9):
    print("------------")
    cell_auto.set_gen_limit(e)
    cell_auto.start()
    print(hex(cell_auto.read_current_gen()))
    cell_auto.stop()
    cell_auto.print_cell_states()

# TEST 2
# Write state different from initial state
# and run a few steps
print("============")
cell_auto.reset()
print("------------")
cell_auto.set_gen_limit(1)
cell_auto.start()
cell_auto.stop()
state = []
for i in range(cell_auto.grid_size[1]):
    line = []
    for e in range(cell_auto.grid_size[0]):
        line.append(cell_auto.read_cell_state((e,i)))
    state.append(line)
print("State after 1 step")
cell_auto.print_cell_states()
print("------------")
cell_auto.set_gen_limit(2)
cell_auto.start()
cell_auto.stop()
print("State after next step")
cell_auto.print_cell_states()
print("------------")
for i in range(cell_auto.grid_size[1]):
    for e in range(cell_auto.grid_size[0]):
        cell_auto.write_cell_state((e,i), state[i][e])
print("State after writing step 1 back")
cell_auto.print_cell_states()
print("------------")
cell_auto.set_gen_limit(3)
cell_auto.start()
cell_auto.stop()
print("State after next step again")
cell_auto.print_cell_states()

# TEST 3
# Test computation speed when doubling
# generations limit several times
print("============")
cell_auto.reset()
t = [time()]
for i in range(4):
    g = 2**(23+i)
    print("------------")
    print("limit:",hex(g))
    cell_auto.set_gen_limit(g)
    t[-1] = time()
    cell_auto.reset()
    cell_auto.start()
    ok = False
    while (not ok):
        sleep(0.01)
        cg = cell_auto.read_current_gen()
        #print(hex(cg))
        ok = (cg==g)
    cell_auto.stop()
    t.append(time())
    print("time:",t[-1]-t[-2],"s")
    cell_auto.print_cell_states()

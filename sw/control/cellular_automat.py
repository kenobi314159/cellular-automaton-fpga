#!/usr/bin/python3
#-------------------------------------------------------------------------------
# PROJECT: CELLULAR AUTOMATON FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

class cellular_automat:
    def __init__(self, wishbone, base_addr=0x8000, grid_size=(3,3)):
        self.wb = wishbone
        self.ba = base_addr
        self.grid_size = grid_size

    def read_ctrl_reg(self):
        v = self.wb.read(self.ba+0x0)
        return v
    def read_gen_limit(self):
        v = self.wb.read(self.ba+0x1)
        return v
    def read_current_gen(self):
        v = self.wb.read(self.ba+0x2)
        return v
    def read_cell_state(self,coords=(0,0)):
        v = self.wb.read(self.ba+0x4000+coords[0]+coords[1]*self.grid_size[0])
        return v
    def print_cell_states(self):
        for i in range(self.grid_size[1]):
            line = ""
            for e in range(self.grid_size[0]):
                line += "%02d " % (self.read_cell_state((e,i)))
            print(line)
        return 0
        
    def start(self):
        self.wb.write(self.ba+0x0,1)
    def stop(self):
        self.wb.write(self.ba+0x0,0)
    def reset(self):
        self.wb.write(self.ba+0x0,2)
    def set_gen_limit(self,limit):
        self.wb.write(self.ba+0x1,limit)
    def set_unlimited_gen(self):
        self.set_gen_limit(0)
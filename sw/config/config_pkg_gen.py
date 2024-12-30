#!/usr/bin/python3
#-------------------------------------------------------------------------------
# PROJECT: CELLULAR AUTOMATON FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

from argparse import ArgumentParser
from math import log, ceil

# Helper functions
def my_bin(number,digits):
    str = bin(number)
    str = str[2:]
    diff = digits-len(str)
    if (diff>=0):
        str = "0"*(digits-len(str))+str
    else:
        str = str[-digits:]
    return str

# Configuration class
class cell_auto_config:
    def __init__(self,init_in_file,trans_tab_in_file,out_file,rom_ways,max_m_blocks):
        self.init_in_file      = init_in_file
        self.trans_tab_in_file = trans_tab_in_file
        self.out_file          = out_file
        self.rom_ways          = rom_ways
        self.max_m_blocks   = max_m_blocks

        self.is_five_conn   = None
        self.rows           = None
        self.cols           = None
        self.state_w        = None
        self.init_state     = None
        self.trans_list     = None
        self.rom_addr_width = None
        self.act_rom_items  = None

        self.error = 0

        val0 = self.parse_init_file()
        if (self.error):
            return
        val1 = self.parse_trans_file()
        if (self.error):
            return
        max_val = val0 if (val0>val1) else val1
        self.state_w = ceil(log(max_val+1,2))

    def parse_init_file(self):
        self.init_state = []
        with open(self.init_in_file,"r") as f:
            for line in f:
                line = line.split(" ")
                if (len(line)==0):
                    break
                self.init_state.append([])
                for v in line:
                    if (len(v)==0):
                        break
                    self.init_state[-1].append(int(v))
        if (len(self.init_state)==0):
            print("Error: Input file "+self.init_in_file+" contains 0 readable rows.")
            self.error = -1
            return self.error
        self.rows = len(self.init_state)
        self.cols = len(self.init_state[0])
        print("Detected automaton size: "+str(self.cols)+"x"+str(self.rows))
        max_val = 1
        #print("init state:")
        for i,r in enumerate(self.init_state):
            #print(i,r)
            if (len(r)!=self.cols):
                print("Error: Input file "+self.init_in_file+" contains "+str(self.cols)+" readable columns on row 0 but "+str(len(r))+" readable columns on row "+str(i)+".")
                self.error = -1
                return self.error
            for v in r:
                if (v>max_val):
                    max_val = v
        return max_val

    def parse_trans_file(self):
        self.trans_list = []
        max_val = 1
        with open(self.trans_tab_in_file,"r") as f:
            for line in f:
                line = line.split("#")[0].strip()
                if (len(line)==0):
                    continue # Skip empty line
                (i,o) = [x.strip() for x in line.split(":")]
                i = i.split(" ")
                #print("in: "+str(i))
                #print("out: "+str(o))
                if (self.is_five_conn==None):
                    self.is_five_conn = (len(i)==5)
                if (self.is_five_conn and len(i)!=5):
                    print("Error: Transition table in input file "+self.trans_tab_in_file+" detected as five-connected, but line "+line+" contains "+str(len(i))+" inputs.")
                    self.error = -2
                    return self.error
                if (not self.is_five_conn and len(i)!=9):
                    print("Error: Transition table in input file "+self.trans_tab_in_file+" detected as nine-connected, but line "+line+" contains "+str(len(i))+" inputs.")
                    self.error = -2
                    return self.error

                i = tuple([int(x) for x in i])
                o = int(o)
                self.trans_list.append((i,o))

                for v in i:
                    if (v>max_val):
                        max_val = v
                if (o>max_val):
                    max_val = o

        print("ROM ways set:",self.rom_ways)
        print("Explicit transition rules parsed:",len(self.trans_list))
        if (len(self.trans_list)==0):
            print("Zero explicit rules found; Adding one default 5-connected rule '0 0 0 0 0 : 0'")
            self.trans_list.append(((0,0,0,0,0),0))
            self.is_five_conn = True
        rule_zero = self.trans_list[0]

        if (len(self.trans_list)%self.rom_ways!=0):
            print("Adding",self.rom_ways-(len(self.trans_list)%self.rom_ways),"copies of one of the rules to make divisible by",self.rom_ways)
            for i in range(self.rom_ways-(len(self.trans_list)%self.rom_ways)):
                self.trans_list.append(rule_zero)

        self.act_rom_items = len(self.trans_list)//self.rom_ways
        print("Number of actually valid ROM items:",self.act_rom_items)
        self.rom_addr_width = ceil(log(self.act_rom_items,2))
        target_rom_items = 2**self.rom_addr_width;
        print("Adding",target_rom_items-self.act_rom_items,"copies of one of the rules to make number of ROM items a power of 2")
        for i in range(target_rom_items-self.act_rom_items):
            self.trans_list += [rule_zero for x in range(self.rom_ways)]

        print("Resulting number of explicit transition rules:",len(self.trans_list))
        print("Number of ROM items which will actually be checked in each calculation step:",self.act_rom_items)
        print("Number of clock cycles required for each calculation step: %d+%d=%d" % (self.act_rom_items,3,self.act_rom_items+3))

        return max_val

    def write_init_state_def(self,f):
        f.write("    -- Initial State\n")
        f.write("    -- It is written using 'x => y' notation, so it would work even when one of the dimensions has size 1.\n")
        f.write("    constant INIT_STATE     : cell_field_t := (")
        l = ""
        for i in range(self.rows-1,-1,-1):
            l += " %03d => (" % (i)
            l += ",".join(' %03d => "%s"' % (e,my_bin(s,self.state_w)) for e,s in enumerate(self.init_state[i]))
            l += ")"
            if (i>0):
                l += ",\n"
            else:
                l += ");\n"
            f.write(l);
            l = "                                               "
        f.write("\n")

    def write_trans_rule_rom(self,f):
        f.write("    -- Transition rule ROM itself\n")
        f.write("    -- It is written using 'x => y' notation, so it would work even when one of the dimensions has size 1.\n")
        f.write("    constant TRANS_RULE_ROM : trans_rule_rom_t := (")
        l = ""
        for i in range(2**self.rom_addr_width-1,-1,-1):
            l += " %03d => (" % (i)
            for e in range(self.rom_ways-1,-1,-1):
                l += " %03d => (" % (e)
                l += '"%s",' % (my_bin(self.trans_list[i*self.rom_ways+e][1],self.state_w))
                l += ",".join(['"%s"' % (my_bin(in_s,self.state_w)) for in_s in self.trans_list[i*self.rom_ways+e][0][::-1]])
                l += ")"
                if (e==0):
                    l += ")"
                    if (i==0):
                        l += ");"
                    else:
                        l += ","
                else:
                    l += ","
                l += "\n"
                f.write(l)
                l = "                                                   "
                if (e!=0):
                    l += "         "
        f.write("\n")

    def generate_pkg_file(self):
        with open(self.out_file,'w') as f:
            # Header
            f.write("--------------------------------------------------------------------------------\n")
            f.write("-- PROJECT: CELLULAR AUTOMATON FPGA\n")
            f.write("--------------------------------------------------------------------------------\n")
            f.write("-- AUTHORS: Jan Kubalek <kubalekj492@gmail.com>\n")
            f.write("-- LICENSE: The MIT License, please read LICENSE file\n")
            f.write("--------------------------------------------------------------------------------\n")
            f.write("-- This is a generated file containing definition of variables\n")
            f.write("-- for initial configuration and transition table of the Cellular Automaton.\n")
            f.write("library IEEE;\n")
            f.write("use IEEE.std_logic_1164.all;\n")
            f.write("use IEEE.numeric_std.all;\n")
            f.write("\n")

            # Package declarations and correct definitions
            f.write("package CELLULAR_AUTOMATON_CONFIG_PKG is\n")

            # Constant part of the package
            f.write("""
    -- 2-logarithm function
    function log2(number : integer) return integer;

    -- Number of cells in one ROW
    constant ROW_SIZE      : integer := %d;
    -- Number of cells in one COLUMN
    constant COL_SIZE      : integer := %d;

    -- Converting connection type to number
    constant CONNECTION_NUM : integer := %d;

    -- Width of signal in which a Cell state is expressed
    constant C_STATE_WIDTH : integer := %d;

    -- Number of parallel ways in Cell associative ROM for transition rules
    constant WAYS_N : integer := %d;

    -- Address width of Cell associative ROM for transition rules
    constant ROM_ADDR_WIDTH : integer := %d;

    -- Number of actually valid ROM items
    constant ACT_ROM_ITEMS : integer := %d;

    -- Number of cycles needed to complete one calculation step
    constant GEN_CYCLES : integer := ACT_ROM_ITEMS+3;

    -- Maximum number of Cells, which can store their ROM in an M-RAM block
    constant MAX_M_BLOCKS : integer := %d;

    -- Cell grid types
    type cell_state_t    is array (C_STATE_WIDTH -1 downto 0) of std_logic;
    type cell_row_t      is array (ROW_SIZE      -1 downto 0) of cell_state_t;
    type cell_field_t    is array (COL_SIZE      -1 downto 0) of cell_row_t;
    type neigh_t         is array (CONNECTION_NUM-1 downto 0) of cell_state_t;
    type neigh_arr_t     is array (ROW_SIZE      -1 downto 0) of neigh_t;
    type neigh_arr_2d_t  is array (COL_SIZE      -1 downto 0) of neigh_arr_t;

    -- Vector array types
    type trans_rule_t      is array (CONNECTION_NUM+1 -1 downto 0) of cell_state_t; -- ('high => output, others => input)
    type trans_rule_pack_t is array (WAYS_N           -1 downto 0) of trans_rule_t;
    type trans_rule_rom_t  is array (2**ROM_ADDR_WIDTH-1 downto 0) of trans_rule_pack_t;

""" % (self.cols,self.rows,5 if (self.is_five_conn) else 9,self.state_w,self.rom_ways,self.rom_addr_width,self.act_rom_items,self.max_m_blocks))

            # Init state declaration and definition
            self.write_init_state_def(f)

            # Transition rules ROM declaration and definition
            self.write_trans_rule_rom(f)

            f.write("    -- -------------------------------------------------------------------------\n")
            f.write("\n")
            f.write("end CELLULAR_AUTOMATON_CONFIG_PKG;\n")
            f.write("\n")

            # Package body (constant)
            f.write("package body CELLULAR_AUTOMATON_CONFIG_PKG is\n")
            f.write("""

    -- -------------------------------------------------------------------------

    function log2(number : integer) return integer is
        variable w : integer := 0;
    begin
        if (number<1) then
            return 0;
        end if;

        while (2**w<number) loop
            w := w+1;
        end loop;

        return w;
    end function;

    -- -------------------------------------------------------------------------

""")
            f.write("end;\n")

if (__name__=="__main__"):
    # Define parameters
    parser = ArgumentParser()

    parser.add_argument("init_state_file",help="Name of input '.cas' file with initial automaton state")
    parser.add_argument("trans_table_file",help="Name of input '.tab 'file with explicit automaton transition rules")
    parser.add_argument("--rom_ways",type=int,default=4,help="Number of parallel ways in Cell associative ROM for transition rules (default: 4)")
    parser.add_argument("--max_m_block_cells",type=int,default=0,help="Maximum number of Cells, which can store their ROM in an M-RAM block (the rest will be logic LUTs instead) (default: 0)")
    parser.add_argument("--vhdl_pkg_output",default="../../rtl/comp/cellular_automaton/cellular_automaton_config_pkg.vhd",help="Name of output file (default: ../../rtl/comp/cellular_automaton/cellular_automaton_config_pkg.vhd)")

    # Parse arguments
    args = parser.parse_args()

    # Run configuration generator
    ca_config = cell_auto_config(args.init_state_file,args.trans_table_file,args.vhdl_pkg_output,args.rom_ways,args.max_m_block_cells)
    if (ca_config.error!=0):
        exit(ca_config.error)
    ca_config.generate_pkg_file()


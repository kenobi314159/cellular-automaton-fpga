--------------------------------------------------------------------------------
-- PROJECT: CELLULAR AUTOMATON FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------
-- This is a generated file containing definition of variables
-- for initial configuration and transition table of the Cellular Automaton.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package CELLULAR_AUTOMATON_CONFIG_PKG is

    -- 2-logarithm function
    function log2(number : integer) return integer;
    
    -- Number of cells in one ROW
    constant ROW_SIZE      : integer := 12;
    -- Number of cells in one COLUMN
    constant COL_SIZE      : integer := 8;

    -- Converting connection type to number
    constant CONNECTION_NUM : integer := 5;

    -- Width of signal in which a Cell state is expressed
    constant C_STATE_WIDTH : integer := 2;

    -- Number of parallel ways in Cell associative ROM for transition rules
    constant WAYS_N : integer := 4;

    -- Address width of Cell associative ROM for transition rules
    constant ROM_ADDR_WIDTH : integer := 1;

    -- Number of actually valid ROM items
    constant ACT_ROM_ITEMS : integer := 2;

    -- Number of cycles needed to complete one calculation step
    constant GEN_CYCLES : integer := ACT_ROM_ITEMS+3;

    -- Maximum number of Cells, which can store their ROM in an M-RAM block
    constant MAX_M_BLOCKS : integer := 0;

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

    -- Initial State
    -- It is written using 'x => y' notation, so it would work even when one of the dimensions has size 1.
    constant INIT_STATE     : cell_field_t := ( 007 => ( 000 => "00", 001 => "00", 002 => "00", 003 => "00", 004 => "00", 005 => "00", 006 => "00", 007 => "00", 008 => "00", 009 => "00", 010 => "00", 011 => "00"),
                                                006 => ( 000 => "00", 001 => "00", 002 => "00", 003 => "00", 004 => "00", 005 => "00", 006 => "00", 007 => "00", 008 => "00", 009 => "00", 010 => "00", 011 => "00"),
                                                005 => ( 000 => "00", 001 => "01", 002 => "00", 003 => "00", 004 => "00", 005 => "00", 006 => "00", 007 => "01", 008 => "00", 009 => "00", 010 => "00", 011 => "00"),
                                                004 => ( 000 => "01", 001 => "01", 002 => "00", 003 => "00", 004 => "00", 005 => "00", 006 => "01", 007 => "01", 008 => "00", 009 => "00", 010 => "00", 011 => "00"),
                                                003 => ( 000 => "00", 001 => "00", 002 => "00", 003 => "00", 004 => "00", 005 => "00", 006 => "00", 007 => "00", 008 => "00", 009 => "00", 010 => "00", 011 => "00"),
                                                002 => ( 000 => "00", 001 => "00", 002 => "00", 003 => "00", 004 => "00", 005 => "00", 006 => "00", 007 => "00", 008 => "00", 009 => "00", 010 => "00", 011 => "00"),
                                                001 => ( 000 => "00", 001 => "01", 002 => "00", 003 => "00", 004 => "00", 005 => "00", 006 => "00", 007 => "01", 008 => "00", 009 => "00", 010 => "00", 011 => "00"),
                                                000 => ( 000 => "01", 001 => "01", 002 => "00", 003 => "00", 004 => "00", 005 => "00", 006 => "01", 007 => "01", 008 => "00", 009 => "00", 010 => "00", 011 => "00"));

    -- Transition rule ROM itself
    -- It is written using 'x => y' notation, so it would work even when one of the dimensions has size 1.
    constant TRANS_RULE_ROM : trans_rule_rom_t := ( 001 => ( 003 => ("00","00","01","01","00","00"),
                                                             002 => ("01","00","00","00","00","11"),
                                                             001 => ("01","00","00","11","10","00"),
                                                             000 => ("01","00","11","10","00","00")),
                                                    000 => ( 003 => ("11","00","00","00","10","00"),
                                                             002 => ("10","00","00","01","00","01"),
                                                             001 => ("00","01","00","01","01","00"),
                                                             000 => ("00","00","01","01","00","00")));

    -- -------------------------------------------------------------------------

end CELLULAR_AUTOMATON_CONFIG_PKG;

package body CELLULAR_AUTOMATON_CONFIG_PKG is


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

end;

--------------------------------------------------------------------------------
-- PROJECT: CELLULAR AUTOMATON FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.CELLULAR_AUTOMATON_CONFIG_PKG.all;

-- ----------------------------------------------------------------------------
--                           Entity Declaration
-- ----------------------------------------------------------------------------

entity CELL is
generic(
    -- Cell's position in the field
    ROW : integer;
    COL : integer
);
port(
    CLK   : in  std_logic;
    RESET : in  std_logic;

    -- SW Control
    SW_EN      : in  std_logic;
    SW_RESET   : in  std_logic;

    -- States of the Cells neighbours
    NEIGHBOURS : in  neigh_t;

    -- State of this Cell
    STATE      : buffer cell_state_t;

    -- Forced state overwrite from outside
    FORCED_STATE     : cell_state_t;
    FORCED_STATE_EN  : std_logic
);
end entity;

-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
--                             Architecture
-- ----------------------------------------------------------------------------

architecture FULL of CELL is

    -- -------------------------------------------------------------------------
    -- Internal FSM
    -- -------------------------------------------------------------------------

    type state_t is (S_INIT,S_CMP,S_FINAL_CMP,S_NEXT_GEN);
    signal present_st : state_t;
    signal next_st    : state_t;

    -- -------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- Cell State transition
    -- -------------------------------------------------------------------------

    signal neigh_reg    : neigh_t;

    signal rom          : trans_rule_rom_t := TRANS_RULE_ROM;
    signal rom_addr_reg : unsigned(ROM_ADDR_WIDTH-1 downto 0);
    signal rom_do_reg   : trans_rule_pack_t;

    signal next_cell_state_reg : cell_state_t;

    -- -------------------------------------------------------------------------

    function get_ram_type return string is
    begin
        if (ROW*ROW_SIZE+COL>=MAX_M_BLOCKS) then
            return "no_rw_check, logic";
        end if;
        return "no_rw_check, M-RAM";
    end function;

    attribute ramstyle : string;
    attribute ramstyle of rom : signal is get_ram_type;

begin

    -- -------------------------------------------------------------------------
    -- Internal FSM
    -- -------------------------------------------------------------------------

    st_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
            present_st <= next_st;
            if (RESET='1' or SW_RESET='1') then
                present_st <= S_INIT;
            end if;
        end if;
    end process;

    fsm_pr : process (present_st,SW_EN,rom_addr_reg)
    begin
        next_st <= present_st;

        case present_st is
            when S_INIT      =>
                if (SW_EN='1') then
                    next_st <= S_CMP;
                end if;

            when S_CMP       =>
                if (rom_addr_reg=ACT_ROM_ITEMS-1) then
                    next_st <= S_FINAL_CMP;
                end if;

            when S_FINAL_CMP =>
                next_st <= S_NEXT_GEN;

            when S_NEXT_GEN  =>
                next_st <= S_INIT;

            when others      =>
                next_st <= S_INIT;
        end case;
    end process;

    -- -------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- Cell State transition
    -- -------------------------------------------------------------------------

    neigh_reg_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
            -- Store input vector
            if (present_st=S_INIT) then
                neigh_reg <= NEIGHBOURS;
            end if;
        end if;
    end process;

    rom_addr_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
            -- Increment over all valid items in ROM
            if (present_st=S_CMP) then
                rom_addr_reg <= rom_addr_reg+1;
            end if;
            -- Reset to addr 0 to start new comparison
            if (present_st=S_INIT) then
                rom_addr_reg <= (others => '0');
            end if;
        end if;
    end process;

    rom_do_reg_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
            -- Read from ROM with 1 CLK latency
            rom_do_reg <= rom(to_integer(rom_addr_reg));
        end if;
    end process;

    mext_cell_state_reg_pr : process (CLK)
        variable cmp_successful : std_logic;
    begin
        if (rising_edge(CLK)) then

            -- Compare to read from ROM and load new valid transition, if comparison is succesful
            cmp_successful := '0';
            if (present_st=S_CMP or present_st=S_FINAL_CMP) then

                for i in 0 to WAYS_N-1 loop

                    cmp_successful := '1';
                    for e in 0 to CONNECTION_NUM-1 loop

                        if (neigh_reg(e)/=rom_do_reg(i)(e)) then
                            cmp_successful := '0';
                        end if;

                    end loop;

                    if (cmp_successful='1') then
                        next_cell_state_reg <= rom_do_reg(i)(CONNECTION_NUM);
                    end if;

                end loop;

            end if;

            -- By default stay in the same state as now
            if (present_st=S_INIT) then
                next_cell_state_reg <= STATE;
            end if;

        end if;
    end process;

    cell_state_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
            -- Update Cell State after comparison is done
            if (present_st=S_NEXT_GEN) then
                STATE <= next_cell_state_reg;
            end if;
            -- Overwrite state if forced
            if (FORCED_STATE_EN='1') then
                STATE <= FORCED_STATE;
            end if;
            if (RESET='1' or SW_RESET='1') then
                STATE <= INIT_STATE(ROW)(COL);
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------

end architecture;


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

entity CELLULAR_AUTOMATON is
generic (
    -- Number of LEDs to be controlled
    LEDS_NUM      : integer := 8
);
port (
    CLK     : in  std_logic;
    RESET   : in  std_logic;

    -- ----------------------------------------
    -- WISHBONE slave interface
    -- ----------------------------------------
    -- Address Space:
    -- 0x0000 - Control Register (R/W)
    --          Write 0 to Stop
    --          Write 1 to Start/Resume
    --          Write 2 to Reset and Stop
    -- 0x0001 - Generations Limit Register (R/W)
    --          Write number of generations to count (Only when stopped)
    --          Write 0 for unlimited counting
    -- 0x0002 - Current Generation Register (R/-)
    --          Index of generation after last Control Register Reset
    --          Might overflow when Generations Limit is set to 0
    -- 0x0003 - Configured Column Size Register (R/-)
    -- 0x0004 - Configured Row Size Register (R/-)
    -- 0x0003-0x3FFF - 0xDEADCAFE
    -- 0x4000-0x7FFF - Cells' States (R/-)
    --                 Read current Cell's State (anytime)
    --                 0xDEADBEEF when out of bounds
    -- Cells addressing:
    --   0 1 2
    --   3 4 5
    --   6 7 8
    WB_CYC   : in  std_logic;
    WB_STB   : in  std_logic;
    WB_WE    : in  std_logic;
    WB_ADDR  : in  std_logic_vector(16-1 downto 0);
    WB_DIN   : in  std_logic_vector(32-1 downto 0);
    WB_STALL : out std_logic; -- not ARDY
    WB_ACK   : out std_logic; -- DRDY
    WB_DOUT  : out std_logic_vector(32-1 downto 0);
    
    -- ----------------------------------------

    -- ----------------------------------------
    -- LEDs control
    -- ----------------------------------------

    LED_OUT  : out std_logic_vector(LEDS_NUM-1 downto 0)

    -- ----------------------------------------
);
end entity;

-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
--                             Architecture
-- ----------------------------------------------------------------------------

architecture FULL of CELLULAR_AUTOMATON is

    -- -------------------------------------------------------------------------
    -- Constants
    -- -------------------------------------------------------------------------

    -- Type for field of sells in one long row
    type cell_long_row_t is array (ROW_SIZE*COL_SIZE-1 downto 0) of cell_state_t;

    -----------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- Signals
    -- -------------------------------------------------------------------------

    signal WB_WR : std_logic;
    signal WB_RD : std_logic;

    signal control_reg     : std_logic;
    signal start_reg       : std_logic;
    
    signal gen_limit_reg : unsigned(32-1 downto 0);
    signal gen_curr_reg  : unsigned(32-1 downto 0);
    
    signal gen_cycle_reg : unsigned(log2(GEN_CYCLES)-1 downto 0);

    signal cells_en         : std_logic;
    signal cells_reset      : std_logic;
    signal cell_neighbours  : neigh_arr_2d_t;
    signal cell_state       : cell_field_t;
    signal cell_state_lined : cell_long_row_t;

    constant BLINK_CNT_WIDTH     : integer := 26;
    constant PROGRESS_STEP_WIDTH : integer := log2(LEDS_NUM);
    signal blink_cnt_reg         : unsigned(BLINK_CNT_WIDTH-1 downto 0);
    signal next_progress_gen_reg : unsigned(32-1 downto 0);
    signal next_progress_led     : unsigned(log2(LEDS_NUM)-1 downto 0);
    signal leds_blink            : std_logic_vector(2**(log2(LEDS_NUM))-1 downto 0);
    signal leds_progress         : std_logic_vector(2**(log2(LEDS_NUM))-1 downto 0);
    
    ---------------------------------------------------------------------------

begin

    WB_STALL <= '0'; -- Allways ready for requests
    WB_WR    <= WB_STB and WB_WE;
    WB_RD    <= WB_CYC and WB_STB and (not WB_WE);

    -- -------------------------------------------------------------------------
    -- Control Register
    -- -------------------------------------------------------------------------

    control_reg_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then

            start_reg <= '0';
            -- Writing from WB
            if (WB_WR='1' and unsigned(WB_ADDR)=0) then
                if (unsigned(WB_DIN)=2) then -- Reset
                    control_reg     <= '0';
                elsif (unsigned(WB_DIN)=1) then -- Start
                    control_reg     <= WB_DIN(0);
                    start_reg       <= '1';
                elsif (unsigned(WB_DIN)=0) then -- Stop
                    control_reg     <= WB_DIN(0);
                end if;
            end if;

            if (RESET='1') then
                control_reg     <= '0';
                start_reg       <= '0';
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    
    -- -------------------------------------------------------------------------
    -- Generations Limit Register
    -- -------------------------------------------------------------------------

    gen_limit_reg_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
        
            -- Writing new value when stopped
            if (control_reg='0' and WB_WR='1' and unsigned(WB_ADDR)=1) then
                gen_limit_reg <= unsigned(WB_DIN);
            end if;

            if (RESET='1') then
                gen_limit_reg <= (gen_limit_reg'high => '1', others => '0');
            end if;
        end if;
    end process;

    gen_curr_reg_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
        
            -- Increment when running until limit is reached
            if (gen_cycle_reg=GEN_CYCLES-1) then
                gen_curr_reg <= gen_curr_reg+1;
            end if;

            -- Control Register Reset
            if (cells_reset='1') then
                gen_curr_reg <= (others => '0');
            end if;

            if (RESET='1') then
                gen_curr_reg <= (others => '0');
            end if;
        end if;
    end process;
    
    gen_cycle_reg_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
            -- Simulate cycle of the Cell's internal FSM
            if (gen_cycle_reg/=0 or cells_en='1') then
                gen_cycle_reg <= gen_cycle_reg+1;
                if (gen_cycle_reg=GEN_CYCLES-1) then
                    gen_cycle_reg <= (others => '0');
                end if;
            end if;
            if (RESET='1' or cells_reset='1') then
                gen_cycle_reg <= (others => '0');
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    
    -- -------------------------------------------------------------------------
    -- Wishbone Reading Register
    -- -------------------------------------------------------------------------
    
    wb_din_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
            -- Allways send response after 1 cycle
            WB_ACK <= WB_STB and WB_CYC;
            
            -- Reading on WB
            if (WB_ADDR(14)='0') then
                WB_DOUT <= X"DEADCAFE";
                if    (unsigned(WB_ADDR)=0) then
                    WB_DOUT <= (0 => control_reg, others => '0');
                elsif (unsigned(WB_ADDR)=1) then
                    WB_DOUT <= std_logic_vector(gen_limit_reg);
                elsif (unsigned(WB_ADDR)=2) then
                    WB_DOUT <= std_logic_vector(gen_curr_reg);
                elsif (unsigned(WB_ADDR)=3) then
                    WB_DOUT <= std_logic_vector(to_unsigned(COL_SIZE, 32));
                elsif (unsigned(WB_ADDR)=4) then
                    WB_DOUT <= std_logic_vector(to_unsigned(ROW_SIZE, 32));
                end if;
            else
                WB_DOUT <= X"DEADBEEF";
                if (unsigned(WB_ADDR(14-1 downto 0))<COL_SIZE*ROW_SIZE) then
                    WB_DOUT <= std_logic_vector(resize(unsigned(cell_state_lined(to_integer(unsigned(WB_ADDR(14-1 downto 0))))),WB_DOUT'length));
                end if;
            end if;
            if (RESET='1') then
                WB_ACK <= '0';
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- Cellular Automaton Cells field
    -- -------------------------------------------------------------------------

    cells_en    <= '1' when control_reg='1' and (gen_curr_reg<gen_limit_reg or gen_limit_reg=0) else '0';
    cells_reset <= '1' when WB_WR='1' and unsigned(WB_ADDR)=0 and unsigned(WB_DIN)=2 else '0';

    cell_field_g : for i in 0 to COL_SIZE-1 generate
        cell_row_g : for e in 0 to ROW_SIZE-1 generate
            cell_i : entity work.CELL
            generic map(
                ROW => i,
                COL => e
            )
            port map(
                CLK        => CLK  ,
                RESET      => RESET,

                SW_EN      => cells_en   ,
                SW_RESET   => cells_reset,

                NEIGHBOURS => cell_neighbours(i)(e),
                STATE      => cell_state     (i)(e)
            );
        end generate;
    end generate;

    cell_connection_p : process (cell_state)
        variable r_u : integer;
        variable r_d : integer;
        variable c_l : integer;
        variable c_r : integer;
    begin
        cell_neighbours <= (others => (others => (others => (others => '0'))));

        for r in 0 to COL_SIZE-1 loop
            
            if (r=0) then
                r_u := COL_SIZE-1;
            else
                r_u := r-1;
            end if;

            if (r=COL_SIZE-1) then
                r_d := 0;
            else
                r_d := r+1;
            end if;

            for c in 0 to ROW_SIZE-1 loop

                if (c=0) then
                    c_l := ROW_SIZE-1;
                else
                    c_l := c-1;
                end if;

                if (c=ROW_SIZE-1) then
                    c_r := 0;
                else
                    c_r := c+1;
                end if;

                if    (CONNECTION_NUM=5) then
                    cell_neighbours(r)(c)(0) <= cell_state(r_u)(c  );
                    cell_neighbours(r)(c)(1) <= cell_state(r  )(c_l);
                    cell_neighbours(r)(c)(2) <= cell_state(r  )(c  );
                    cell_neighbours(r)(c)(3) <= cell_state(r  )(c_r);
                    cell_neighbours(r)(c)(4) <= cell_state(r_d)(c  );
                elsif (CONNECTION_NUM=9) then
                    cell_neighbours(r)(c)(0) <= cell_state(r_u)(c_l);
                    cell_neighbours(r)(c)(1) <= cell_state(r_u)(c  );
                    cell_neighbours(r)(c)(2) <= cell_state(r_u)(c_r);
                    cell_neighbours(r)(c)(3) <= cell_state(r  )(c_l);
                    cell_neighbours(r)(c)(4) <= cell_state(r  )(c  );
                    cell_neighbours(r)(c)(5) <= cell_state(r  )(c_r);
                    cell_neighbours(r)(c)(6) <= cell_state(r_d)(c_l);
                    cell_neighbours(r)(c)(7) <= cell_state(r_d)(c  );
                    cell_neighbours(r)(c)(8) <= cell_state(r_d)(c_r);
                end if;

            end loop;
        end loop;

    end process;

    -- Cell state lining
    cell_state_lining_p : process (cell_state)
    begin
        for i in 0 to COL_SIZE-1 loop
            for e in 0 to ROW_SIZE-1 loop
                cell_state_lined(i*ROW_SIZE+e) <= cell_state(i)(e);
            end loop;
        end loop;
    end process;

    -- -------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- LEDs control
    -- -------------------------------------------------------------------------

    -- counter for LEDs blinking
    leds_blink_cnt_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            blink_cnt_reg <= blink_cnt_reg+1;
            if (RESET='1') then
                blink_cnt_reg <= (others => '0');
            end if;
        end if;
    end process;

    -- LEDs blinking
    leds_blink_p : process (blink_cnt_reg)
    begin
        leds_blink <= (others => '0');
        leds_blink(to_integer(blink_cnt_reg(BLINK_CNT_WIDTH-1 downto BLINK_CNT_WIDTH-log2(LEDS_NUM)))) <= '1';
    end process;

    -- Comparator for LEDs progress display
    next_progress_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (start_reg='1') then
                -- set first progress line
                next_progress_gen_reg <= (others => '0');
                next_progress_gen_reg(32-PROGRESS_STEP_WIDTH-1 downto 0) <= unsigned(gen_limit_reg(32-1 downto PROGRESS_STEP_WIDTH));
                -- shut down progress LEDs
                leds_progress         <= (others => '0');
                -- set pointer to the 0th LED
                next_progress_led     <= (others => '0');
            elsif (control_reg='1') then
                if (next_progress_gen_reg<=gen_curr_reg) then
                    -- set new progress line
                    next_progress_gen_reg <= next_progress_gen_reg+unsigned(gen_limit_reg(32-1 downto PROGRESS_STEP_WIDTH));
                    -- add new LED to progress bar
                    leds_progress(to_integer(next_progress_led)) <= '1';
                    -- set pointer to the next LED
                    next_progress_led     <= next_progress_led+1;
                end if;
            end if;

            -- reset progress
            if (RESET='1' or cells_reset='1') then
                next_progress_gen_reg <= (others => '0');
                next_progress_led     <= (others => '0');
                leds_progress         <= (others => '0');
            end if;
        end if;
    end process;

    -- Final LEDs setting
    LED_OUT  <= (leds_blink(leds_blink'high downto leds_blink'length-LEDS_NUM) or leds_progress(leds_progress'high downto leds_progress'length-LEDS_NUM)) and (LEDS_NUM-1 downto 0 => blink_cnt_reg(0));

    -- -------------------------------------------------------------------------

end architecture;


--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
--          Jan Kubalek <kubalekj492@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FPGA is
    Port (
        -- System clock and reset button
        CLK_12M     : in  std_logic;
        RST_BTN_N   : in  std_logic;
        -- UART interface
        UART_RXD    : in  std_logic;
        UART_TXD    : out std_logic;
        -- LED output
        LED_OUT     : out std_logic_vector(8-1 downto 0)
    );
end entity;

architecture FULL of FPGA is

    constant WB_BASE_PORTS  : natural := 2; -- System Module + Cellular Automat
    constant WB_BASE_OFFSET : natural := 15;

    signal rst_btn : std_logic;

    signal pll_locked   : std_logic;
    signal pll_locked_n : std_logic;

    signal clk_usr  : std_logic;
    signal rst_usr  : std_logic;
    signal rst_eth0 : std_logic;
    signal rst_eth1 : std_logic;

    signal wb_master_cyc   : std_logic;
    signal wb_master_stb   : std_logic;
    signal wb_master_we    : std_logic;
    signal wb_master_addr  : std_logic_vector(16-1 downto 0);
    signal wb_master_dout  : std_logic_vector(32-1 downto 0);
    signal wb_master_stall : std_logic;
    signal wb_master_ack   : std_logic;
    signal wb_master_din   : std_logic_vector(32-1 downto 0);

    signal wb_mbs_cyc   : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_stb   : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_we    : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_addr  : std_logic_vector(WB_BASE_PORTS*16-1 downto 0);
    signal wb_mbs_din   : std_logic_vector(WB_BASE_PORTS*32-1 downto 0);
    signal wb_mbs_stall : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_ack   : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_dout  : std_logic_vector(WB_BASE_PORTS*32-1 downto 0);

begin

    rst_btn <= not RST_BTN_N;

    pll_i : entity work.PLL
    port map (
        IN_CLK_12M     => CLK_12M,
        IN_RST_BTN     => rst_btn,
        OUT_PLL_LOCKED => pll_locked,
        OUT_CLK_25M    => open,
        OUT_CLK_50M    => clk_usr
    );

    pll_locked_n <= not pll_locked;

    rst_usr_sync_i : entity work.RST_SYNC
    port map (
        CLK        => clk_usr,
        ASYNC_RST  => pll_locked_n,
        SYNCED_RST => rst_usr
    );
    uart2wbm_i : entity work.UART2WBM
    generic map (
        CLK_FREQ  => 50e6,
        BAUD_RATE => 9600
    )
    port map (
        CLK      => clk_usr,
        RST      => rst_usr,
        -- UART INTERFACE
        UART_TXD => UART_TXD,
        UART_RXD => UART_RXD,
        -- WISHBONE MASTER INTERFACE
        WB_CYC   => wb_master_cyc,
        WB_STB   => wb_master_stb,
        WB_WE    => wb_master_we,
        WB_ADDR  => wb_master_addr,
        WB_DOUT  => wb_master_dout,
        WB_STALL => wb_master_stall,
        WB_ACK   => wb_master_ack,
        WB_DIN   => wb_master_din
    );

    wb_splitter_base_i : entity work.WB_SPLITTER
    generic map (
        MASTER_PORTS => WB_BASE_PORTS,
        ADDR_OFFSET  => WB_BASE_OFFSET
    )
    port map (
        CLK        => clk_usr,
        RST        => rst_usr,

        WB_S_CYC   => wb_master_cyc,
        WB_S_STB   => wb_master_stb,
        WB_S_WE    => wb_master_we,
        WB_S_ADDR  => wb_master_addr,
        WB_S_DIN   => wb_master_dout,
        WB_S_STALL => wb_master_stall,
        WB_S_ACK   => wb_master_ack,
        WB_S_DOUT  => wb_master_din,

        WB_M_CYC   => wb_mbs_cyc,
        WB_M_STB   => wb_mbs_stb,
        WB_M_WE    => wb_mbs_we,
        WB_M_ADDR  => wb_mbs_addr,
        WB_M_DOUT  => wb_mbs_dout,
        WB_M_STALL => wb_mbs_stall,
        WB_M_ACK   => wb_mbs_ack,
        WB_M_DIN   => wb_mbs_din
    );

    sys_module_i : entity work.SYS_MODULE
    port map (
        -- CLOCK AND RESET
        CLK      => clk_usr,
        RST      => rst_usr,

        -- WISHBONE SLAVE INTERFACE
        WB_CYC   => wb_mbs_cyc(0),
        WB_STB   => wb_mbs_stb(0),
        WB_WE    => wb_mbs_we(0),
        WB_ADDR  => wb_mbs_addr((0+1)*16-1 downto 0*16),
        WB_DIN   => wb_mbs_dout((0+1)*32-1 downto 0*32),
        WB_STALL => wb_mbs_stall(0),
        WB_ACK   => wb_mbs_ack(0),
        WB_DOUT  => wb_mbs_din((0+1)*32-1 downto 0*32)
    );

    cellular_auto_i : entity work.CELLULAR_AUTOMATON
    generic map(
        LEDS_NUM => 8
    )
    port map(
        CLK      => clk_usr,
        RESET    => rst_usr,

        WB_CYC   => wb_mbs_cyc(1),
        WB_STB   => wb_mbs_stb(1),
        WB_WE    => wb_mbs_we(1),
        WB_ADDR  => wb_mbs_addr((1+1)*16-1 downto 1*16),
        WB_DIN   => wb_mbs_dout((1+1)*32-1 downto 1*32),
        WB_STALL => wb_mbs_stall(1),
        WB_ACK   => wb_mbs_ack(1),
        WB_DOUT  => wb_mbs_din((1+1)*32-1 downto 1*32),

        LED_OUT  => LED_OUT
    );

end architecture;

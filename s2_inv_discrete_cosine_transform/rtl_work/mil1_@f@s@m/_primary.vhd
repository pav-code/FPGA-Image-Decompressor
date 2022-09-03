library verilog;
use verilog.vl_types.all;
entity mil1_FSM is
    generic(
        Y_OFFSET        : integer := 0;
        U_EVEN_OFFSET   : integer := 38400;
        V_EVEN_OFFSET   : integer := 57600;
        RGB_OFFSET      : integer := 146944
    );
    port(
        CLOCK_50_I      : in     vl_logic;
        start           : in     vl_logic;
        finish          : out    vl_logic;
        Resetn          : in     vl_logic;
        PB_pushed       : in     vl_logic_vector(3 downto 0);
        SRAM_address    : out    vl_logic_vector(17 downto 0);
        SRAM_read_data  : in     vl_logic_vector(15 downto 0);
        SRAM_we_n       : out    vl_logic;
        SRAM_write_data : out    vl_logic_vector(15 downto 0);
        a               : in     vl_logic_vector(63 downto 0);
        b               : in     vl_logic_vector(63 downto 0);
        c               : in     vl_logic_vector(63 downto 0);
        d               : in     vl_logic_vector(63 downto 0);
        op1             : out    vl_logic_vector(31 downto 0);
        op2             : out    vl_logic_vector(31 downto 0);
        op3             : out    vl_logic_vector(31 downto 0);
        op4             : out    vl_logic_vector(31 downto 0);
        op5             : out    vl_logic_vector(31 downto 0);
        op6             : out    vl_logic_vector(31 downto 0);
        op7             : out    vl_logic_vector(31 downto 0);
        op8             : out    vl_logic_vector(31 downto 0)
    );
end mil1_FSM;

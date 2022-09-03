library verilog;
use verilog.vl_types.all;
entity VGA_Controller is
    generic(
        H_SYNC_CYC      : integer := 96;
        H_SYNC_BACK     : integer := 48;
        H_SYNC_ACT      : integer := 640;
        H_SYNC_TOTAL    : integer := 800;
        V_SYNC_CYC      : integer := 2;
        V_SYNC_BACK     : integer := 31;
        V_SYNC_ACT      : integer := 480;
        V_SYNC_TOTAL    : integer := 524
    );
    port(
        Clock           : in     vl_logic;
        Resetn          : in     vl_logic;
        iRed            : in     vl_logic_vector(9 downto 0);
        iGreen          : in     vl_logic_vector(9 downto 0);
        iBlue           : in     vl_logic_vector(9 downto 0);
        oCoord_X        : out    vl_logic_vector(9 downto 0);
        oCoord_Y        : out    vl_logic_vector(9 downto 0);
        oVGA_R          : out    vl_logic_vector(9 downto 0);
        oVGA_G          : out    vl_logic_vector(9 downto 0);
        oVGA_B          : out    vl_logic_vector(9 downto 0);
        oVGA_H_SYNC     : out    vl_logic;
        oVGA_V_SYNC     : out    vl_logic;
        oVGA_SYNC       : out    vl_logic;
        oVGA_BLANK      : out    vl_logic;
        oVGA_CLOCK      : out    vl_logic
    );
end VGA_Controller;

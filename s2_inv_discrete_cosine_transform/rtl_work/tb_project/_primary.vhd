library verilog;
use verilog.vl_types.all;
entity tb_project is
    generic(
        VIEW_AREA_LEFT  : integer := 160;
        VIEW_AREA_RIGHT : integer := 480;
        VIEW_AREA_TOP   : integer := 120;
        VIEW_AREA_BOTTOM: integer := 360
    );
end tb_project;

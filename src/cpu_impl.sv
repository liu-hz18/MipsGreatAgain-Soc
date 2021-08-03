`include "defines.svh"

module cpu_impl #(
    parameter BUS_WIDTH = 4
) (
    input wire aclk,
    input wire aresetn,

    input wire[5:0] ext_int,

    // ICACHE AXI signals
    output wire [BUS_WIDTH-1:0] icache_arid, 
    output wire [31:0] icache_araddr       , 
    output wire [3 :0] icache_arlen        , 
    output wire [2 :0] icache_arsize       , 
    output wire [1 :0] icache_arburst      , 
    output wire [1 :0] icache_arlock       , 
    output wire [3 :0] icache_arcache      , 
    output wire [2 :0] icache_arprot       , 
    output wire        icache_arvalid      ,
    input  wire        icache_arready      , 
    // Read data channel signals
    input  wire [BUS_WIDTH-1:0] icache_rid , 
    input  wire [31:0] icache_rdata        , 
    input  wire [1 :0] icache_rresp        ,
    input  wire        icache_rlast        ,
    input  wire        icache_rvalid       ,
    output wire        icache_rready       ,
    output wire [BUS_WIDTH-1:0] icache_awid, 
    output wire [31:0] icache_awaddr       , 
    output wire [3 :0] icache_awlen        , 
    output wire [2 :0] icache_awsize       , 
    output wire [1 :0] icache_awburst      , 
    output wire [1 :0] icache_awlock       , 
    output wire [3 :0] icache_awcache      , 
    output wire [2 :0] icache_awprot       , 
    output wire        icache_awvalid      , 
    input  wire        icache_awready      , 
    // Write data channel signals
    output wire [BUS_WIDTH-1:0] icache_wid , 
    output wire [31:0] icache_wdata        , 
    output wire [3 :0] icache_wstrb        , 
    output wire        icache_wlast        , 
    output wire        icache_wvalid       , 
    input  wire        icache_wready       , 
    // Write response channel
    input  wire [BUS_WIDTH-1:0] icache_bid , 
    input  wire [1 :0] icache_bresp        , 
    input  wire        icache_bvalid       , 
    output wire        icache_bready       ,

    // DCACHE AXI signals
    output wire [BUS_WIDTH-1:0] dcache_arid, 
    output wire [31:0] dcache_araddr       , 
    output wire [3 :0] dcache_arlen        , 
    output wire [2 :0] dcache_arsize       , 
    output wire [1 :0] dcache_arburst      , 
    output wire [1 :0] dcache_arlock       , 
    output wire [3 :0] dcache_arcache      , 
    output wire [2 :0] dcache_arprot       , 
    output wire        dcache_arvalid      ,
    input  wire        dcache_arready      , 
    // Read data channel signals
    input  wire [BUS_WIDTH-1:0] dcache_rid , 
    input  wire [31:0] dcache_rdata        , 
    input  wire [1 :0] dcache_rresp        ,
    input  wire        dcache_rlast        ,
    input  wire        dcache_rvalid       ,
    output wire        dcache_rready       ,
    
    // Write address(control) channel signals
    output wire [BUS_WIDTH-1:0] dcache_awid, 
    output wire [31:0] dcache_awaddr       , 
    output wire [3 :0] dcache_awlen        , 
    output wire [2 :0] dcache_awsize       , 
    output wire [1 :0] dcache_awburst      , 
    output wire [1 :0] dcache_awlock       , 
    output wire [3 :0] dcache_awcache      , 
    output wire [2 :0] dcache_awprot       , 
    output wire        dcache_awvalid      , 
    input  wire        dcache_awready      , 
    // Write data channel signals
    output wire [BUS_WIDTH-1:0] dcache_wid , 
    output wire [31:0] dcache_wdata        , 
    output wire [3 :0] dcache_wstrb        , 
    output wire        dcache_wlast        , 
    output wire        dcache_wvalid       , 
    input  wire        dcache_wready       , 
    // Write response channel
    input  wire [BUS_WIDTH-1:0] dcache_bid , 
    input  wire [1 :0] dcache_bresp        , 
    input  wire        dcache_bvalid       , 
    output wire        dcache_bready       , 

    // UNCACHED AXI signals
    // Read address(control) channel signals
    output wire [BUS_WIDTH-1:0] uncache_arid, 
    output wire [31:0] uncache_araddr       , 
    output wire [3 :0] uncache_arlen        , 
    output wire [2 :0] uncache_arsize       , 
    output wire [1 :0] uncache_arburst      , 
    output wire [1 :0] uncache_arlock       , 
    output wire [3 :0] uncache_arcache      , 
    output wire [2 :0] uncache_arprot       , 
    output wire        uncache_arvalid      ,
    input  wire        uncache_arready      , 
    // Read data channel signals
    input  wire [BUS_WIDTH-1:0] uncache_rid , 
    input  wire [31:0] uncache_rdata        , 
    input  wire [1 :0] uncache_rresp        ,
    input  wire        uncache_rlast        ,
    input  wire        uncache_rvalid       ,
    output wire        uncache_rready       ,
    
    // Write address(control) channel signals
    output wire [BUS_WIDTH-1:0] uncache_awid, 
    output wire [31:0] uncache_awaddr       , 
    output wire [3 :0] uncache_awlen        , 
    output wire [2 :0] uncache_awsize       , 
    output wire [1 :0] uncache_awburst      , 
    output wire [1 :0] uncache_awlock       , 
    output wire [3 :0] uncache_awcache      , 
    output wire [2 :0] uncache_awprot       , 
    output wire        uncache_awvalid      , 
    input  wire        uncache_awready      , 
    // Write data channel signals
    output wire [BUS_WIDTH-1:0] uncache_wid , 
    output wire [31:0] uncache_wdata        , 
    output wire [3 :0] uncache_wstrb        , 
    output wire        uncache_wlast        , 
    output wire        uncache_wvalid       , 
    input  wire        uncache_wready       , 
    // Write response channel
    input  wire [BUS_WIDTH-1:0] uncache_bid , 
    input  wire [1 :0] uncache_bresp        , 
    input  wire        uncache_bvalid       , 
    output wire        uncache_bready       , 

    // debug infos
    output wire[31:0] debug_wb_pc,      // wb stage
    output wire[3 :0] debug_wb_rf_wen,  // wb stage
    output wire[4 :0] debug_wb_rf_wnum, // wb stage
    output wire[31:0] debug_wb_rf_wdata // wb stage
);

axi_req_t ibus_axi_req, dbus_axi_req, duncached_axi_req;
axi_resp_t ibus_axi_resp, dbus_axi_resp, duncached_axi_resp;

// synchronize reset and clk
wire clk = aclk;
reg[2:0] sync_rst;
always_ff @(posedge clk) begin
    sync_rst <= { sync_rst[1:0], ~aresetn };
end
wire rst = sync_rst[2];

// ICACHE out ports assign
assign icache_arid = 4'b0000;
assign icache_araddr = ibus_axi_req.araddr;
assign icache_arlen = ibus_axi_req.arlen;
assign icache_arsize = ibus_axi_req.arsize;
assign icache_arburst = ibus_axi_req.arburst;
assign icache_arlock = ibus_axi_req.arlock;
assign icache_arcache = ibus_axi_req.arcache;
assign icache_arprot = ibus_axi_req.arprot;
assign icache_arvalid = ibus_axi_req.arvalid;
assign ibus_axi_resp.arready = icache_arready;
assign ibus_axi_resp.rdata = icache_rdata;
assign ibus_axi_resp.rresp = icache_rresp;
assign ibus_axi_resp.rlast = icache_rlast;
assign ibus_axi_resp.rvalid = icache_rvalid;
assign icache_rready = ibus_axi_req.rready;
assign icache_awid = 4'b0000;
assign icache_awaddr = ibus_axi_req.awaddr;
assign icache_awlen = ibus_axi_req.awlen;
assign icache_awsize = ibus_axi_req.awsize;
assign icache_awburst = ibus_axi_req.awburst;
assign icache_awlock = ibus_axi_req.awlock;
assign icache_awcache = ibus_axi_req.awcache;
assign icache_awprot = ibus_axi_req.awprot;
assign icache_awvalid = ibus_axi_req.awvalid;
assign ibus_axi_resp.awready = icache_awready;
assign icache_wid  = 4'b0000;
assign icache_wdata = ibus_axi_req.wdata;
assign icache_wstrb = ibus_axi_req.wstrb;
assign icache_wlast = ibus_axi_req.wlast;
assign icache_wvalid = ibus_axi_req.wvalid;
assign ibus_axi_resp.wready = icache_wready;
assign ibus_axi_resp.bresp = icache_bresp;
assign ibus_axi_resp.bvalid = icache_bvalid;
assign icache_bready = ibus_axi_req.bready;
// DCACHE out ports assign
assign dcache_arid = 4'b0001;
assign dcache_araddr = dbus_axi_req.araddr;
assign dcache_arlen = dbus_axi_req.arlen;
assign dcache_arsize = dbus_axi_req.arsize;
assign dcache_arburst = dbus_axi_req.arburst;
assign dcache_arlock = dbus_axi_req.arlock;
assign dcache_arcache = dbus_axi_req.arcache;
assign dcache_arprot = dbus_axi_req.arprot;
assign dcache_arvalid = dbus_axi_req.arvalid;
assign dbus_axi_resp.arready = dcache_arready;
assign dbus_axi_resp.rdata = dcache_rdata;
assign dbus_axi_resp.rresp = dcache_rresp;
assign dbus_axi_resp.rlast = dcache_rlast;
assign dbus_axi_resp.rvalid = dcache_rvalid;
assign dcache_rready = dbus_axi_req.rready;
assign dcache_awid = 4'b0001;
assign dcache_awaddr = dbus_axi_req.awaddr;
assign dcache_awlen = dbus_axi_req.awlen;
assign dcache_awsize = dbus_axi_req.awsize;
assign dcache_awburst = dbus_axi_req.awburst;
assign dcache_awlock = dbus_axi_req.awlock;
assign dcache_awcache = dbus_axi_req.awcache;
assign dcache_awprot = dbus_axi_req.awprot;
assign dcache_awvalid = dbus_axi_req.awvalid;
assign dbus_axi_resp.awready = dcache_awready;
assign dcache_wid  = 4'b0001;
assign dcache_wdata = dbus_axi_req.wdata;
assign dcache_wstrb = dbus_axi_req.wstrb;
assign dcache_wlast = dbus_axi_req.wlast;
assign dcache_wvalid = dbus_axi_req.wvalid;
assign dbus_axi_resp.wready = dcache_wready;
assign dbus_axi_resp.bresp = dcache_bresp;
assign dbus_axi_resp.bvalid = dcache_bvalid;
assign dcache_bready = dbus_axi_req.bready;
// UNCACHE out ports assign
assign uncache_arid = 4'b0010;
assign uncache_araddr = duncached_axi_req.araddr;
assign uncache_arlen = duncached_axi_req.arlen;
assign uncache_arsize = duncached_axi_req.arsize;
assign uncache_arburst = duncached_axi_req.arburst;
assign uncache_arlock = duncached_axi_req.arlock;
assign uncache_arcache = duncached_axi_req.arcache;
assign uncache_arprot = duncached_axi_req.arprot;
assign uncache_arvalid = duncached_axi_req.arvalid;
assign duncached_axi_resp.arready = uncache_arready;
assign duncached_axi_resp.rdata = uncache_rdata;
assign duncached_axi_resp.rresp = uncache_rresp;
assign duncached_axi_resp.rlast = uncache_rlast;
assign duncached_axi_resp.rvalid = uncache_rvalid;
assign uncache_rready = duncached_axi_req.rready;
assign uncache_awid = 4'b0010;
assign uncache_awaddr = duncached_axi_req.awaddr;
assign uncache_awlen = duncached_axi_req.awlen;
assign uncache_awsize = duncached_axi_req.awsize;
assign uncache_awburst = duncached_axi_req.awburst;
assign uncache_awlock = duncached_axi_req.awlock;
assign uncache_awcache = duncached_axi_req.awcache;
assign uncache_awprot = duncached_axi_req.awprot;
assign uncache_awvalid = duncached_axi_req.awvalid;
assign duncached_axi_resp.awready = uncache_awready;
assign uncache_wid  = 4'b0010;
assign uncache_wdata = duncached_axi_req.wdata;
assign uncache_wstrb = duncached_axi_req.wstrb;
assign uncache_wlast = duncached_axi_req.wlast;
assign uncache_wvalid = duncached_axi_req.wvalid;
assign duncached_axi_resp.wready = uncache_wready;
assign duncached_axi_resp.bresp = uncache_bresp;
assign duncached_axi_resp.bvalid = uncache_bvalid;
assign uncache_bready = duncached_axi_req.bready;

cpu_ibus_if ibus_if();
bit_t invalidate_icache;
word_t invalidate_addr;

ibus_controller #(
    .DATA_WIDTH(32),
    .LINE_WIDTH(`ICACHE_LINE_WIDTH),
    .SET_ASSOC(`ICACHE_SET_ASSOC),
    .CACHE_SIZE(`ICACHE_CACHE_SIZE)
) ibus_controller_instance  (
    .clk(clk),
    .rst(rst),
    
    .ibus(ibus_if.slave),
    .invalidate_icache(invalidate_icache),
    .invalidate_addr(invalidate_addr),

    .axi_req(ibus_axi_req),
    .axi_resp(ibus_axi_resp)
);

cpu_core cpu_core_instance(
    .clk(clk),
    .rst(rst),

    .ext_int(ext_int),
    
    .ibus(ibus_if.master),

    .invalidate_icache(invalidate_icache),
    .invalidate_addr(invalidate_addr),

    // move dbus axi control to cpu, just for simplicity.
    .dcache_axi_req(dbus_axi_req),
    .dcache_axi_resp(dbus_axi_resp),

    .uncached_axi_req(duncached_axi_req),
    .uncached_axi_resp(duncached_axi_resp),

    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_wen(debug_wb_rf_wen),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

endmodule


/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

`include "config.h"

module soc_up_top(
    input         resetn, 
    input         clk,

    //------gpio----------------
    output [15:0] led,
    output [1 :0] led_rg0,
    output [1 :0] led_rg1,
    output [7 :0] num_csn,
    output [6 :0] num_a_g,
    input  [7 :0] switch, 
    output [3 :0] btn_key_col,
    input  [3 :0] btn_key_row,
    input  [1 :0] btn_step,

    //------DDR3 interface------
    inout  [15:0] ddr3_dq,
    output [12:0] ddr3_addr,
    output [2 :0] ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_odt,
    output        ddr3_reset_n,
    output        ddr3_cke,
    output [1:0]  ddr3_dm,
    inout  [1:0]  ddr3_dqs_p,
    inout  [1:0]  ddr3_dqs_n,
    output        ddr3_ck_p,
    output        ddr3_ck_n,

    //------uart-------
    inout         UART_RX,
    inout         UART_TX,

    //------spi flash-------
    output        SPI_CLK,
    output        SPI_CS,
    inout         SPI_MISO,
    inout         SPI_MOSI
);


wire        cpu_clk;
wire        sys_clk;
wire        ddr_clk;
reg         cpu_resetn;
reg         sys_resetn;
reg         ddr_resetn;
clk_pll  clk_pll_33
 (
  .clk_in1(clk    ),  //100MHz
  .cpu_clk(cpu_clk),  //60MHz
  .sys_clk(sys_clk)   //33MHz
 );


wire [`LID         -1 :0] cpu_awid;
wire [`Lawaddr     -1 :0] cpu_awaddr;
wire [`Lawlen      -1 :0] cpu_awlen;
wire [`Lawsize     -1 :0] cpu_awsize;
wire [`Lawburst    -1 :0] cpu_awburst;
wire [`Lawlock     -1 :0] cpu_awlock;
wire [`Lawcache    -1 :0] cpu_awcache;
wire [`Lawprot     -1 :0] cpu_awprot;
wire                      cpu_awvalid;
wire                      cpu_awready;
wire [`LID         -1 :0] cpu_wid;
wire [`Lwdata      -1 :0] cpu_wdata;
wire [`Lwstrb      -1 :0] cpu_wstrb;
wire                      cpu_wlast;
wire                      cpu_wvalid;
wire                      cpu_wready;
wire [`LID         -1 :0] cpu_bid;
wire [`Lbresp      -1 :0] cpu_bresp;
wire                      cpu_bvalid;
wire                      cpu_bready;
wire [`LID         -1 :0] cpu_arid;
wire [`Laraddr     -1 :0] cpu_araddr;
wire [`Larlen      -1 :0] cpu_arlen;
wire [`Larsize     -1 :0] cpu_arsize;
wire [`Larburst    -1 :0] cpu_arburst;
wire [`Larlock     -1 :0] cpu_arlock;
wire [`Larcache    -1 :0] cpu_arcache;
wire [`Larprot     -1 :0] cpu_arprot;
wire                      cpu_arvalid;
wire                      cpu_arready;
wire [`LID         -1 :0] cpu_rid;
wire [`Lrdata      -1 :0] cpu_rdata;
wire [`Lrresp      -1 :0] cpu_rresp;
wire                      cpu_rlast;
wire                      cpu_rvalid;
wire                      cpu_rready;

wire [`LID         -1 :0] cpu_sync_awid;
wire [`Lawaddr     -1 :0] cpu_sync_awaddr;
wire [`Lawlen      -1 :0] cpu_sync_awlen;
wire [`Lawsize     -1 :0] cpu_sync_awsize;
wire [`Lawburst    -1 :0] cpu_sync_awburst;
wire [`Lawlock     -1 :0] cpu_sync_awlock;
wire [`Lawcache    -1 :0] cpu_sync_awcache;
wire [`Lawprot     -1 :0] cpu_sync_awprot;
wire                      cpu_sync_awvalid;
wire                      cpu_sync_awready;
wire [`LID         -1 :0] cpu_sync_wid;
wire [`Lwdata      -1 :0] cpu_sync_wdata;
wire [`Lwstrb      -1 :0] cpu_sync_wstrb;
wire                      cpu_sync_wlast;
wire                      cpu_sync_wvalid;
wire                      cpu_sync_wready;
wire [`LID         -1 :0] cpu_sync_bid;
wire [`Lbresp      -1 :0] cpu_sync_bresp;
wire                      cpu_sync_bvalid;
wire                      cpu_sync_bready;
wire [`LID         -1 :0] cpu_sync_arid;
wire [`Laraddr     -1 :0] cpu_sync_araddr;
wire [`Larlen      -1 :0] cpu_sync_arlen;
wire [`Larsize     -1 :0] cpu_sync_arsize;
wire [`Larburst    -1 :0] cpu_sync_arburst;
wire [`Larlock     -1 :0] cpu_sync_arlock;
wire [`Larcache    -1 :0] cpu_sync_arcache;
wire [`Larprot     -1 :0] cpu_sync_arprot;
wire                      cpu_sync_arvalid;
wire                      cpu_sync_arready;
wire [`LID         -1 :0] cpu_sync_rid;
wire [`Lrdata      -1 :0] cpu_sync_rdata;
wire [`Lrresp      -1 :0] cpu_sync_rresp;
wire                      cpu_sync_rlast;
wire                      cpu_sync_rvalid;
wire                      cpu_sync_rready;


wire [`LID         -1 :0] spi_s_awid;
wire [`Lawaddr     -1 :0] spi_s_awaddr;
wire [`Lawlen      -1 :0] spi_s_awlen;
wire [`Lawsize     -1 :0] spi_s_awsize;
wire [`Lawburst    -1 :0] spi_s_awburst;
wire [`Lawlock     -1 :0] spi_s_awlock;
wire [`Lawcache    -1 :0] spi_s_awcache;
wire [`Lawprot     -1 :0] spi_s_awprot;
wire                      spi_s_awvalid;
wire                      spi_s_awready;
wire [`LID         -1 :0] spi_s_wid;
wire [`Lwdata      -1 :0] spi_s_wdata;
wire [`Lwstrb      -1 :0] spi_s_wstrb;
wire                      spi_s_wlast;
wire                      spi_s_wvalid;
wire                      spi_s_wready;
wire [`LID         -1 :0] spi_s_bid;
wire [`Lbresp      -1 :0] spi_s_bresp;
wire                      spi_s_bvalid;
wire                      spi_s_bready;
wire [`LID         -1 :0] spi_s_arid;
wire [`Laraddr     -1 :0] spi_s_araddr;
wire [`Larlen      -1 :0] spi_s_arlen;
wire [`Larsize     -1 :0] spi_s_arsize;
wire [`Larburst    -1 :0] spi_s_arburst;
wire [`Larlock     -1 :0] spi_s_arlock;
wire [`Larcache    -1 :0] spi_s_arcache;
wire [`Larprot     -1 :0] spi_s_arprot;
wire                      spi_s_arvalid;
wire                      spi_s_arready;
wire [`LID         -1 :0] spi_s_rid;
wire [`Lrdata      -1 :0] spi_s_rdata;
wire [`Lrresp      -1 :0] spi_s_rresp;
wire                      spi_s_rlast;
wire                      spi_s_rvalid;
wire                      spi_s_rready;

wire [`LID         -1 :0] conf_s_awid;
wire [`Lawaddr     -1 :0] conf_s_awaddr;
wire [`Lawlen      -1 :0] conf_s_awlen;
wire [`Lawsize     -1 :0] conf_s_awsize;
wire [`Lawburst    -1 :0] conf_s_awburst;
wire [`Lawlock     -1 :0] conf_s_awlock;
wire [`Lawcache    -1 :0] conf_s_awcache;
wire [`Lawprot     -1 :0] conf_s_awprot;
wire                      conf_s_awvalid;
wire                      conf_s_awready;
wire [`LID         -1 :0] conf_s_wid;
wire [`Lwdata      -1 :0] conf_s_wdata;
wire [`Lwstrb      -1 :0] conf_s_wstrb;
wire                      conf_s_wlast;
wire                      conf_s_wvalid;
wire                      conf_s_wready;
wire [`LID         -1 :0] conf_s_bid;
wire [`Lbresp      -1 :0] conf_s_bresp;
wire                      conf_s_bvalid;
wire                      conf_s_bready;
wire [`LID         -1 :0] conf_s_arid;
wire [`Laraddr     -1 :0] conf_s_araddr;
wire [`Larlen      -1 :0] conf_s_arlen;
wire [`Larsize     -1 :0] conf_s_arsize;
wire [`Larburst    -1 :0] conf_s_arburst;
wire [`Larlock     -1 :0] conf_s_arlock;
wire [`Larcache    -1 :0] conf_s_arcache;
wire [`Larprot     -1 :0] conf_s_arprot;
wire                      conf_s_arvalid;
wire                      conf_s_arready;
wire [`LID         -1 :0] conf_s_rid;
wire [`Lrdata      -1 :0] conf_s_rdata;
wire [`Lrresp      -1 :0] conf_s_rresp;
wire                      conf_s_rlast;
wire                      conf_s_rvalid;
wire                      conf_s_rready;

wire [`LID         -1 :0] mac_s_awid;
wire [`Lawaddr     -1 :0] mac_s_awaddr;
wire [`Lawlen      -1 :0] mac_s_awlen;
wire [`Lawsize     -1 :0] mac_s_awsize;
wire [`Lawburst    -1 :0] mac_s_awburst;
wire [`Lawlock     -1 :0] mac_s_awlock;
wire [`Lawcache    -1 :0] mac_s_awcache;
wire [`Lawprot     -1 :0] mac_s_awprot;
wire                      mac_s_awvalid;
wire                      mac_s_awready;
wire [`LID         -1 :0] mac_s_wid;
wire [`Lwdata      -1 :0] mac_s_wdata;
wire [`Lwstrb      -1 :0] mac_s_wstrb;
wire                      mac_s_wlast;
wire                      mac_s_wvalid;
wire                      mac_s_wready;
wire [`LID         -1 :0] mac_s_bid;
wire [`Lbresp      -1 :0] mac_s_bresp;
wire                      mac_s_bvalid;
wire                      mac_s_bready;
wire [`LID         -1 :0] mac_s_arid;
wire [`Laraddr     -1 :0] mac_s_araddr;
wire [`Larlen      -1 :0] mac_s_arlen;
wire [`Larsize     -1 :0] mac_s_arsize;
wire [`Larburst    -1 :0] mac_s_arburst;
wire [`Larlock     -1 :0] mac_s_arlock;
wire [`Larcache    -1 :0] mac_s_arcache;
wire [`Larprot     -1 :0] mac_s_arprot;
wire                      mac_s_arvalid;
wire                      mac_s_arready;
wire [`LID         -1 :0] mac_s_rid;
wire [`Lrdata      -1 :0] mac_s_rdata;
wire [`Lrresp      -1 :0] mac_s_rresp;
wire                      mac_s_rlast;
wire                      mac_s_rvalid;
wire                      mac_s_rready;

wire [`LID         -1 :0] mac_m_awid;
wire [`Lawaddr     -1 :0] mac_m_awaddr;
wire [`Lawlen      -1 :0] mac_m_awlen;
wire [`Lawsize     -1 :0] mac_m_awsize;
wire [`Lawburst    -1 :0] mac_m_awburst;
wire [`Lawlock     -1 :0] mac_m_awlock;
wire [`Lawcache    -1 :0] mac_m_awcache;
wire [`Lawprot     -1 :0] mac_m_awprot;
wire                      mac_m_awvalid;
wire                      mac_m_awready;
wire [`LID         -1 :0] mac_m_wid;
wire [`Lwdata      -1 :0] mac_m_wdata;
wire [`Lwstrb      -1 :0] mac_m_wstrb;
wire                      mac_m_wlast;
wire                      mac_m_wvalid;
wire                      mac_m_wready;
wire [`LID         -1 :0] mac_m_bid;
wire [`Lbresp      -1 :0] mac_m_bresp;
wire                      mac_m_bvalid;
wire                      mac_m_bready;
wire [`LID         -1 :0] mac_m_arid;
wire [`Laraddr     -1 :0] mac_m_araddr;
wire [`Larlen      -1 :0] mac_m_arlen;
wire [`Larsize     -1 :0] mac_m_arsize;
wire [`Larburst    -1 :0] mac_m_arburst;
wire [`Larlock     -1 :0] mac_m_arlock;
wire [`Larcache    -1 :0] mac_m_arcache;
wire [`Larprot     -1 :0] mac_m_arprot;
wire                      mac_m_arvalid;
wire                      mac_m_arready;
wire [`LID         -1 :0] mac_m_rid;
wire [`Lrdata      -1 :0] mac_m_rdata;
wire [`Lrresp      -1 :0] mac_m_rresp;
wire                      mac_m_rlast;
wire                      mac_m_rvalid;
wire                      mac_m_rready;

wire [`LID         -1 :0] s0_awid;
wire [`Lawaddr     -1 :0] s0_awaddr;
wire [`Lawlen      -1 :0] s0_awlen;
wire [`Lawsize     -1 :0] s0_awsize;
wire [`Lawburst    -1 :0] s0_awburst;
wire [`Lawlock     -1 :0] s0_awlock;
wire [`Lawcache    -1 :0] s0_awcache;
wire [`Lawprot     -1 :0] s0_awprot;
wire                      s0_awvalid;
wire                      s0_awready;
wire [`LID         -1 :0] s0_wid;
wire [`Lwdata      -1 :0] s0_wdata;
wire [`Lwstrb      -1 :0] s0_wstrb;
wire                      s0_wlast;
wire                      s0_wvalid;
wire                      s0_wready;
wire [`LID         -1 :0] s0_bid   ;
wire [`Lbresp      -1 :0] s0_bresp ;
wire                      s0_bvalid;
wire                      s0_bready;
wire [`LID         -1 :0] s0_arid;
wire [`Laraddr     -1 :0] s0_araddr;
wire [`Larlen      -1 :0] s0_arlen;
wire [`Larsize     -1 :0] s0_arsize;
wire [`Larburst    -1 :0] s0_arburst;
wire [`Larlock     -1 :0] s0_arlock;
wire [`Larcache    -1 :0] s0_arcache;
wire [`Larprot     -1 :0] s0_arprot;
wire                      s0_arvalid;
wire                      s0_arready;
wire [`LID         -1 :0] s0_rid    ;
wire [`Lrdata      -1 :0] s0_rdata  ;
wire [`Lrresp      -1 :0] s0_rresp  ;
wire                      s0_rlast  ;
wire                      s0_rvalid ;
wire                      s0_rready;

wire [8            -1 :0] mig_awid    ;
wire [`Lawaddr     -1 :0] mig_awaddr  ;
wire [8            -1 :0] mig_awlen   ;
wire [`Lawsize     -1 :0] mig_awsize  ;
wire [`Lawburst    -1 :0] mig_awburst ;
wire [`Lawlock     -1 :0] mig_awlock  ;
wire [`Lawcache    -1 :0] mig_awcache ;
wire [`Lawprot     -1 :0] mig_awprot  ;
wire                      mig_awvalid ;
wire                      mig_awready ;
wire [8            -1 :0] mig_wid     ;
wire [`Lwdata      -1 :0] mig_wdata   ;
wire [`Lwstrb      -1 :0] mig_wstrb   ;
wire                      mig_wlast   ;
wire                      mig_wvalid  ;
wire                      mig_wready  ;
wire [8            -1 :0] mig_bid     ;
wire [`Lbresp      -1 :0] mig_bresp   ;
wire                      mig_bvalid  ;
wire                      mig_bready  ;
wire [8            -1 :0] mig_arid    ;
wire [`Laraddr     -1 :0] mig_araddr  ;
wire [8            -1 :0] mig_arlen   ;
wire [`Larsize     -1 :0] mig_arsize  ;
wire [`Larburst    -1 :0] mig_arburst ;
wire [`Larlock     -1 :0] mig_arlock  ;
wire [`Larcache    -1 :0] mig_arcache ;
wire [`Larprot     -1 :0] mig_arprot  ;
wire                      mig_arvalid ;
wire                      mig_arready ;
wire [8            -1 :0] mig_rid     ;
wire [`Lrdata      -1 :0] mig_rdata   ;
wire [`Lrresp      -1 :0] mig_rresp   ;
wire                      mig_rlast   ;
wire                      mig_rvalid  ;
wire                      mig_rready  ;

wire [`LID         -1 :0] apb_s_awid;
wire [`Lawaddr     -1 :0] apb_s_awaddr;
wire [`Lawlen      -1 :0] apb_s_awlen;
wire [`Lawsize     -1 :0] apb_s_awsize;
wire [`Lawburst    -1 :0] apb_s_awburst;
wire [`Lawlock     -1 :0] apb_s_awlock;
wire [`Lawcache    -1 :0] apb_s_awcache;
wire [`Lawprot     -1 :0] apb_s_awprot;
wire                      apb_s_awvalid;
wire                      apb_s_awready;
wire [`LID         -1 :0] apb_s_wid;
wire [`Lwdata      -1 :0] apb_s_wdata;
wire [`Lwstrb      -1 :0] apb_s_wstrb;
wire                      apb_s_wlast;
wire                      apb_s_wvalid;
wire                      apb_s_wready;
wire [`LID         -1 :0] apb_s_bid;
wire [`Lbresp      -1 :0] apb_s_bresp;
wire                      apb_s_bvalid;
wire                      apb_s_bready;
wire [`LID         -1 :0] apb_s_arid;
wire [`Laraddr     -1 :0] apb_s_araddr;
wire [`Larlen      -1 :0] apb_s_arlen;
wire [`Larsize     -1 :0] apb_s_arsize;
wire [`Larburst    -1 :0] apb_s_arburst;
wire [`Larlock     -1 :0] apb_s_arlock;
wire [`Larcache    -1 :0] apb_s_arcache;
wire [`Larprot     -1 :0] apb_s_arprot;
wire                      apb_s_arvalid;
wire                      apb_s_arready;
wire [`LID         -1 :0] apb_s_rid;
wire [`Lrdata      -1 :0] apb_s_rdata;
wire [`Lrresp      -1 :0] apb_s_rresp;
wire                      apb_s_rlast;
wire                      apb_s_rvalid;
wire                      apb_s_rready;

//spi
wire [3:0]spi_csn_o ;
wire [3:0]spi_csn_en;
wire spi_sck_o ;
wire spi_sdo_i ;
wire spi_sdo_o ;
wire spi_sdo_en;
wire spi_sdi_i ;
wire spi_sdi_o ;
wire spi_sdi_en;
wire spi_inta_o;
assign     SPI_CLK = spi_sck_o;
assign     SPI_CS  = ~spi_csn_en[0] & spi_csn_o[0];
assign     SPI_MOSI = spi_sdo_en ? 1'bz : spi_sdo_o ;
assign     SPI_MISO = spi_sdi_en ? 1'bz : spi_sdi_o ;
assign     spi_sdo_i = SPI_MOSI;
assign     spi_sdi_i = SPI_MISO;

//uart
wire UART_CTS,   UART_RTS;
wire UART_DTR,   UART_DSR;
wire UART_RI,    UART_DCD;
assign UART_CTS = 1'b0;
assign UART_DSR = 1'b0;
assign UART_DCD = 1'b0;
wire uart0_int   ;
wire uart0_txd_o ;
wire uart0_txd_i ;
wire uart0_txd_oe;
wire uart0_rxd_o ;
wire uart0_rxd_i ;
wire uart0_rxd_oe;
wire uart0_rts_o ;
wire uart0_cts_i ;
wire uart0_dsr_i ;
wire uart0_dcd_i ;
wire uart0_dtr_o ;
wire uart0_ri_i  ;
assign     UART_RX     = uart0_rxd_oe ? 1'bz : uart0_rxd_o ;
assign     UART_TX     = uart0_txd_oe ? 1'bz : uart0_txd_o ;
assign     UART_RTS    = uart0_rts_o ;
assign     UART_DTR    = uart0_dtr_o ;
assign     uart0_txd_i = UART_TX;
assign     uart0_rxd_i = UART_RX;
assign     uart0_cts_i = UART_CTS;
assign     uart0_dcd_i = UART_DCD;
assign     uart0_dsr_i = UART_DSR;
assign     uart0_ri_i  = UART_RI ;

//interrupt
wire [5:0] int_out;
assign int_out = {1'b0, 1'b0, 1'b0, uart0_int, spi_inta_o, 1'b0   };


// cpu
mycpu_top u_cpu(
    .ext_int   (int_out       ),   //high active

    .aclk      (cpu_clk       ),
    .aresetn   (cpu_resetn    ),   //low active

    .arid      (cpu_arid      ),
    .araddr    (cpu_araddr    ),
    .arlen     (cpu_arlen     ),
    .arsize    (cpu_arsize    ),
    .arburst   (cpu_arburst   ),
    .arlock    (cpu_arlock    ),
    .arcache   (cpu_arcache   ),
    .arprot    (cpu_arprot    ),
    .arvalid   (cpu_arvalid   ),
    .arready   (cpu_arready   ),

    .rid       (cpu_rid       ),
    .rdata     (cpu_rdata     ),
    .rresp     (cpu_rresp     ),
    .rlast     (cpu_rlast     ),
    .rvalid    (cpu_rvalid    ),
    .rready    (cpu_rready    ),
               
    .awid      (cpu_awid      ),
    .awaddr    (cpu_awaddr    ),
    .awlen     (cpu_awlen     ),
    .awsize    (cpu_awsize    ),
    .awburst   (cpu_awburst   ),
    .awlock    (cpu_awlock    ),
    .awcache   (cpu_awcache   ),
    .awprot    (cpu_awprot    ),
    .awvalid   (cpu_awvalid   ),
    .awready   (cpu_awready   ),
    
    .wid       (cpu_wid       ),
    .wdata     (cpu_wdata     ),
    .wstrb     (cpu_wstrb     ),
    .wlast     (cpu_wlast     ),
    .wvalid    (cpu_wvalid    ),
    .wready    (cpu_wready    ),
    
    .bid       (cpu_bid       ),
    .bresp     (cpu_bresp     ),
    .bvalid    (cpu_bvalid    ),
    .bready    (cpu_bready    ),

    //debug interface
    .debug_wb_pc      ( ),
    .debug_wb_rf_wen  ( ),
    .debug_wb_rf_wnum ( ),
    .debug_wb_rf_wdata( )
);
//clock sync: from cpu_clk to sys_clk
axi_clock_converter  u_axi_clock_sync(
  .s_axi_aclk    (cpu_clk          ),
  .s_axi_aresetn (cpu_resetn       ),
  .s_axi_awid    (cpu_awid         ),
  .s_axi_awaddr  (cpu_awaddr       ),
  .s_axi_awlen   (cpu_awlen        ),
  .s_axi_awsize  (cpu_awsize       ),
  .s_axi_awburst (cpu_awburst      ),
  .s_axi_awlock  (cpu_awlock       ),
  .s_axi_awcache (cpu_awcache      ),
  .s_axi_awprot  (cpu_awprot       ),
  .s_axi_awqos   (4'd0             ),
  .s_axi_awvalid (cpu_awvalid      ),
  .s_axi_awready (cpu_awready      ),
  .s_axi_wid     (cpu_wid          ),
  .s_axi_wdata   (cpu_wdata        ),
  .s_axi_wstrb   (cpu_wstrb        ),
  .s_axi_wlast   (cpu_wlast        ),
  .s_axi_wvalid  (cpu_wvalid       ),
  .s_axi_wready  (cpu_wready       ),
  .s_axi_bid     (cpu_bid          ),
  .s_axi_bresp   (cpu_bresp        ),
  .s_axi_bvalid  (cpu_bvalid       ),
  .s_axi_bready  (cpu_bready       ),
  .s_axi_arid    (cpu_arid         ),
  .s_axi_araddr  (cpu_araddr       ),
  .s_axi_arlen   (cpu_arlen        ),
  .s_axi_arsize  (cpu_arsize       ),
  .s_axi_arburst (cpu_arburst      ),
  .s_axi_arlock  (cpu_arlock       ),
  .s_axi_arcache (cpu_arcache      ),
  .s_axi_arprot  (cpu_arprot       ),
  .s_axi_arqos   (4'd0             ),
  .s_axi_arvalid (cpu_arvalid      ),
  .s_axi_arready (cpu_arready      ),
  .s_axi_rid     (cpu_rid          ),
  .s_axi_rdata   (cpu_rdata        ),
  .s_axi_rresp   (cpu_rresp        ),
  .s_axi_rlast   (cpu_rlast        ),
  .s_axi_rvalid  (cpu_rvalid       ),
  .s_axi_rready  (cpu_rready       ),
  .m_axi_aclk    (sys_clk          ),
  .m_axi_aresetn (sys_resetn       ),
  .m_axi_awid    (cpu_sync_awid    ),
  .m_axi_awaddr  (cpu_sync_awaddr  ),
  .m_axi_awlen   (cpu_sync_awlen   ),
  .m_axi_awsize  (cpu_sync_awsize  ),
  .m_axi_awburst (cpu_sync_awburst ),
  .m_axi_awlock  (cpu_sync_awlock  ),
  .m_axi_awcache (cpu_sync_awcache ),
  .m_axi_awprot  (cpu_sync_awprot  ),
  .m_axi_awqos   (                 ),
  .m_axi_awvalid (cpu_sync_awvalid ),
  .m_axi_awready (cpu_sync_awready ),
  .m_axi_wid     (cpu_sync_wid     ),
  .m_axi_wdata   (cpu_sync_wdata   ),
  .m_axi_wstrb   (cpu_sync_wstrb   ),
  .m_axi_wlast   (cpu_sync_wlast   ),
  .m_axi_wvalid  (cpu_sync_wvalid  ),
  .m_axi_wready  (cpu_sync_wready  ),
  .m_axi_bid     (cpu_sync_bid     ),
  .m_axi_bresp   (cpu_sync_bresp   ),
  .m_axi_bvalid  (cpu_sync_bvalid  ),
  .m_axi_bready  (cpu_sync_bready  ),
  .m_axi_arid    (cpu_sync_arid    ),
  .m_axi_araddr  (cpu_sync_araddr  ),
  .m_axi_arlen   (cpu_sync_arlen   ), 
  .m_axi_arsize  (cpu_sync_arsize  ),
  .m_axi_arburst (cpu_sync_arburst ),
  .m_axi_arlock  (cpu_sync_arlock  ),
  .m_axi_arcache (cpu_sync_arcache ),
  .m_axi_arprot  (cpu_sync_arprot  ),
  .m_axi_arqos   (                 ),
  .m_axi_arvalid (cpu_sync_arvalid ),
  .m_axi_arready (cpu_sync_arready ),
  .m_axi_rid     (cpu_sync_rid     ),
  .m_axi_rdata   (cpu_sync_rdata   ),
  .m_axi_rresp   (cpu_sync_rresp   ),
  .m_axi_rlast   (cpu_sync_rlast   ),
  .m_axi_rvalid  (cpu_sync_rvalid  ),
  .m_axi_rready  (cpu_sync_rready  ) 
);

// AXI_MUX 
axi_slave_mux AXI_SLAVE_MUX
(
.axi_s_aresetn     (sys_resetn      ),
.spi_boot          (1'b1            ),  

.axi_s_awid        (cpu_sync_awid        ),
.axi_s_awaddr      (cpu_sync_awaddr      ),
.axi_s_awlen       (cpu_sync_awlen       ),
.axi_s_awsize      (cpu_sync_awsize      ),
.axi_s_awburst     (cpu_sync_awburst     ),
.axi_s_awlock      (cpu_sync_awlock      ),
.axi_s_awcache     (cpu_sync_awcache     ),
.axi_s_awprot      (cpu_sync_awprot      ),
.axi_s_awvalid     (cpu_sync_awvalid     ),
.axi_s_awready     (cpu_sync_awready     ),
.axi_s_wready      (cpu_sync_wready      ),
.axi_s_wid         (cpu_sync_wid         ),
.axi_s_wdata       (cpu_sync_wdata       ),
.axi_s_wstrb       (cpu_sync_wstrb       ),
.axi_s_wlast       (cpu_sync_wlast       ),
.axi_s_wvalid      (cpu_sync_wvalid      ),
.axi_s_bid         (cpu_sync_bid         ),
.axi_s_bresp       (cpu_sync_bresp       ),
.axi_s_bvalid      (cpu_sync_bvalid      ),
.axi_s_bready      (cpu_sync_bready      ),
.axi_s_arid        (cpu_sync_arid        ),
.axi_s_araddr      (cpu_sync_araddr      ),
.axi_s_arlen       (cpu_sync_arlen       ),
.axi_s_arsize      (cpu_sync_arsize      ),
.axi_s_arburst     (cpu_sync_arburst     ),
.axi_s_arlock      (cpu_sync_arlock      ),
.axi_s_arcache     (cpu_sync_arcache     ),
.axi_s_arprot      (cpu_sync_arprot      ),
.axi_s_arvalid     (cpu_sync_arvalid     ),
.axi_s_arready     (cpu_sync_arready     ),
.axi_s_rready      (cpu_sync_rready      ),
.axi_s_rid         (cpu_sync_rid         ),
.axi_s_rdata       (cpu_sync_rdata       ),
.axi_s_rresp       (cpu_sync_rresp       ),
.axi_s_rlast       (cpu_sync_rlast       ),
.axi_s_rvalid      (cpu_sync_rvalid      ),

.s0_awid           (s0_awid         ),
.s0_awaddr         (s0_awaddr       ),
.s0_awlen          (s0_awlen        ),
.s0_awsize         (s0_awsize       ),
.s0_awburst        (s0_awburst      ),
.s0_awlock         (s0_awlock       ),
.s0_awcache        (s0_awcache      ),
.s0_awprot         (s0_awprot       ),
.s0_awvalid        (s0_awvalid      ),
.s0_awready        (s0_awready      ),
.s0_wid            (s0_wid          ),
.s0_wdata          (s0_wdata        ),
.s0_wstrb          (s0_wstrb        ),
.s0_wlast          (s0_wlast        ),
.s0_wvalid         (s0_wvalid       ),
.s0_wready         (s0_wready       ),
.s0_bid            (s0_bid          ),
.s0_bresp          (s0_bresp        ),
.s0_bvalid         (s0_bvalid       ),
.s0_bready         (s0_bready       ),
.s0_arid           (s0_arid         ),
.s0_araddr         (s0_araddr       ),
.s0_arlen          (s0_arlen        ),
.s0_arsize         (s0_arsize       ),
.s0_arburst        (s0_arburst      ),
.s0_arlock         (s0_arlock       ),
.s0_arcache        (s0_arcache      ),
.s0_arprot         (s0_arprot       ),
.s0_arvalid        (s0_arvalid      ),
.s0_arready        (s0_arready      ),
.s0_rid            (s0_rid          ),
.s0_rdata          (s0_rdata        ),
.s0_rresp          (s0_rresp        ),
.s0_rlast          (s0_rlast        ),
.s0_rvalid         (s0_rvalid       ),
.s0_rready         (s0_rready       ),

.s1_awid           (spi_s_awid          ),
.s1_awaddr         (spi_s_awaddr        ),
.s1_awlen          (spi_s_awlen         ),
.s1_awsize         (spi_s_awsize        ),
.s1_awburst        (spi_s_awburst       ),
.s1_awlock         (spi_s_awlock        ),
.s1_awcache        (spi_s_awcache       ),
.s1_awprot         (spi_s_awprot        ),
.s1_awvalid        (spi_s_awvalid       ),
.s1_awready        (spi_s_awready       ),
.s1_wid            (spi_s_wid           ),
.s1_wdata          (spi_s_wdata         ),
.s1_wstrb          (spi_s_wstrb         ),
.s1_wlast          (spi_s_wlast         ),
.s1_wvalid         (spi_s_wvalid        ),
.s1_wready         (spi_s_wready        ),
.s1_bid            (spi_s_bid           ),
.s1_bresp          (spi_s_bresp         ),
.s1_bvalid         (spi_s_bvalid        ),
.s1_bready         (spi_s_bready        ),
.s1_arid           (spi_s_arid          ),
.s1_araddr         (spi_s_araddr        ),
.s1_arlen          (spi_s_arlen         ),
.s1_arsize         (spi_s_arsize        ),
.s1_arburst        (spi_s_arburst       ),
.s1_arlock         (spi_s_arlock        ),
.s1_arcache        (spi_s_arcache       ),
.s1_arprot         (spi_s_arprot        ),
.s1_arvalid        (spi_s_arvalid       ),
.s1_arready        (spi_s_arready       ),
.s1_rid            (spi_s_rid           ),
.s1_rdata          (spi_s_rdata         ),
.s1_rresp          (spi_s_rresp         ),
.s1_rlast          (spi_s_rlast         ),
.s1_rvalid         (spi_s_rvalid        ),
.s1_rready         (spi_s_rready        ),

.s2_awid           (apb_s_awid         ),
.s2_awaddr         (apb_s_awaddr       ),
.s2_awlen          (apb_s_awlen        ),
.s2_awsize         (apb_s_awsize       ),
.s2_awburst        (apb_s_awburst      ),
.s2_awlock         (apb_s_awlock       ),
.s2_awcache        (apb_s_awcache      ),
.s2_awprot         (apb_s_awprot       ),
.s2_awvalid        (apb_s_awvalid      ),
.s2_awready        (apb_s_awready      ),
.s2_wid            (apb_s_wid          ),
.s2_wdata          (apb_s_wdata        ),
.s2_wstrb          (apb_s_wstrb        ),
.s2_wlast          (apb_s_wlast        ),
.s2_wvalid         (apb_s_wvalid       ),
.s2_wready         (apb_s_wready       ),
.s2_bid            (apb_s_bid          ),
.s2_bresp          (apb_s_bresp        ),
.s2_bvalid         (apb_s_bvalid       ),
.s2_bready         (apb_s_bready       ),
.s2_arid           (apb_s_arid         ),
.s2_araddr         (apb_s_araddr       ),
.s2_arlen          (apb_s_arlen        ),
.s2_arsize         (apb_s_arsize       ),
.s2_arburst        (apb_s_arburst      ),
.s2_arlock         (apb_s_arlock       ),
.s2_arcache        (apb_s_arcache      ),
.s2_arprot         (apb_s_arprot       ),
.s2_arvalid        (apb_s_arvalid      ),
.s2_arready        (apb_s_arready      ),
.s2_rid            (apb_s_rid          ),
.s2_rdata          (apb_s_rdata        ),
.s2_rresp          (apb_s_rresp        ),
.s2_rlast          (apb_s_rlast        ),
.s2_rvalid         (apb_s_rvalid       ),
.s2_rready         (apb_s_rready       ),

.s3_awid           (conf_s_awid         ),
.s3_awaddr         (conf_s_awaddr       ),
.s3_awlen          (conf_s_awlen        ),
.s3_awsize         (conf_s_awsize       ),
.s3_awburst        (conf_s_awburst      ),
.s3_awlock         (conf_s_awlock       ),
.s3_awcache        (conf_s_awcache      ),
.s3_awprot         (conf_s_awprot       ),
.s3_awvalid        (conf_s_awvalid      ),
.s3_awready        (conf_s_awready      ),
.s3_wid            (conf_s_wid          ),
.s3_wdata          (conf_s_wdata        ),
.s3_wstrb          (conf_s_wstrb        ),
.s3_wlast          (conf_s_wlast        ),
.s3_wvalid         (conf_s_wvalid       ),
.s3_wready         (conf_s_wready       ),
.s3_bid            (conf_s_bid          ),
.s3_bresp          (conf_s_bresp        ),
.s3_bvalid         (conf_s_bvalid       ),
.s3_bready         (conf_s_bready       ),
.s3_arid           (conf_s_arid         ),
.s3_araddr         (conf_s_araddr       ),
.s3_arlen          (conf_s_arlen        ),
.s3_arsize         (conf_s_arsize       ),
.s3_arburst        (conf_s_arburst      ),
.s3_arlock         (conf_s_arlock       ),
.s3_arcache        (conf_s_arcache      ),
.s3_arprot         (conf_s_arprot       ),
.s3_arvalid        (conf_s_arvalid      ),
.s3_arready        (conf_s_arready      ),
.s3_rid            (conf_s_rid          ),
.s3_rdata          (conf_s_rdata        ),
.s3_rresp          (conf_s_rresp        ),
.s3_rlast          (conf_s_rlast        ),
.s3_rvalid         (conf_s_rvalid       ),
.s3_rready         (conf_s_rready       ),

.s4_awid           (                   ),
.s4_awaddr         (                   ),
.s4_awlen          (                   ),
.s4_awsize         (                   ),
.s4_awburst        (                   ),
.s4_awlock         (                   ),
.s4_awcache        (                   ),
.s4_awprot         (                   ),
.s4_awvalid        (                   ),
.s4_awready        (1'b1               ),
.s4_wid            (                   ),
.s4_wdata          (                   ),
.s4_wstrb          (                   ),
.s4_wlast          (                   ),
.s4_wvalid         (                   ),
.s4_wready         (1'b1               ),
.s4_bid            (4'd0               ),
.s4_bresp          (2'd0               ),
.s4_bvalid         (1'b0               ),
.s4_bready         (                   ),
.s4_arid           (                   ),
.s4_araddr         (                   ),
.s4_arlen          (                   ),
.s4_arsize         (                   ),
.s4_arburst        (                   ),
.s4_arlock         (                   ),
.s4_arcache        (                   ),
.s4_arprot         (                   ),
.s4_arvalid        (                   ),
.s4_arready        (1'b1               ),
.s4_rid            (4'd0               ),
.s4_rdata          (32'd0              ),
.s4_rresp          (2'd0               ),
.s4_rlast          (1'b1               ),
.s4_rvalid         (1'b0               ),
.s4_rready         (                   ),

.axi_s_aclk        (sys_clk            )
);

//SPI
spi_flash_ctrl SPI                    
(                                         
.aclk           (sys_clk           ),       
.aresetn        (sys_resetn        ),       
.spi_addr       (16'h1fe8          ),
.fast_startup   (1'b0              ),
.s_awid         (spi_s_awid        ),
.s_awaddr       (spi_s_awaddr      ),
.s_awlen        (spi_s_awlen       ),
.s_awsize       (spi_s_awsize      ),
.s_awburst      (spi_s_awburst     ),
.s_awlock       (spi_s_awlock      ),
.s_awcache      (spi_s_awcache     ),
.s_awprot       (spi_s_awprot      ),
.s_awvalid      (spi_s_awvalid     ),
.s_awready      (spi_s_awready     ),
.s_wready       (spi_s_wready      ),
.s_wid          (spi_s_wid         ),
.s_wdata        (spi_s_wdata       ),
.s_wstrb        (spi_s_wstrb       ),
.s_wlast        (spi_s_wlast       ),
.s_wvalid       (spi_s_wvalid      ),
.s_bid          (spi_s_bid         ),
.s_bresp        (spi_s_bresp       ),
.s_bvalid       (spi_s_bvalid      ),
.s_bready       (spi_s_bready      ),
.s_arid         (spi_s_arid        ),
.s_araddr       (spi_s_araddr      ),
.s_arlen        (spi_s_arlen       ),
.s_arsize       (spi_s_arsize      ),
.s_arburst      (spi_s_arburst     ),
.s_arlock       (spi_s_arlock      ),
.s_arcache      (spi_s_arcache     ),
.s_arprot       (spi_s_arprot      ),
.s_arvalid      (spi_s_arvalid     ),
.s_arready      (spi_s_arready     ),
.s_rready       (spi_s_rready      ),
.s_rid          (spi_s_rid         ),
.s_rdata        (spi_s_rdata       ),
.s_rresp        (spi_s_rresp       ),
.s_rlast        (spi_s_rlast       ),
.s_rvalid       (spi_s_rvalid      ),

.power_down_req (1'b0              ),
.power_down_ack (                  ),
.csn_o          (spi_csn_o         ),
.csn_en         (spi_csn_en        ), 
.sck_o          (spi_sck_o         ),
.sdo_i          (spi_sdo_i         ),
.sdo_o          (spi_sdo_o         ),
.sdo_en         (spi_sdo_en        ), // active low
.sdi_i          (spi_sdi_i         ),
.sdi_o          (spi_sdi_o         ),
.sdi_en         (spi_sdi_en        ),
.inta_o         (spi_inta_o        )
);

//confreg
confreg CONFREG(
.aclk              (sys_clk            ),       
.timer_clk         (sys_clk            ),       
.aresetn           (sys_resetn         ),       
.awid              (conf_s_awid        ),
.awaddr            (conf_s_awaddr      ),
.awlen             (conf_s_awlen       ),
.awsize            (conf_s_awsize      ),
.awburst           (conf_s_awburst     ),
.awlock            (conf_s_awlock      ),
.awcache           (conf_s_awcache     ),
.awprot            (conf_s_awprot      ),
.awvalid           (conf_s_awvalid     ),
.awready           (conf_s_awready     ),
.wready            (conf_s_wready      ),
.wid               (conf_s_wid         ),
.wdata             (conf_s_wdata       ),
.wstrb             (conf_s_wstrb       ),
.wlast             (conf_s_wlast       ),
.wvalid            (conf_s_wvalid      ),
.bid               (conf_s_bid         ),
.bresp             (conf_s_bresp       ),
.bvalid            (conf_s_bvalid      ),
.bready            (conf_s_bready      ),
.arid              (conf_s_arid        ),
.araddr            (conf_s_araddr      ),
.arlen             (conf_s_arlen       ),
.arsize            (conf_s_arsize      ),
.arburst           (conf_s_arburst     ),
.arlock            (conf_s_arlock      ),
.arcache           (conf_s_arcache     ),
.arprot            (conf_s_arprot      ),
.arvalid           (conf_s_arvalid     ),
.arready           (conf_s_arready     ),
.rready            (conf_s_rready      ),
.rid               (conf_s_rid         ),
.rdata             (conf_s_rdata       ),
.rresp             (conf_s_rresp       ),
.rlast             (conf_s_rlast       ),
.rvalid            (conf_s_rvalid      ),

.ram_random_mask   (            ),

.led               (led         ),
.led_rg0           (led_rg0     ),
.led_rg1           (led_rg1     ),
.num_csn           (num_csn     ),
.num_a_g           (num_a_g     ),
.switch            (switch      ),
.btn_key_col       (btn_key_col ),
.btn_key_row       (btn_key_row ),
.btn_step          (btn_step    )
);

//clock sync: from sys_clk to ddr_clk
axi_clock_converter  u_mig_clock_sync(
  .s_axi_aclk    (sys_clk          ),
  .s_axi_aresetn (sys_resetn       ),
  .s_axi_awid    (s0_awid          ),
  .s_axi_awaddr  (s0_awaddr        ),
  .s_axi_awlen   (s0_awlen         ),
  .s_axi_awsize  (s0_awsize        ),
  .s_axi_awburst (s0_awburst       ),
  .s_axi_awlock  (s0_awlock        ),
  .s_axi_awcache (s0_awcache       ),
  .s_axi_awprot  (s0_awprot        ),
  .s_axi_awqos   (4'd0             ),
  .s_axi_awvalid (s0_awvalid       ),
  .s_axi_awready (s0_awready       ),
  .s_axi_wid     (s0_wid           ),
  .s_axi_wdata   (s0_wdata         ),
  .s_axi_wstrb   (s0_wstrb         ),
  .s_axi_wlast   (s0_wlast         ),
  .s_axi_wvalid  (s0_wvalid        ),
  .s_axi_wready  (s0_wready        ),
  .s_axi_bid     (s0_bid           ),
  .s_axi_bresp   (s0_bresp         ),
  .s_axi_bvalid  (s0_bvalid        ),
  .s_axi_bready  (s0_bready        ),
  .s_axi_arid    (s0_arid          ),
  .s_axi_araddr  (s0_araddr        ),
  .s_axi_arlen   (s0_arlen         ),
  .s_axi_arsize  (s0_arsize        ),
  .s_axi_arburst (s0_arburst       ),
  .s_axi_arlock  (s0_arlock        ),
  .s_axi_arcache (s0_arcache       ),
  .s_axi_arprot  (s0_arprot        ),
  .s_axi_arqos   (4'd0             ),
  .s_axi_arvalid (s0_arvalid       ),
  .s_axi_arready (s0_arready       ),
  .s_axi_rid     (s0_rid           ),
  .s_axi_rdata   (s0_rdata         ),
  .s_axi_rresp   (s0_rresp         ),
  .s_axi_rlast   (s0_rlast         ),
  .s_axi_rvalid  (s0_rvalid        ),
  .s_axi_rready  (s0_rready        ),
  .m_axi_aclk    (ddr_clk          ),
  .m_axi_aresetn (ddr_resetn       ),
  .m_axi_awid    (mig_awid         ),
  .m_axi_awaddr  (mig_awaddr       ),
  .m_axi_awlen   (mig_awlen        ),
  .m_axi_awsize  (mig_awsize       ),
  .m_axi_awburst (mig_awburst      ),
  .m_axi_awlock  (mig_awlock       ),
  .m_axi_awcache (mig_awcache      ),
  .m_axi_awprot  (mig_awprot       ),
  .m_axi_awqos   (                 ),
  .m_axi_awvalid (mig_awvalid      ),
  .m_axi_awready (mig_awready      ),
  .m_axi_wid     (mig_wid          ),
  .m_axi_wdata   (mig_wdata        ),
  .m_axi_wstrb   (mig_wstrb        ),
  .m_axi_wlast   (mig_wlast        ),
  .m_axi_wvalid  (mig_wvalid       ),
  .m_axi_wready  (mig_wready       ),
  .m_axi_bid     (mig_bid[3:0]     ),
  .m_axi_bresp   (mig_bresp        ),
  .m_axi_bvalid  (mig_bvalid       ),
  .m_axi_bready  (mig_bready       ),
  .m_axi_arid    (mig_arid         ),
  .m_axi_araddr  (mig_araddr       ),
  .m_axi_arlen   (mig_arlen        ), 
  .m_axi_arsize  (mig_arsize       ),
  .m_axi_arburst (mig_arburst      ),
  .m_axi_arlock  (mig_arlock       ),
  .m_axi_arcache (mig_arcache      ),
  .m_axi_arprot  (mig_arprot       ),
  .m_axi_arqos   (                 ),
  .m_axi_arvalid (mig_arvalid      ),
  .m_axi_arready (mig_arready      ),
  .m_axi_rid     (mig_rid[3:0]     ),
  .m_axi_rdata   (mig_rdata        ),
  .m_axi_rresp   (mig_rresp        ),
  .m_axi_rlast   (mig_rlast        ),
  .m_axi_rvalid  (mig_rvalid       ),
  .m_axi_rready  (mig_rready       ) 
);
assign mig_awid [7:4] = 4'd0;
assign mig_awlen[7:4] = 4'd0;
assign mig_wid  [7:4] = 4'd0;
assign mig_arid [7:4] = 4'd0;
assign mig_arlen[7:4] = 4'd0;


//ddr3
wire   c1_sys_clk_i;
wire   c1_clk_ref_i;
wire   c1_sys_rst_i;
wire   c1_calib_done;
wire   c1_clk0;
wire   c1_rst0;

clk_wiz_0  clk_pll_1
(
    .clk_out1(c1_clk_ref_i),  //200MHz
    .clk_in1(clk)             //100MHz
);

assign c1_sys_clk_i      = clk;
assign c1_sys_rst_i      = resetn;

assign ddr_clk = c1_clk0;
always @(posedge c1_clk0)
begin
    ddr_resetn <= ~c1_rst0 && c1_calib_done;
end

reg sys_resetn_t, cpu_resetn_t;
always @(posedge sys_clk)
begin
    sys_resetn_t <= ddr_resetn;
    sys_resetn   <= sys_resetn_t;
end
always @(posedge cpu_clk)
begin
    cpu_resetn_t <= ddr_resetn;
    cpu_resetn   <= cpu_resetn_t;
end

//ddr3 controller
mig_axi_32 mig_axi (
    // Inouts
    .ddr3_dq             (ddr3_dq         ),  
    .ddr3_dqs_p          (ddr3_dqs_p      ),    // for X16 parts 
    .ddr3_dqs_n          (ddr3_dqs_n      ),  // for X16 parts
    // Outputs
    .ddr3_addr           (ddr3_addr       ),  
    .ddr3_ba             (ddr3_ba         ),
    .ddr3_ras_n          (ddr3_ras_n      ),                        
    .ddr3_cas_n          (ddr3_cas_n      ),                        
    .ddr3_we_n           (ddr3_we_n       ),                          
    .ddr3_reset_n        (ddr3_reset_n    ),
    .ddr3_ck_p           (ddr3_ck_p       ),                          
    .ddr3_ck_n           (ddr3_ck_n       ),       
    .ddr3_cke            (ddr3_cke        ),                          
    .ddr3_dm             (ddr3_dm         ),
    .ddr3_odt            (ddr3_odt        ),
    
	.ui_clk              (c1_clk0         ),
    .ui_clk_sync_rst     (c1_rst0         ),
 
    .sys_clk_i           (c1_sys_clk_i    ),
    .sys_rst             (c1_sys_rst_i    ),                        
    .init_calib_complete (c1_calib_done   ),
    .clk_ref_i           (c1_clk_ref_i    ),
    .mmcm_locked         (                ),
	
	.app_sr_active       (                ),
    .app_ref_ack         (                ),
    .app_zq_ack          (                ),
    .app_sr_req          (1'b0            ),
    .app_ref_req         (1'b0            ),
    .app_zq_req          (1'b0            ),
    
    .aresetn             (ddr_resetn      ),
    .s_axi_awid          (mig_awid        ),
    .s_axi_awaddr        (mig_awaddr[26:0]),
    .s_axi_awlen         ({mig_awlen}     ),
    .s_axi_awsize        (mig_awsize      ),
    .s_axi_awburst       (mig_awburst     ),
    .s_axi_awlock        (mig_awlock[0:0] ),
    .s_axi_awcache       (mig_awcache     ),
    .s_axi_awprot        (mig_awprot      ),
    .s_axi_awqos         (4'b0            ),
    .s_axi_awvalid       (mig_awvalid     ),
    .s_axi_awready       (mig_awready     ),
    .s_axi_wdata         (mig_wdata       ),
    .s_axi_wstrb         (mig_wstrb       ),
    .s_axi_wlast         (mig_wlast       ),
    .s_axi_wvalid        (mig_wvalid      ),
    .s_axi_wready        (mig_wready      ),
    .s_axi_bid           (mig_bid         ),
    .s_axi_bresp         (mig_bresp       ),
    .s_axi_bvalid        (mig_bvalid      ),
    .s_axi_bready        (mig_bready      ),
    .s_axi_arid          (mig_arid        ),
    .s_axi_araddr        (mig_araddr[26:0]),
    .s_axi_arlen         ({mig_arlen}     ),
    .s_axi_arsize        (mig_arsize      ),
    .s_axi_arburst       (mig_arburst     ),
    .s_axi_arlock        (mig_arlock[0:0] ),
    .s_axi_arcache       (mig_arcache     ),
    .s_axi_arprot        (mig_arprot      ),
    .s_axi_arqos         (4'b0            ),
    .s_axi_arvalid       (mig_arvalid     ),
    .s_axi_arready       (mig_arready     ),
    .s_axi_rid           (mig_rid         ),
    .s_axi_rdata         (mig_rdata       ),
    .s_axi_rresp         (mig_rresp       ),
    .s_axi_rlast         (mig_rlast       ),
    .s_axi_rvalid        (mig_rvalid      ),
    .s_axi_rready        (mig_rready      )
);


//AXI2APB
axi2apb_misc APB_DEV 
(
.clk                (sys_clk            ),
.rst_n              (sys_resetn         ),

.axi_s_awid         (apb_s_awid         ),
.axi_s_awaddr       (apb_s_awaddr       ),
.axi_s_awlen        (apb_s_awlen        ),
.axi_s_awsize       (apb_s_awsize       ),
.axi_s_awburst      (apb_s_awburst      ),
.axi_s_awlock       (apb_s_awlock       ),
.axi_s_awcache      (apb_s_awcache      ),
.axi_s_awprot       (apb_s_awprot       ),
.axi_s_awvalid      (apb_s_awvalid      ),
.axi_s_awready      (apb_s_awready      ),
.axi_s_wid          (apb_s_wid          ),
.axi_s_wdata        (apb_s_wdata        ),
.axi_s_wstrb        (apb_s_wstrb        ),
.axi_s_wlast        (apb_s_wlast        ),
.axi_s_wvalid       (apb_s_wvalid       ),
.axi_s_wready       (apb_s_wready       ),
.axi_s_bid          (apb_s_bid          ),
.axi_s_bresp        (apb_s_bresp        ),
.axi_s_bvalid       (apb_s_bvalid       ),
.axi_s_bready       (apb_s_bready       ),
.axi_s_arid         (apb_s_arid         ),
.axi_s_araddr       (apb_s_araddr       ),
.axi_s_arlen        (apb_s_arlen        ),
.axi_s_arsize       (apb_s_arsize       ),
.axi_s_arburst      (apb_s_arburst      ),
.axi_s_arlock       (apb_s_arlock       ),
.axi_s_arcache      (apb_s_arcache      ),
.axi_s_arprot       (apb_s_arprot       ),
.axi_s_arvalid      (apb_s_arvalid      ),
.axi_s_arready      (apb_s_arready      ),
.axi_s_rid          (apb_s_rid          ),
.axi_s_rdata        (apb_s_rdata        ),
.axi_s_rresp        (apb_s_rresp        ),
.axi_s_rlast        (apb_s_rlast        ),
.axi_s_rvalid       (apb_s_rvalid       ),
.axi_s_rready       (apb_s_rready       ),

//UART0
.uart0_txd_i        (uart0_txd_i      ),
.uart0_txd_o        (uart0_txd_o      ),
.uart0_txd_oe       (uart0_txd_oe     ),
.uart0_rxd_i        (uart0_rxd_i      ),
.uart0_rxd_o        (uart0_rxd_o      ),
.uart0_rxd_oe       (uart0_rxd_oe     ),
.uart0_rts_o        (uart0_rts_o      ),
.uart0_dtr_o        (uart0_dtr_o      ),
.uart0_cts_i        (uart0_cts_i      ),
.uart0_dsr_i        (uart0_dsr_i      ),
.uart0_dcd_i        (uart0_dcd_i      ),
.uart0_ri_i         (uart0_ri_i       ),
.uart0_int          (uart0_int        )
);
endmodule


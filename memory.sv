/*
 * File: memory.sv
 * Created: 14 Nov 2014
 * Modules contained: memory_simulation, memory_synthesis, memorySystem
 *
 * Changelog:
 * 04/13/2025: Changed synthesis memory block so only enabled when A[15]=0
 * 04/10/2025: Changed synthesis memory block to using Vivado Distrbuted
 * Memory IP. (vsetty)
 * 04/02/2025: Changed synthesis memory back to using Vivado's Block Memory IP. (vsetty)
 * 04/16/2024:  Added comment to memory initialization line to reduce
 *               confusion for students. (ckasuba)
 * 12/03/2020:  Changed synthesis memory to be inferred, initialized by the
 *              memory.mif file. Might not be backwards compatible with old
 *              Cyclone IV E boards. (ekusuma)
 */

 /*
 * module: memory
 *
 *  This is a full sized memory for the RISC240 and initialized with
 *  a memory.hex file.
 *
 */
module memory_simulation
  (input logic        clock, enable,
   input wr_enable_t  we_L,
   input rd_enable_t  re_L,
   inout wire  [15:0] data,
   input logic [15:0] address);

  logic [15:0] mem [16'hffff:16'h0000];

  assign data = (enable & (re_L === MEM_RD)) ? mem[address] : 16'bz;

  always @(posedge clock)
    if (enable & (we_L === MEM_WR))
      mem[address] <= data;

//  initial $readmemh("memory.hex", mem);
  /*
   * Let me explain why not $readmemh.
   * RISC240 memory is byte addressable, but all reads are 16-bits at a time.
   * Therefore, the memory array has to have a 16-bit data bus.  But, the
   * memory.hex file has one line per 16-bit word (i.e. two bytes).
   * $readmemh will take the first line and put it at Mem[0] and the second
   * line at Mem[1], etc.
   * We want the first lien at Mem[0] and the second line at Mem[2].
   * Therefore, custom memory loading code.
   */
  initial begin
    int fd, status;
    logic [14:0] addr;
    logic [15:0] value;
    fd = $fopen("memory.hex", "r");
    if (fd) begin
      addr = 16'h0;
      while (!$feof(fd)) begin
        status = $fscanf(fd,"%h", value);
        if (status == 1) begin
          mem[{addr, 1'b0}] = value;
          addr += 1;
        end
      end
    end else begin
      $display("File not found: memory.hex must be in the local directory");
      $fflush();
      $finish(2);
    end

    $fclose(fd);
  end

endmodule : memory_simulation

module memory_synthesis (
    input logic        clock, enable,
    input wr_enable_t  we_L,
    input rd_enable_t  re_L,
    inout tri  [15:0] data, /* tri is identical to wire */
    input logic [15:0] address
);

  //Use Distributed Mem Generator 8.0
  //Initialized with memory.coe
  logic [15:0] dina, douta;

  logic ena, wea;
  assign ena = enable & ((we_L === MEM_WR) || (re_L === MEM_RD));
  assign wea = enable & (we_L === MEM_WR);


  // In Synthesis, only the bottom half of memory is filled.
  // The top half does not map to any memory, so is available for
  // the student to use for Memory-mapped I/O.
  `ifdef synthesis
  dist_mem_gen_0 mem (
    .clk(clock),
    .we(wea),
    .a(address[14:1]),
    .d(dina),
    .spo(douta)
    );
  `endif

    /* The Implicit Bus Driver seen in typical 240 Implementations (S25)*/
    assign dina = data; //Bus always reads.
    assign data = (enable & re_L == MEM_RD) ? douta : 'bz;

endmodule : memory_synthesis



 /*
 * module: memorySystem
 *
 * This is our data memory, with combinational read and synchronous write.
 * Each memory word is 16 bits, and there is a 16 bit address space.
 */

`include "constants.sv"

module memorySystem (
   inout tri [15:0]   data,
   input logic [15:0]   address,
   input wr_enable_t we_L,
   input rd_enable_t re_L,
   input logic          clock); //Best to use CLOCK_100 for Vivado Synth Memory, since there's a 2-cycle read latency

`ifdef synthesis
    logic synth_enable;
    assign synth_enable = (address[15] == '0) ? '1 : '0;
    // Full sized memory for synthesis, initialized with memory.coe
    memory_synthesis memsyn (
        .clock      (clock),
        .enable     (synth_enable),
        .we_L       (we_L),
        .re_L       (re_L),
        .data       (data),
        .address    (address)
    );
`else
    // Full sized memory for simulation, initialized with memory.hex
    memory_simulation memsim (
        .clock      (clock),
        .enable     (1'b1),
        .we_L       (we_L),
        .re_L       (re_L),
        .data       (data),
        .address    (address)
    );
`endif

endmodule : memorySystem


/*
* So it turns out that there is some magic that Quartus uses that lets you
* initialize inferred memory with a MIF file.
*
* Source:
* https://www.intel.com/content/www/us/en/programmable/quartushelp/17.0/hdl/vlog/vlog_file_dir_ram_init.htm
*
* Basically a magic comment that the Quartus precompiler will handle.
*
* With this in place, a bram.v IP block is NOT necessary!
*
* NOTE: I am not sure if this method works with Cyclone IV E boards, or the
* older version of Quartus. If this course decides to revert to said boards then
* we may have to revisit this issue.
*/
module memory_synthesis_quartus (
    input logic        clock, enable,
    input wr_enable_t  we_L,
    input rd_enable_t  re_L,
    inout tri  [15:0] data, /* tri is identical to wire */
    input logic [15:0] address
);

    /* Thankfully Quartus does the sane thing and spits out an error if the
    * initialization file does not exist.
    */
    /* Seems like there are some students that fail synthesis with a full 16-bit
    * address space...as a workaround we can reduce that to 10 bits.
    */
    localparam NUM_WORDS = 2**10;
    logic [15:0] mem[0:NUM_WORDS-1] /* synthesis ram_init_file = "memory.mif" */; // DO NOT CHANGE THIS LINE!

    assign data = (enable & (re_L === MEM_RD)) ? mem[address[9:0]] : 16'bz;

    always @(posedge clock)
        if (enable & (we_L === MEM_WR))
            mem[address[9:0]] <= data;

endmodule : memory_synthesis_quartus

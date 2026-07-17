`timescale 1ns/1ps

/*
 * risc240_tb.sv
 *
 * Generic VCS regression testbench for RISC240_top.
 *
 * The RTL's memory_simulation module loads "memory.hex" from the current
 * working directory. This testbench waits for STOP/STOP1, then dumps the
 * architectural state to a text file for Python to verify.
 *
 * Run example:
 *   ./simv +STATE=rtl_state.txt +MAX_CYCLES=50000
 */

`include "constants.sv"

module risc240_tb;

    RISC240_top dut();

    string state_file;
    integer fd;
    integer max_cycles;
    integer tb_cycles;
    bit dumped;

        /*
         * When python launches the sim, it does for ex:
         * ./simv +STATE=/tmp/test13/rtl_state.txt +MAX_CYCLES=50000
         * Here, the plusargs are the +
         * EXAMPLE:
         * $value$plusargs("STATE=%s", state_file);
         * means:
         * "Did the simulator start with something like +STATE=...? If so, put that string into state_file."
         * WHY:
         * w/out plusargs you COULD write
         * 
         * initial begin
         *    state_file = "rtl_state.txt";
         *    max_cycles = 50000;
         * end
         * 
         * But every simulation would always use those values.
         * 
         * Now with plusargs:
         * The same compiled simulator can be configured differently each time you run it:
         * ./simv +STATE=test1.txt +MAX_CYCLES=500
         * or
         * ./simv +STATE=test2.txt +MAX_CYCLES=100000
         * 
         * No need for recompilation.
         * 
         * TLDR: No recompilation is needed because the SystemVerilog source never changes. 
         *       Only the runtime arguments (like the output filename or cycle limit) change.
         */
    
    initial begin
        if (!$value$plusargs("STATE=%s", state_file)) 
            state_file = "rtl_state.txt";

        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
            max_cycles = 50000;

        tb_cycles = 0;
        dumped = 0;
    end


    task automatic dump_state;
        integer address;
        begin
            if (dumped)
                return;

            dumped = 1;
            fd = $fopen(state_file, "w");

            if (fd == 0) begin
                $display("TB_ERROR: could not open state file %s", state_file);
                $finish(2);
            end
            // Here we can use the already built in "testbench" in the risc240 top to 
            // track the states of the registers
            // Scalar architectural state
            $fdisplay(fd, "PC=%04h", dut.pc); 
            $fdisplay(fd, "IR=%04h", dut.ir);
            $fdisplay(fd, "FLAGS=%01h", dut.condCodes);
            $fdisplay(fd, "ACC=%08h", dut.accResultOut);

            $fdisplay(fd, "R0=%04h", dut.r0);
            $fdisplay(fd, "R1=%04h", dut.r1);
            $fdisplay(fd, "R2=%04h", dut.r2);
            $fdisplay(fd, "R3=%04h", dut.r3);
            $fdisplay(fd, "R4=%04h", dut.r4);
            $fdisplay(fd, "R5=%04h", dut.r5);
            $fdisplay(fd, "R6=%04h", dut.r6);
            $fdisplay(fd, "R7=%04h", dut.r7);

            // Vector architectural state
            $fdisplay(fd, "V0=%016h", dut.dp.vfile.v0);
            $fdisplay(fd, "V1=%016h", dut.dp.vfile.v1);
            $fdisplay(fd, "V2=%016h", dut.dp.vfile.v2);
            $fdisplay(fd, "V3=%016h", dut.dp.vfile.v3);
            $fdisplay(fd, "V4=%016h", dut.dp.vfile.v4);
            $fdisplay(fd, "V5=%016h", dut.dp.vfile.v5);
            $fdisplay(fd, "V6=%016h", dut.dp.vfile.v6);
            $fdisplay(fd, "V7=%016h", dut.dp.vfile.v7);

            // Accumulator store result locations
            $fdisplay(fd, "M0200=%04h", dut.memmod.memsim.mem[16'h0200]);
            $fdisplay(fd, "M0202=%04h", dut.memmod.memsim.mem[16'h0202]);
            $fdisplay(fd, "M0204=%04h", dut.memmod.memsim.mem[16'h0204]);
            $fdisplay(fd, "M0206=%04h", dut.memmod.memsim.mem[16'h0206]);
            $fdisplay(fd, "M0208=%04h", dut.memmod.memsim.mem[16'h0208]);
            $fdisplay(fd, "M020A=%04h", dut.memmod.memsim.mem[16'h020A]);

            // Dump the data region used by the supplied regression tests.
            // memory_simulation is byte-addressed, and valid words are at
            // even addresses.
            for (address = 16'h0100; address <= 16'h013E; address += 2)
                $fdisplay(
                    fd,
                    "M%04h=%04h",
                    address[15:0],
                    dut.memmod.memsim.mem[address]
                );

            $fclose(fd);

            $display("TB_STATE_DUMPED=%s", state_file);
            $display("TB_STOP_STATE=%s", dut.currState.name);
            $display("TB_CYCLES=%0d", tb_cycles);
        end
    endtask

    /*
     * Dump as soon as the architectural machine reaches STOP or STOP1.
     * This occurs before the original simulation top's own timeout matters.
     */
    always @(negedge dut.clock) begin
        tb_cycles = tb_cycles + 1;

        if (!dumped && ((dut.currState == STOP) || (dut.currState == STOP1))) begin
            dump_state();
            #1;
            $finish;
        end

        if (tb_cycles >= max_cycles) begin
            $display(
                "TB_TIMEOUT: exceeded %0d cycles at PC=%04h state=%s",
                max_cycles,
                dut.pc,
                dut.currState.name
            );
            $finish(3);
        end
    end

endmodule

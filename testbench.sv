`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 08:20:54 AM
// Design Name: 
// Module Name: testbench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//================================================================
// File: testbench.sv
//================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

//---------------------------------------------------------
// 1. Transaction (Sequence Item)
//---------------------------------------------------------
class fir_seq_item extends uvm_sequence_item;
    rand logic signed [15:0] data_in;
    rand logic valid_in;
    logic signed [31:0] data_out;
    logic valid_out;

    `uvm_object_utils_begin(fir_seq_item)
        `uvm_field_int(data_in, UVM_ALL_ON)
        `uvm_field_int(valid_in, UVM_ALL_ON)
        `uvm_field_int(data_out, UVM_ALL_ON)
        `uvm_field_int(valid_out, UVM_ALL_ON)
    `uvm_object_utils_end

    // --- NEW: Constrained Random Block ---
    constraint data_c {
        // The 'dist' operator assigns weighted probabilities to values
        data_in dist {
            0               := 10,  // 10% chance to generate exactly 0
            32767           := 10,  // 10% chance to hit Max Positive
            -32768          := 10,  // 10% chance to hit Max Negative
            [-100:100]      := 20,  // 20% chance to pick a small value
            [-32767:32766]  :/ 50   // The remaining 50% should be spread equally for all other numbers
        };
    }

    function new(string name = "fir_seq_item");
        super.new(name);
    endfunction
endclass

//---------------------------------------------------------
// 2. Sequence
//---------------------------------------------------------
class fir_rand_seq extends uvm_sequence#(fir_seq_item);
    `uvm_object_utils(fir_rand_seq)
    
    function new(string name = "fir_rand_seq");
        super.new(name);
    endfunction
    
    task body();
    req = fir_seq_item::type_id::create("req");

    //---------------------------------------
    // 1. CONTROL COVERAGE 
    //---------------------------------------

    // 1 → 0 → 1 (stall)
    start_item(req);
    assert(req.randomize() with { valid_in == 1; });
    finish_item(req);

    start_item(req);
    assert(req.randomize() with { valid_in == 0; });
    finish_item(req);

    start_item(req);
    assert(req.randomize() with { valid_in == 1; });
    finish_item(req);

    // 1,1,1,1 (burst)
    repeat(4) begin
        start_item(req);
        assert(req.randomize() with { valid_in == 1; });
        finish_item(req);
    end


    //---------------------------------------
    // 2. DATA COVERAGE 
    //---------------------------------------

    // max_pos → max_neg transition
    start_item(req);
    assert(req.randomize() with { data_in == 32767; valid_in == 1; });
    finish_item(req);

    start_item(req);
    assert(req.randomize() with { data_in == -32768; valid_in == 1; });
    finish_item(req);

    // hit zero
    start_item(req);
    assert(req.randomize() with { data_in == 0; valid_in == 1; });
    finish_item(req);

    // hit small values
    repeat(100) begin
        start_item(req);
        assert(req.randomize() with { data_in inside {[-100:100]}; valid_in == 1; });
        finish_item(req);
    end


    //---------------------------------------
    // 3. RANDOM TRAFFIC 
    //---------------------------------------

    repeat(500) begin 
        start_item(req);
        assert(req.randomize() with { valid_in dist {1 := 80, 0 := 20}; });
        finish_item(req);
    end
endtask
endclass

//---------------------------------------------------------
// 3. Driver
//---------------------------------------------------------
class fir_driver extends uvm_driver#(fir_seq_item);
    `uvm_component_utils(fir_driver)
    virtual fir_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fir_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "Virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        wait(vif.reset_n == 1);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            vif.valid_in <= req.valid_in;
            vif.data_in  <= req.data_in;
            seq_item_port.item_done();
        end
    endtask
endclass

//---------------------------------------------------------
// 4. Monitors
//---------------------------------------------------------
class fir_input_monitor extends uvm_monitor;
    `uvm_component_utils(fir_input_monitor)
    virtual fir_if vif;
    uvm_analysis_port#(fir_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fir_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "Virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        fir_seq_item item;
        wait(vif.reset_n == 1);
        forever begin
            @(posedge vif.clk);
            item = fir_seq_item::type_id::create("item");
            item.data_in = vif.data_in;
            item.valid_in = vif.valid_in;
            ap.write(item); 
        end
    endtask
endclass

class fir_output_monitor extends uvm_monitor;
    `uvm_component_utils(fir_output_monitor)
    virtual fir_if vif;
    uvm_analysis_port#(fir_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fir_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "Virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        fir_seq_item item;
        wait(vif.reset_n == 1); 
        forever begin
            @(posedge vif.clk);
            if (vif.valid_out) begin
                item = fir_seq_item::type_id::create("item");
                item.data_out = vif.data_out;
                item.valid_out = vif.valid_out;
                ap.write(item);
            end
        end
    endtask
endclass

//---------------------------------------------------------
// 5. Predictor (Golden Reference)
//---------------------------------------------------------
class fir_predictor extends uvm_subscriber#(fir_seq_item);
    `uvm_component_utils(fir_predictor)
    
    uvm_analysis_port#(fir_seq_item) ap;
    logic signed [15:0] delay_line [$];
    logic signed [15:0] coeff [4] = '{16'h0800, 16'h1000, 16'h1000, 16'h0800};
    int N = 4;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void write(fir_seq_item t);
        fir_seq_item expected = fir_seq_item::type_id::create("expected");
        logic signed [31:0] acc = 0;
        
        if (t.valid_in) begin
            delay_line.push_front(t.data_in);
            if (delay_line.size() > N) delay_line.pop_back();

            foreach(delay_line[i]) begin
                acc += int'(delay_line[i]) * int'(coeff[i]); 
            end
            
            expected.data_out = acc;
            ap.write(expected); // Only send expected output when valid data was processed
        end
    endfunction
endclass

//---------------------------------------------------------
// 6. Scoreboard
//---------------------------------------------------------
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class fir_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fir_scoreboard)
    
    uvm_analysis_imp_expected#(fir_seq_item, fir_scoreboard) exp_export;
    uvm_analysis_imp_actual#(fir_seq_item, fir_scoreboard) act_export;
    
    fir_seq_item exp_queue[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        exp_export = new("exp_export", this);
        act_export = new("act_export", this);
    endfunction

    function void write_expected(fir_seq_item t);
        exp_queue.push_back(t);
    endfunction

    function void write_actual(fir_seq_item act);
        fir_seq_item exp;
        if (exp_queue.size() > 0) begin
            exp = exp_queue.pop_front();
            if (exp.data_out !== act.data_out) begin
                `uvm_error("SCBD", $sformatf("Mismatch! Exp: %0d, Act: %0d", exp.data_out, act.data_out))
            end else begin
                `uvm_info("SCBD", $sformatf("Match! Data: %0d", act.data_out), UVM_HIGH)
            end
        end
    endfunction
endclass

//---------------------------------------------------------
// 7. Coverage
//---------------------------------------------------------
class fir_coverage extends uvm_subscriber#(fir_seq_item);
    `uvm_component_utils(fir_coverage)
    fir_seq_item req;

    covergroup cg_data_in;
        option.per_instance = 1;
        cp_data: coverpoint req.data_in iff (req.valid_in) {
            bins zero       = {0};
            bins max_pos    = {32767};
            bins max_neg    = {-32768};
            bins small_vals = {[-100:100]};
            bins max_to_min = (32767 => -32768); 
        }
        cp_valid: coverpoint req.valid_in {
            bins active = {1};
            bins stalled = {0};
        }
    
        // 3. CROSS COVERAGE
        // the bins of cp_data and cp_valid
        cross_data_valid: cross cp_data, cp_valid {
            // Example: We might not care if the data is max_pos exactly when stalled,
            // so we could optionally ignore certain crosses to keep coverage goals realistic.
            // ignore_bins ignore_stall_max = binsof(cp_valid.stalled) && binsof(cp_data.max_pos);
        }
    endgroup

    covergroup cg_control;
        option.per_instance = 1;
        cp_valid: coverpoint req.valid_in {
            bins stall      = (1 => 0 => 1);
            bins burst_4    = (1 [* 4]);
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_data_in = new();
        cg_control = new();
    endfunction

    function void write(fir_seq_item t);
        req = t;
        cg_data_in.sample();
        cg_control.sample();
    endfunction
endclass

//---------------------------------------------------------
// 8. Agent
//---------------------------------------------------------
class fir_agent extends uvm_agent;
    `uvm_component_utils(fir_agent)
    
    uvm_sequencer#(fir_seq_item) sqr;
    fir_driver                   drv;
    fir_input_monitor            in_mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr    = uvm_sequencer#(fir_seq_item)::type_id::create("sqr", this);
        drv    = fir_driver::type_id::create("drv", this);
        in_mon = fir_input_monitor::type_id::create("in_mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

//---------------------------------------------------------
// 9. Environment
//---------------------------------------------------------
class fir_env extends uvm_env;
    `uvm_component_utils(fir_env)
    
    fir_agent          agent;
    fir_output_monitor out_mon;
    fir_predictor      predictor;
    fir_scoreboard     sb;
    fir_coverage       cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent     = fir_agent::type_id::create("agent", this);
        out_mon   = fir_output_monitor::type_id::create("out_mon", this);
        predictor = fir_predictor::type_id::create("predictor", this);
        sb        = fir_scoreboard::type_id::create("sb", this);
        cov       = fir_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.in_mon.ap.connect(predictor.analysis_export);
        agent.in_mon.ap.connect(cov.analysis_export);
        predictor.ap.connect(sb.exp_export);
        out_mon.ap.connect(sb.act_export);
    endfunction
endclass

//---------------------------------------------------------
// 10. Test
//---------------------------------------------------------
class fir_test extends uvm_test;
    `uvm_component_utils(fir_test)
    fir_env env;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fir_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fir_rand_seq seq = fir_rand_seq::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask
endclass

//---------------------------------------------------------
// 11. Top Level Module
//---------------------------------------------------------
module tb_top;
    logic clk;
    logic reset_n;

    fir_if vif(clk, reset_n);

    FIR_Filter dut (
        .clk(vif.clk),
        .reset_n(vif.reset_n),
        .valid_in(vif.valid_in),
        .data_in(vif.data_in),
        .valid_out(vif.valid_out),
        .data_out(vif.data_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset_n = 0;
        #20 reset_n = 1;
    end

    initial begin
        uvm_config_db#(virtual fir_if)::set(null, "*", "vif", vif);
        run_test("fir_test");
    end
endmodule

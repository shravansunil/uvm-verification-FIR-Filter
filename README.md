with open("README.md", "w") as f:
    f.write("""# UVM Verification Environment for Pipelined FIR Filter

This repository contains a complete, industry-standard **Universal Verification Methodology (UVM)** testbench designed to verify a parameterized, pipelined Finite Impulse Response (FIR) filter.

The testbench employs **Constrained Random Verification (CRV)**, **Directed-Random Sequences**, and comprehensive **Functional Coverage** to ensure 100% cycle-accurate verification of the Design Under Test (DUT) across both data path calculations and control signal protocols.

---

## Design Under Test (DUT) Specifications

The DUT is a synchronous, hardware-optimized FIR filter with a configurable number of taps (default $N=4$). It utilizes a 3-stage computational pipeline to maximize clock frequency.

> **Pro-Tip:** The DUT has a strict **3-cycle latency** from when `valid_in` is asserted to when the corresponding `valid_out` and `data_out` are produced. The testbench handles this latency automatically using a delay-matching FIFO scoreboard.

### Interface Signals

| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| **clk** | Input | 1-bit | System clock. |
| **reset_n** | Input | 1-bit | Active-low asynchronous reset. |
| **valid_in** | Input | 1-bit | Asserts when input data is valid. |
| **data_in** | Input | 16-bit | Signed input data stream. |
| **valid_out** | Output | 1-bit | Asserts when output data is valid. |
| **data_out** | Output | 32-bit | Signed accumulated output result. |

---

## Testbench Architecture

The environment is built upon the UVM 1.2 class hierarchy. It provides a self-checking, automated mechanism for stimulating the DUT and predicting expected outcomes.

### Core Components

- **`fir_seq_item`**: The fundamental transaction packet containing randomized `data_in` and `valid_in` stimulus, alongside output variables. It utilizes standard `dist` constraints to heavily weight edge-case generation (e.g., exactly `0`, Max Positive, Max Negative).
- **`fir_rand_seq`**: A **Directed-Random Sequence** that executes specific manual corner cases (e.g., immediate maximum-to-minimum transitions, consecutive stalls) followed by 500 packets of constrained random traffic.
- **`fir_agent`**: Encapsulates the Sequencer, Driver, and Input Monitor to manage the primary stimulus interface.
- **`fir_driver`**: Synchronizes sequence items to the physical virtual interface (`vif`) clock edges, strictly respecting the `reset_n` signal before driving.
- **`fir_monitors`**: Passive components (Input and Output) that continuously observe the bus. They capture data *only* when the corresponding `valid` signals are asserted, broadcasting transactions to the predictor, scoreboard, and coverage collectors via analysis ports.
- **`fir_predictor`**: The **Golden Reference Model**. Implemented in SystemVerilog, it mathematically mimics the FIR filter's delay line and coefficient multiplication using 32-bit arithmetic to prevent intermediate overflow.
- **`fir_scoreboard`**: An in-order FIFO checker. It queues expected transactions from the Predictor and pops them for rigorous comparison the moment the Output Monitor detects a `valid_out` assertion.

---

## Coverage Model

Achieving Coverage Closure is tracked via the `fir_coverage` subscriber. It guarantees that the randomizer effectively hits all mathematical and protocol boundaries.

### Functional Covergroups

- **`cg_data_in`**: Tracks extreme data limits. Bins ensure generation of `0`, `32767` (Max Pos), `-32768` (Max Neg), and `max_to_min` transition testing.
- **`cg_control`**: Tracks pipeline protocol health. Ensures the DUT is subjected to pipeline bubbles (stalls: `1 => 0 => 1`) and continuous streaming (bursts: `1 [* 4]`).
- **`cross_data_valid`**: A 2D cross-coverage matrix proving that all data extremes were tested under both streaming and stalled pipeline conditions.

---

## Simulation and Execution

This testbench is fully compatible with **Xilinx Vivado Simulator (XSIM)** and utilizes advanced elaboration flags to collect Code and Functional Coverage databases.

### Running via Command Line (XSIM)

To compile, elaborate, and run the simulation with coverage collection enabled, execute the following commands:

```bash
# 1. Elaborate with Code Coverage (sbct: Statement, Branch, Condition, Toggle)
xelab --incr --debug typical --relax --mt 8 -L xil_defaultlib -L uvm -L unisims_ver -L unimacro_ver -L secureip --snapshot tb_top_behav xil_defaultlib.tb_top xil_defaultlib.glbl -cc_type sbct

# 2. Run Simulation specifying the UVM Test
xsim tb_top_behav -testplusarg UVM_TESTNAME=fir_test -testplusarg UVM_VERBOSITY=UVM_LOW -runall

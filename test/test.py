# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_vga_mandala(dut):
    dut._log.info("Starting VGA Mandala Art test")

    # Initialize clock (25 MHz for VGA 640x480 @60Hz standard)
    clock = Clock(dut.clk, 40, units="ns")  # 40ns period = 25MHz
    cocotb.start_soon(clock.start())

    # Apply reset
    dut._log.info("Applying reset")
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut._log.info("Reset released")

    # Monitor VGA synchronization signals
    await ClockCycles(dut.clk, 100)
    dut._log.info(f"HSYNC: {dut.uo_out.value & 0b10000000 != 0}")
    dut._log.info(f"VSYNC: {dut.uo_out.value & 0b00010000 != 0}")

    # Ensure HSYNC and VSYNC toggle within reasonable cycles
    hsync_seen, vsync_seen = False, False
    for _ in range(5000):  # Run for enough cycles to capture at least one full frame
        await RisingEdge(dut.clk)
        hsync = dut.uo_out.value & 0b10000000
        vsync = dut.uo_out.value & 0b00010000
        if hsync:
            hsync_seen = True
        if vsync:
            vsync_seen = True
        if hsync_seen and vsync_seen:
            break
    
    assert hsync_seen, "HSYNC signal was not observed"
    assert vsync_seen, "VSYNC signal was not observed"
    dut._log.info("HSYNC and VSYNC observed, VGA signal functioning")

    # Check pixel color outputs
    for _ in range(100):
        await RisingEdge(dut.clk)
        pixel_color = dut.uo_out.value & 0b00101111  # Extracting RGB bits
        dut._log.info(f"Pixel Color Output: {bin(pixel_color)}")
    
    dut._log.info("VGA Mandala Art Test Completed Successfully")

    # # Change it to match the actual expected output of your module:
    # assert dut.uo_out.value == 50

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.

# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from pysolitaire.solitaire.board import Move
from pysolitaire.solitaire.players.random import RandomPlayer

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Create a random player (contains board state)
    player = RandomPlayer()

    while len(player.board.get_moves() > 0):
        next_move: Move = player.get_next_move()
        input_val = next_move.x
        input_val |= next_move.y << 3
        input_val |= int(next_move.jump_dir) << 6
        dut.ui_in.value = input_val

        # Wait for one clock cycle to see the output values
        await ClockCycles(dut.clk, 1)
        output_val = int(dut.uo_out.value)
        assert output_val == player.board.num_pieces()

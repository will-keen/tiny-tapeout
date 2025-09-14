# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import os
import sys
from pathlib import Path
# add pysolitaire directory to module search path
sys.path.append((Path(os.getcwd())/"pysolitaire").as_posix())

from pysolitaire.solitaire.board import Move
from pysolitaire.solitaire.players.random import RandomPlayer

import random


def pack_input(next_move: Move):
    input_val = next_move.x
    input_val |= next_move.y << 3
    # Python enum.auto starts at 1... :/
    input_val |= (next_move.jump_dir.value - 1) << 6
    return input_val

def unpack_output(output_val: int):
    num_pieces = output_val & ((1 << 6) - 1) 
    game_over = output_val >> 6
    return num_pieces, game_over

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

    # Tiny Tapeout CI doesn't appear to use a constant seed
    random.seed(0)

    # Create a random player (contains board state)
    player = RandomPlayer()

    while len(player.board.get_moves()) > 0:
        # Get a random move
        next_move: Move = player.get_next_move()
        # Apply move to board
        dut.ui_in.value = pack_input(next_move)

        # Wait for one clock cycle to see the output values
        await ClockCycles(dut.clk, 1)
        output_val = int(dut.uo_out.value)
        num_pieces, game_over = unpack_output(output_val)
        assert num_pieces == player.board.num_pieces()
        assert not game_over

        # Apply move to model board
        player.board.apply_move(next_move)

    for _ in range (10):
        # Check that the number of pieces left remains stable
        await ClockCycles(dut.clk, 1)
        output_val = int(dut.uo_out.value)
        num_pieces, game_over = unpack_output(output_val)
        assert num_pieces == player.board.num_pieces()
        assert game_over

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

from pysolitaire.solitaire.board import Move, BOARD_WIDTH, space_exists
from pysolitaire.solitaire.players.random import RandomPlayer

import random


def pack_input(next_move: Move) -> int:
    input_val = next_move.x
    input_val |= next_move.y << 3
    # Python enum.auto starts at 1... :/
    input_val |= (next_move.jump_dir.value - 1) << 6
    return input_val

def unpack_output(output_val: int) -> tuple[int, int]:
    num_pieces = output_val & ((1 << 6) - 1) 
    game_over = output_val >> 6
    return num_pieces, game_over

def get_rtl_board_str(rtl_board_packed: int) -> str:
    board_str = ""
    board_str += "  " + " ".join(str(x) for x in range(BOARD_WIDTH)) + "\n"
    for y in range(BOARD_WIDTH):
        board_str += f"{y} "
        for x in range(BOARD_WIDTH):
            peg = ((rtl_board_packed >> (y * BOARD_WIDTH)) >> x) & 1
            space_str = " " if not space_exists(x, y) else "o" if peg else "."
            board_str += space_str + " "
        board_str += "\n"
    return board_str[:-1]


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

    # Internal debugging can be enabled if not running gate level sim
    internal_debug = False

    while len(player.board.get_moves()) > 0:
        # Get a random move
        next_move: Move = player.get_next_move()
        # Apply move to board
        dut.ui_in.value = pack_input(next_move)

        # Wait for one clock cycle to see the output values
        await ClockCycles(dut.clk, 1)
        output_val = int(dut.uo_out.value)
        rtl_num_pieces, game_over = unpack_output(output_val)
        model_board_pieces = player.board.num_pieces()
        if internal_debug:
            rtl_board = int(dut.user_project.u_solitaire.board.value)
            rtl_board_str = get_rtl_board_str(rtl_board)
            dut._log.info("RTL board:\n%s", rtl_board_str)
            dut._log.info("RTL board pieces: %d", rtl_num_pieces)
            assert rtl_board.bit_count() == model_board_pieces
        assert rtl_num_pieces == model_board_pieces
        assert not game_over

        # Apply move to model board
        dut._log.info("model board:\n%s", player.board)
        dut._log.info("model board pieces: %d", model_board_pieces)
        dut._log.info(f"applying next move: {next_move}")
        player.board.apply_move(next_move)

    for _ in range (10):
        # Check that the number of pieces left remains stable
        await ClockCycles(dut.clk, 1)
        output_val = int(dut.uo_out.value)
        num_pieces, game_over = unpack_output(output_val)
        assert num_pieces == player.board.num_pieces()
        assert game_over

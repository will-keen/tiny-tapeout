
module solitaire(
  input  wire clk,
  input  wire rst_n,
  input  wire [2:0] piece_x,
  input  wire [2:0] piece_y,
  input  wire [1:0] direction,
  output wire [5:0] piece_count,
  output wire       game_over
);

  // Models a peg solitaire board:
  //     0 1 2 3 4 5 6
  //  0      x x x
  //  1      x x x
  //  2  x x x x x x x
  //  3  x x x 0 x x x
  //  4  x x x x x x x
  //  5      x x x
  //  6      x x x

  localparam BOARD_WIDTH = 7;
  // Dead zones - the corners of the board in x/y have no spaces
  localparam MIN_VAL = 2;
  localparam MAX_VAL = BOARD_WIDTH - 2;

  localparam [1:0]
    LEFT  = 2'b00,
    RIGHT = 2'b01,
    UP    = 2'b10,
    DOWN  = 2'b11;

  // This is a hack.
  // We can't have the same dimensions as board a localparam due to tool limitations.
  localparam [(BOARD_WIDTH*BOARD_WIDTH)-1:0] SPACE_EXISTS = 49'h070e7ffffce1c;
  // Reset needs to be a constant for synthesis.
  // It has the same value as space_exists,
  // but with the centremost peg removed.
  localparam [(BOARD_WIDTH*BOARD_WIDTH)-1:0] BOARD_RESET_VALUE = 49'h070e7feffce1c;

  // NOTE: Index this by y first - I did it that way in the Python code (can't remember why!)
  reg  [BOARD_WIDTH-1:0][BOARD_WIDTH-1:0] board;
  wire [BOARD_WIDTH-1:0][BOARD_WIDTH-1:0] board_nxt;
  wire [BOARD_WIDTH-1:0][BOARD_WIDTH-1:0] space_exists;
  wire [BOARD_WIDTH-1:0][BOARD_WIDTH-1:0] move_request;
  wire [BOARD_WIDTH-1:0][BOARD_WIDTH-1:0][3:0] move_legal;
  wire [BOARD_WIDTH-1:0][BOARD_WIDTH-1:0][3:0] move_valid;

  genvar x, y;

  generate
    for (x=0; x<BOARD_WIDTH; x++) begin: g_x
      for (y=0; y<BOARD_WIDTH; y++) begin: g_y

        // Whether a space exists on the grid
        assign space_exists[y][x] =
          (
            (x >= MIN_VAL && x < MAX_VAL) && (
              (y >= MIN_VAL) || (y < MAX_VAL)
            )
          ) ||
          (
            (y >= MIN_VAL && y < MAX_VAL) && (
              (x >= MIN_VAL) || (x < MAX_VAL)
            )
          );

        // Whether the user is requesting a move for a particular piece.
        assign move_request[y][x] =
            (piece_x == x) &&
            (piece_y == y);

        // Whether the input move is legal or not
        // Space must exist and contain a piece
        // Must be a piece in the space to the right.
        // Must be an unoccupied space to the right of that.
        if (x < (BOARD_WIDTH - 2)) begin: g_move_legal_right
          assign move_legal[y][x][RIGHT] =
            space_exists[y][x] &&
            space_exists[y][x+1'b1] &&
            space_exists[y][x+2'd2] &&
            board[y][x] &&
            board[y][x+1'b1] &&
            !board[y][x+2'd2];
        end else begin : g_move_legal_right_oob
          assign move_legal[y][x][RIGHT] = 1'b0;
        end
        assign move_valid[y][x][RIGHT] =
          (direction == RIGHT) &&
          move_request[y][x] &&
          move_legal[y][x][RIGHT];
        // Must be a piece in the space to the left.
        // Must be an unoccupied space to the left of that.
        if (x > 1) begin : g_move_legal_left
          assign move_legal[y][x][LEFT] =
            space_exists[y][x] &&
            space_exists[y][x-1'b1] &&
            space_exists[y][x-2'd2] &&
            board[y][x] &&
            board[y][x-1'b1] &&
            !board[y][x-2'd2];
        end else begin : g_move_legal_left_oob
          assign move_legal[y][x][LEFT] = 1'b0;
        end
        assign move_valid[y][x][LEFT] =
          (direction == LEFT) &&
          move_request[y][x] &&
          move_legal[y][x][LEFT];
        // Must be a piece in the space above.
        // Must be an unoccupied space above of that.
        if (y > 1) begin : g_move_legal_up
          assign move_legal[y][x][UP] =
            space_exists[y][x] &&
            space_exists[y-1'b1][x] &&
            space_exists[x][y-2'd2] &&
            board[y][x] &&
            board[y-1'b1][x] &&
            !board[y-2'd2][x];
        end else begin : g_move_legal_up_oob
          assign move_legal[y][x][UP] = 1'b0;
        end
        assign move_valid[y][x][UP] =
          (direction == UP) &&
          move_request[y][x] &&
          move_legal[y][x][UP];
        // Must be a piece in the space above.
        // Must be an unoccupied space above of that.
        if (y < (BOARD_WIDTH - 2)) begin : g_move_legal_down
          assign move_legal[y][x][DOWN] =
            space_exists[y][x] &&
            space_exists[y+1'b1][x] &&
            space_exists[y+2'd2][x] &&
            board[y][x] &&
            board[y+1'b1][x] &&
            !board[y+2'd2][x];
        end else begin : g_move_legal_down_oob
          assign move_legal[y][x][DOWN] = 1'b0;
        end
        assign move_valid[y][x][DOWN] =
          (direction == DOWN) &&
          move_request[y][x] &&
          move_legal[y][x][DOWN];

        // Next board state
        if (SPACE_EXISTS[(y * BOARD_WIDTH) + x]) begin : g_exists
          // Throughout this, we have to ensure x and y don't go out of bounds.
          // We do this with modulo and ternaries. It looks awful.
          assign board_nxt[y][x] = // If the move is valid for the space itself,
                                   // it loses its peg.
                                   move_valid[y][x][LEFT] ? 1'b0 :
                                   move_valid[y][x][RIGHT] ? 1'b0 :
                                   move_valid[y][x][UP] ? 1'b0 :
                                   move_valid[y][x][DOWN] ? 1'b0 :
                                   // If the move is valid for an adjacent space
                                   // towards this space, this space loses its peg.
                                   ((x < BOARD_WIDTH) && move_valid[y][(x+1)%BOARD_WIDTH][LEFT]) ? 1'b0 :
                                   ((x > 0) && move_valid[y][((x-1) >= 0 ? (x-1) : 0)][RIGHT]) ? 1'b0 :
                                   ((y < BOARD_WIDTH) && move_valid[(y+1)%BOARD_WIDTH][x][UP]) ? 1'b0 :
                                   ((y > 0) && move_valid[((y-1) >= 0 ? (y-1) : 0)][x][DOWN]) ? 1'b0 :
                                   // If the move is valid for a space
                                   // two spaces away towards this space,
                                   // this space gains a peg.
                                   ((x < (BOARD_WIDTH-1)) && move_valid[y][(x+2)%BOARD_WIDTH][LEFT]) ? 1'b1 :
                                   ((x > 1) && move_valid[y][((x-2) >= 0 ? (x-2) : 0)][RIGHT]) ? 1'b1 :
                                   ((y < (BOARD_WIDTH-1)) && move_valid[(y+2)%BOARD_WIDTH][x][UP]) ? 1'b1 :
                                   ((y > 1) && move_valid[((y-2) >= 0 ? (y-2) : 0)][x][DOWN]) ? 1'b1 :
                                   // Otherwise it stays the same
                                   board[y][x];
        end else begin : g_doesnt_exist
          assign board_nxt[y][x] = 1'b0;
        end

      end // y
    end // x
  endgenerate

  wire board_en;

  assign board_en = |move_valid;

  always_ff @(posedge clk or negedge rst_n) begin : ff_board
    if (!rst_n) begin
      // Use localparam to ensure constant reset.
      // Can't match the packed dimensions with a localparam.
      board <= BOARD_RESET_VALUE;
    end else if (board_en) begin
      board <= board_nxt;
    end
  end

  // There are up to 32 pieces on the board
  reg [5:0] piece_count_r;
  wire      piece_count_r_en;

  assign piece_count_r_en = |move_valid;

  always_ff @(posedge clk or negedge rst_n) begin : ff_count
    if (~rst_n) begin
      piece_count_r <= 6'd32;
    end else if (piece_count_r_en) begin
      piece_count_r <= piece_count_r - 6'b1;
    end
  end

  assign piece_count = piece_count_r;

  assign game_over = ~|move_legal;

endmodule
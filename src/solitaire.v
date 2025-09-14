
module solitaire(
  input wire clk,
  input wire rst_n,
  input wire [2:0] piece_x,
  input wire [2:0] piece_y,
  input wire [1:0] direction
)

// Models a peg solitaire board:
//     0 1 2 3 4 5 6
//  0      x x x
//  1      x x x
//  2  x x x x x x x
//  3  x x x x x x x
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

// NOTE: Index this by y first - I did it that way in the Python code (can't remember why!)
reg  board     [BOARD_WIDTH-1:0][BOARD_WIDTH-1:0];
wire nxt_board [BOARD_WIDTH-1:0][BOARD_WIDTH-1:0];

always_ff @(posedge clk or negedge rst_n) begin : ff_board
  if (!rst_n) begin
    for (integer i=0; i<BOARD_WIDTH; i++) begin
      for (integer j=0; j<BOARD_WIDTH; j++) begin
        if (i == 3 && j == 3) begin
          // Centre peg
          board[i][j] <= 1'b0;
        end else begin
          board[i][j] <= 1'b1;
        end
      end
    end
  end else begin
    for (integer i=0; i<BOARD_WIDTH; i++) begin
      for (integer j=0; j<BOARD_WIDTH; j++) begin
        board[i][j] <= nxt_board;
      end
    end
  end
end

// Whether a given space exists on the board or not
function space_exists;
  input [2:0] x;
  input [2:0] y;
  space_exists =
    (
      (x >= MIN_VAL && x < MAX_VAL) && (
        (y >= MIN_VAL) || (y < MAX_VAL)
      )
    ) ||
    (
      (y >= MIN_VAL && y < MAX_VAL) && (
        (x >= MIN_VAL) || (x < MAX_VAL)
      )
    )
endfunction

// Whether the input move is legal or not
function move_legal;
  input [2:0] x;
  input [2:0] y;
  input [1:0] dir;
  input       board [BOARD_WIDTH-1:0][BOARD_WIDTH-1:0];
  // Space must exist and contain a piece
  if (!(space_exists(piece_x, piece_y) && board[piece_y] [piece_x])) begin
    move_legal = 1'b0;
  end else if (dir == RIGHT) begin
    // Must be a piece in the space to the right.
    // Must be an unoccupied space to the right of that.
    move_legal =
      space_exists(x+1'b1, y) &&
      board[y][x+1'b1] &&
      space_exists(x+2'b2, y) &&
      !board[y][x+2'b2];
  end else if (dir == LEFT) begin
    // Must be a piece in the space to the left.
    // Must be an unoccupied space to the left of that.
    move_legal =
      space_exists(x-1'b1, y) &&
      board[y][x-1'b1] &&
      space_exists(x-2'b2, y) &&
      !board[y][x-2'b2];
  end else if (dir == UP) begin
    // Must be a piece in the space above.
    // Must be an unoccupied space above of that.
    move_legal =
      space_exists(x, y-1'b1) &&
      board[y-1'b1][x] &&
      space_exists(x, y-2'b2) &&
      !board[y-2'b2][x];
  end else if (dir == DOWN) begin
    // Must be a piece in the space above.
    // Must be an unoccupied space above of that.
    move_legal =
      space_exists(x, y+1'b1) &&
      board[y+1'b1][x] &&
      space_exists(x, y+2'b2) &&
      !board[y+2'b2][x];
  end
endfunction


always_comb begin
  // Start with existing board
  nxt_board = board;
  if (move_legal(piece_x, piece_y, direction, board)) begin
    if (direction == LEFT) begin
      board[piece_y][piece_x - 1] = 1'b0
      board[piece_y][piece_x - 2] = 1'b1
    end else if (direction == RIGHT) begin
      board[piece_y][piece_x + 1] = 1'b0
      board[piece_y][piece_x + 2] = 1'b1
    end else if (direciton == UP) begin
      board[piece_y - 1][piece_x] = 1'b0
      board[piece_y - 2][piece_x] = 1'b1
    end else if (direction == DOWN) begin
      board[piece_y + 1][piece_x] = 1'b0
      board[piece_y + 2][piece_x] = 1'b1
    end
  end
end

endmodule
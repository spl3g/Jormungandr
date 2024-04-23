package snake

import rl "vendor:raylib"
import "core:c"
import "core:fmt"
import "core:os"
import "core:math/rand"
import "core:strings"

BG :: rl.Color {47, 56, 62, 255}
FIELD :: rl.Color {74, 85, 91, 255}
SNAKE_TAIL :: rl.Color {127, 187, 179, 255}
SNAKE_HEAD :: rl.Color {160, 205, 199, 255}
FRUIT :: rl.Color {230, 126, 128, 255}

Field :: [dynamic][dynamic]FieldCell
Snake :: [dynamic][2]int

Direction :: enum {
    Up,
    Down,
    Left,
    Right,
}

FieldCell :: enum {
    None = 0,
    Head,
    Fruit,
}

Result :: enum {
    None = 0,
    WrongDirection,
    GameOver,
    Menu,
}

Menu :: proc(w, h: i32, choice: ^int) -> Result {
    text: cstring = "Jörmungandr"
    position := w / 2 - i32(rl.MeasureText(text, 40)) / 2
    rl.DrawText(text, position, h / 2 - 50, 40, SNAKE_TAIL)
    
    f_color := SNAKE_TAIL
    s_color := SNAKE_TAIL
    switch choice^ {
    case 0:
	s_color = FRUIT
    case 1:
	f_color = FRUIT
    }
    text = "Play"
    position = w / 2 - i32(rl.MeasureText(text, 30)) / 2
    rl.DrawText(text, position, h / 2 + 20, 30, f_color)

    text = "Exit"
    position = w / 2 - i32(rl.MeasureText(text, 30)) / 2
    rl.DrawText(text, position, h / 2 + 50, 30, s_color)
    
    switch {
    case rl.IsKeyPressed(rl.KeyboardKey.UP):
	if choice^ < 2 {
	    choice^ += 1
	}
    case rl.IsKeyPressed(rl.KeyboardKey.DOWN):
	if choice^ >= 0 {
	    choice^ -= 1
	}
    case rl.IsKeyPressed(rl.KeyboardKey.SPACE):
	switch choice^ {
	case 0:
	    rl.CloseWindow()
	    os.exit(0)
	case 1:
	    return nil
	}
    }
    return Result.Menu
}

MovePlayer :: proc(direction: Direction, snake: ^Snake, table: ^Field) -> Result {
    next: ^FieldCell
    y, x: int
    switch direction {
    case .Up:
	x = snake[0][0]
	y = snake[0][1] - 1
    case .Down:
	x = snake[0][0]
	y = snake[0][1] + 1
    case .Left:
	x = snake[0][0] - 1
	y = snake[0][1]
    case .Right:
	x = snake[0][0] + 1
	y = snake[0][1]
    }

    switch {
    case x > len(table) - 1:
	x = 0
    case y > len(table) - 1:
	y = 0
    case y < 0:
	y = len(table) - 1
    case x < 0:
	x = len(table) - 1
    }
    
    next = &table[y][x]
    if len(snake) > 1 && x == snake[1][0] && y == snake[1][1] {
	return Result.WrongDirection
    }

    #partial switch next^ {
	case .None:
	last := pop(snake)
	inject_at(snake, 0, [2]int{x, y})
	table[last[1]][last[0]] = FieldCell.None
	next^ = FieldCell.Head
	case .Head:
	return Result.GameOver
	case .Fruit:
	inject_at(snake, 0, [2]int{x, y})
	next^ = FieldCell.Head
	PlaceFruit(table, snake)
    }
    return Result.None
}

Lose :: proc(w, h, wh: i32 res: ^Result, field: ^Field, snake: ^Snake) {
    rl.ClearBackground(BG)
    text: cstring = "YOU LOST"
    position := w / 2 - i32(rl.MeasureText(text, 30)) / 2
    rl.DrawText(text, position, h / 2 - 30, 30, FRUIT)
    
    text = "press space to return to the main menu"
    position = w / 2 - i32(rl.MeasureText(text, 20)) / 2
    rl.DrawText(text, position, h / 2 + 30, 20, FRUIT)
    
    using fmt
    score_text := "your score is {}"
    cscore := ctprintf(score_text, len(snake)) 
    position = w / 2 - i32(rl.MeasureText(cscore, 25)) / 2
    rl.DrawText(cscore, position, h / 2, 25, SNAKE_TAIL)
    
    if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
	res^ = Result.Menu
	field^ = make(Field, wh)
	for &arr in field {
	    arr = make([dynamic]FieldCell, wh)
	}
	field[wh/2][wh/2] = FieldCell.Head
	snake^ = make(Snake, 0, wh * wh)
	append(snake, [2]int{int(wh/2), int(wh/2)})
	PlaceFruit(field, snake)
    }
}

PlaceFruit :: proc(field: ^Field, snake: ^Snake) {
    rx: i32
    ry: i32
    for {
	rx = rand.int31_max(11)
	ry = rand.int31_max(11)
	if field[rx][ry] == FieldCell.Head {
	    rx = rand.int31_max(11)
	    ry = rand.int31_max(11)
	    continue
	}
	field[rx][ry] = FieldCell.Fruit
	break
    }
}

DrawField :: proc(w, h, rwidth, amount: i32, table: Field, snake: Snake) {
    cube := (rwidth + 5) * (amount / 2)
    
    startx := w / 2 - cube
    starty := h / 2 - cube
    endx := w / 2 + cube
    endy := h / 2 + cube
    if startx < 0 || starty < 0 || endx > w || endy > h {
	text: cstring = "Window is too small"
	position := w / 2 - i32(rl.MeasureText(text, 13)) / 2
	rl.DrawText(text, position, h / 2, 13, rl.GRAY)
    } else {
	for i in 0..<amount {
	    for j in 0..<amount {
		jx := startx + (rwidth + 5) * j
		iy := starty +(rwidth + 5) * i
		color: rl.Color;
		switch table[i][j] {
		case .Head:
		    color = SNAKE_TAIL
		case .Fruit:
		    color = FRUIT
		case .None:
		    color = FIELD
		}
		if int(j) == snake[0][0] && int(i) == snake[0][1] {
		    color = SNAKE_HEAD
		}
		rl.DrawRectangle(jx, iy, rwidth, rwidth, color)
	    }
	}
    }
}

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE});
    rl.InitWindow(800, 800, "Jörmungandr")
    rl.SetTargetFPS(60)

    wh: i32 = 11
    field := make(Field, wh)
    for &arr in field {
	arr = make([dynamic]FieldCell, wh)
    }
    field[wh/2][wh/2] = FieldCell.Head
    snake := make(Snake, 0, wh * wh)
    append(&snake, [2]int{int(wh/2), int(wh/2)})
    PlaceFruit(&field, &snake)
    
    direction := Direction.Right
    last_direction: Direction;
    count := 0
    res: Result = Result.Menu
    choice := 1
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(BG)

	if res == Result.Menu {
	    res = Menu(rl.GetScreenWidth(), rl.GetScreenHeight(), &choice)
	} else if res == Result.GameOver {
	    Lose(rl.GetScreenWidth(), rl.GetScreenHeight(), wh, &res, &field, &snake)
	} else {
	    DrawField(rl.GetScreenWidth(), rl.GetScreenHeight(), 20, wh, field, snake)
	    if count == 10 {
		res = MovePlayer(direction, &snake, &field)
		if res == Result.WrongDirection {
		    direction = last_direction
		    continue
		}
		last_direction = direction
		count = 0
	    }
	    
	    switch {
	    case rl.IsKeyPressed(rl.KeyboardKey.UP):
		direction = Direction.Up
	    case rl.IsKeyPressed(rl.KeyboardKey.DOWN):
		direction = Direction.Down
	    case rl.IsKeyPressed(rl.KeyboardKey.LEFT):
		direction = Direction.Left
	    case rl.IsKeyPressed(rl.KeyboardKey.RIGHT):
		direction = Direction.Right
	    }
	    count += 1
	}
	
        rl.EndDrawing()
    }

    rl.CloseWindow()
}

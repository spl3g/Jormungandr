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

State :: enum {
    None = 0,
    WrongDirection,
    GameOver,
    Menu,
    Settings,
}

Menu :: proc(w, h, field_width, field_height: i32, choice: ^int, field: ^Field, snake: ^Snake) -> State {
    title: cstring = "Jörmungandr"
    position := w / 2 - i32(rl.MeasureText(title, 40)) / 2
    rl.DrawText(title, position, h / 2 - 50, 40, SNAKE_TAIL)
    
    
    buttons := [?]cstring{"Play", "Settings", "Exit"}
    DrawButtons(buttons[:], w, h, choice)
    
    if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
	switch choice^ {
	case 0:
	    PrepareField(field_width, field_height, field, snake)
	    return nil
	case 1:
	    choice^ = 0
	    return State.Settings
	case 2:
	    rl.CloseWindow()
	    os.exit(0)
	}
    }
    return State.Menu
}

Settings :: proc(w, h: i32, field_width, field_height: ^i32, choice: ^int) -> State {
    title: cstring = "Settings"
    position := w / 2 - i32(rl.MeasureText(title, 40)) / 2
    rl.DrawText(title, position, h / 2 - 50, 40, SNAKE_TAIL)
    
    wbutton: cstring = fmt.ctprintf("Field width: {}", field_width^) 
    hbutton: cstring = fmt.ctprintf("Field height: {}", field_height^)
    buttons := [?]cstring{wbutton, hbutton, "Back"}
    DrawButtons(buttons[:], w, h, choice)
    wh := [2]^i32{field_width, field_height}
    if choice^ < 2 {
	switch {
	case rl.IsKeyPressed(rl.KeyboardKey.LEFT):
	    if choice^ > 2 {
		wh[choice^]^ -= 1
	    }
	case rl.IsKeyPressed(rl.KeyboardKey.RIGHT):
	    wh[choice^]^ += 1
	}
    }
    
    if rl.IsKeyPressed(rl.KeyboardKey.SPACE) && choice^ == 2 {
	return State.Menu
    }
     
    return State.Settings
}

DrawButtons :: proc(buttons: []cstring, w, h: i32, choice: ^int) {
    colors := make([]rl.Color, len(buttons))
    defer delete(colors)
    position: i32
    for button in 0..<len(buttons) {
	colors[button] = SNAKE_TAIL
    }
    colors[choice^] = FRUIT
    for button, index in buttons {
	position = w / 2 - i32(rl.MeasureText(button, 30)) / 2
	rl.DrawText(button, position, h / 2 + 20 + 30 * i32(index), 30, colors[index])
    }
    switch {
    case rl.IsKeyPressed(rl.KeyboardKey.UP):
	if choice^ > 0 {
	    choice^ -= 1
	}
    case rl.IsKeyPressed(rl.KeyboardKey.DOWN):
	if choice^ < len(buttons) {
	    choice^ += 1
	}
    }
}

MovePlayer :: proc(direction: Direction, snake: ^Snake, field: ^Field) -> State {
    next: ^FieldCell
    y, x: int
    field_width := len(field^[0])
    field_height := len(field^)
    
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
    case x > int(field_width) - 1:
	x = 0
    case y > int(field_height) - 1:
	y = 0
    case y < 0:
	y = int(field_height) - 1
    case x < 0:
	x = int(field_width) - 1
    }
    
    next = &field[y][x]
    if len(snake) > 1 && x == snake[1][0] && y == snake[1][1] {
	return State.WrongDirection
    }

    #partial switch next^ {
    case .None:
	last := pop(snake)
	inject_at(snake, 0, [2]int{x, y})
	field[last[1]][last[0]] = FieldCell.None
	next^ = FieldCell.Head
    case .Head:
	return State.GameOver
    case .Fruit:
	inject_at(snake, 0, [2]int{x, y})
	next^ = FieldCell.Head
	PlaceFruit(field, snake)
    }
    return State.None
}

Lose :: proc(w, h: i32, snake: Snake) -> State {
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
	return State.Menu
    }
    return State.GameOver
}

PlaceFruit :: proc(field: ^Field, snake: ^Snake) {
    rx: int
    ry: int
    field_width := len(field^[0]) - 1
    field_height := len(field^) - 1
    for {
	rx = rand.int_max(field_width)
	ry = rand.int_max(field_width)
	if field[rx][ry] == FieldCell.Head {
	    rx = rand.int_max(field_width)
	    ry = rand.int_max(field_width)
	    continue
	}
	field[rx][ry] = FieldCell.Fruit
	break
    }
}

PrepareField :: proc(field_width, field_height: i32, field: ^Field, snake: ^Snake) {
	field^ = make(Field, field_height)
	for &arr in field {
	    arr = make([dynamic]FieldCell, field_width)
	}
	field[field_height/2][field_width/2] = FieldCell.Head
	snake^ = make(Snake, 0, field_width * field_height)
	append(snake, [2]int{int(field_width/2), int(field_height/2)})
	PlaceFruit(field, snake)
}

DrawField :: proc(w, h, rwidth, field_width, field_height: i32, field: Field, snake: Snake) {
    cubex := (rwidth + 5) * (field_width / 2)
    cubey := (rwidth + 5) * (field_height / 2)
    
    startx := w / 2 - cubex
    starty := h / 2 - cubey
    endx := w / 2 + cubex
    endy := h / 2 + cubey
    if startx < 0 || starty < 0 || endx > w || endy > h {
	text: cstring = "Window is too small"
	position := w / 2 - i32(rl.MeasureText(text, 13)) / 2
	rl.DrawText(text, position, h / 2, 13, rl.GRAY)
    } else {
	for i in 0..<field_height {
	    for j in 0..<field_width {
		jx := startx + (rwidth + 5) * j
		iy := starty +(rwidth + 5) * i
		color: rl.Color;
		switch field[i][j] {
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

    field_width: i32 = 11
    field_height: i32 = 11
    speed := 10
    field: Field
    snake: Snake
    PrepareField(field_width, field_height, &field, &snake)
    
    direction := Direction.Right
    last_direction: Direction;
    count := 0
    res: State = State.Menu
    choice := 0
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(BG)

	#partial switch res {
	case State.Menu:
	    res = Menu(rl.GetScreenWidth(), rl.GetScreenHeight(), field_width, field_height, &choice, &field, &snake)
	case State.GameOver: 
	    res = Lose(rl.GetScreenWidth(), rl.GetScreenHeight(), snake)
	case State.Settings:
	    res = Settings(rl.GetScreenWidth(), rl.GetScreenHeight(), &field_width, &field_height, &choice)
	case State.None: 
	    DrawField(rl.GetScreenWidth(), rl.GetScreenHeight(), 20, field_width, field_height, field, snake)
	    if count == speed {
		res = MovePlayer(direction, &snake, &field)
		if res == State.WrongDirection {
		    direction = last_direction
		    res = State.None
		    continue
		}
		last_direction = direction
		count = 0
	    }
	    
	    switch {
	    case rl.IsKeyDown(rl.KeyboardKey.UP):
		direction = Direction.Up
	    case rl.IsKeyDown(rl.KeyboardKey.DOWN):
		direction = Direction.Down
	    case rl.IsKeyDown(rl.KeyboardKey.LEFT):
		direction = Direction.Left
	    case rl.IsKeyDown(rl.KeyboardKey.RIGHT):
		direction = Direction.Right
	    }
	    count += 1
	}
	
        rl.EndDrawing()
    }

    rl.CloseWindow()
}

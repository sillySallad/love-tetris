function love.conf(t)
	t.window.width = 24 * 8 * 4
	t.window.height = 24 * 8 * 4
	t.identity = "Tetris"
	t.window.title = "Tetris"

	t.modules.graphics = true
	t.modules.window = true
	t.modules.image = true
	t.modules.math = true
	t.modules.timer = true
	t.modules.event = true
	t.modules.font = true

	t.modules.keyboard = false
	t.modules.audio = false
	t.modules.data = false
	t.modules.joystick = false
	t.modules.mouse = false
	t.modules.physics = false
	t.modules.sound = false
	t.modules.system = false
	t.modules.thread = false
	t.modules.touch = false
	t.modules.video = false
end


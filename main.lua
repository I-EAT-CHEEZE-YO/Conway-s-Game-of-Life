local Class = require('30log')

-- Visual flare: how fast an alive cell warms up, and how fast its trail fades.
local HEAT_RISE = 0.35
local HEAT_DECAY = 0.6
local HEAT_CUTOFF = 0.02

-- How many generations one frame may catch up on after a stall.
local MAX_CATCHUP = 4

Button = Class("Button")

function Button:init(x, y, w, h, text)
	self.x = x
	self.y = y
	self.width = w
	self.height = h
	self.text = text or "button"
	self.font = love.graphics.newFont('assets/fonts/VT323.ttf', 22)
	self.color = {0.5, 0.5, 0.5, 1}
	self.borderColor = {0.12, 0.12, 0.12, 1}
	self.textColor = {0, 0, 0, 1}
end

function Button:draw()
	love.graphics.setColor(self.color)
	love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
	love.graphics.setColor(self.borderColor)
	love.graphics.rectangle('line', self.x + 2, self.y + 2, self.width - 4, self.height - 4)
	love.graphics.setColor(self.textColor)
	love.graphics.setFont(self.font)
	love.graphics.printf(self.text, self.x, self.y + self.height / 2 - 12, self.width, 'center')
end

function love.load()
	math.randomseed(os.time())
	love.graphics.setBackgroundColor(0.08, 0.08, 0.08, 1)

	screen = {}
	screen.width = love.graphics.getWidth()
	screen.height = love.graphics.getHeight()

	love.mouse.setPosition(screen.width/2, screen.height/2 + 125)

	game = {}
	game.showHints = true
	game.dragging = false
	game.running = false
	game.state = 'menu'
	game.time = 0
	-- Simulation speed: generations per second, picked from this ladder.
	game.speeds = {1, 2, 3, 5, 8, 10, 15, 20, 30, 45, 60, 90, 120}
	game.speedIndex = 6
	game.gps = game.speeds[game.speedIndex]
	game.generations = 0
	game.chance = 0.45

	mainMenu = {}
	mainMenu.titleFont = love.graphics.newFont('assets/fonts/VT323.ttf', 64)
	mainMenu.smallFont = love.graphics.newFont('assets/fonts/VT323.ttf', 22)
	mainMenu.title = "Conway's Game of Life"
	mainMenu.titleColor = {0.266, 0.537, 0.101, 1}
	mainMenu.logo = love.graphics.newImage('assets/images/logo.png')
	mainMenu.logoWidth = mainMenu.logo:getWidth()
	mainMenu.logoHeight = mainMenu.logo:getHeight()


	menuButton = Button:new(screen.width / 2 - 132 / 2, screen.height - 386, 132, 42, "Main Menu")
	exitButton = Button:new(screen.width / 2 - 132 / 2, screen.height - 342, 132, 42, "Quit")

	button = {
		emptyButton = Button:new(screen.width / 2 - 132 / 2, screen.height / 2 + 100, 132, 42, "Empty Grid"),
		randomButton = Button:new(screen.width / 2 - 132 / 2, screen.height / 2 + 145, 132, 42, "Random Grid"),
		quitButton = Button:new(screen.width / 2 - 132 / 2, screen.height / 2 + 189, 132, 42, "Quit")
	}

	function button:draw()
		button.emptyButton:draw()
		button.randomButton:draw()
		button.quitButton:draw()
	end

	function mainMenu:draw()
		love.graphics.setBackgroundColor(0.36, 0.37, 0.43, 1)
		love.graphics.setFont(mainMenu.titleFont)
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.printf(mainMenu.title, 5, 36, screen.width, 'center')
		love.graphics.setColor(mainMenu.titleColor)
		love.graphics.printf(mainMenu.title, 0, 32, screen.width, 'center')
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.draw(mainMenu.logo, screen.width / 2 - mainMenu.logoWidth / 2 + 5, 182)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(mainMenu.logo, screen.width / 2 - mainMenu.logoWidth / 2, 175)
		love.graphics.setFont(mainMenu.smallFont)
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.print("Created By I_EAT_CHEEZE_YO ", screen.width - 240, screen.height - 25)
		love.graphics.setColor(1, 1, 1, 1)
	end

	cell = {width = 8, height = 8}
	cell.aliveColor = {0.266, 0.537, 0.101, 1}
	cell.deadColor = {0.11, 0.12, 0.14, 1}

	grid = {}
	grid.showGrid = false
	-- The world is this many viewports wide and tall; the camera pans across it
	-- and grid:draw only paints the cells the viewport can see.
	grid.worldWidth = 2
	grid.worldHeight = 2
	grid.viewWidth = math.floor(screen.width / cell.width)
	grid.viewHeight = math.floor(screen.height / cell.height)
	-- The loops below run 0..width inclusive, so the field is (width + 1) cells.
	grid.width = grid.viewWidth * grid.worldWidth - 1
	grid.height = grid.viewHeight * grid.worldHeight - 1
	grid.data = {}
	grid.heat = {}

	camera = {x = 0, y = 0}
	camera.maxX = math.max((grid.width + 1) * cell.width - screen.width, 0)
	camera.maxY = math.max((grid.height + 1) * cell.height - screen.height, 0)

	-- Palette and pre-rendered sprites for the glow/bloom look.
	visuals = {}
	visuals.birth = {0.85, 1, 0.7}
	visuals.trail = {0.12, 0.34, 0.07}
	visuals.glowColor = {0.35, 0.8, 0.25}

	local function makeRadialSprite(w, h, alphaAt)
		local data = love.image.newImageData(w, h)
		for py = 0, h - 1 do
			for px = 0, w - 1 do
				local dx = (px + 0.5) / w * 2 - 1
				local dy = (py + 0.5) / h * 2 - 1
				local d = math.min(math.sqrt(dx * dx + dy * dy), 1)
				data:setPixel(px, py, 1, 1, 1, alphaAt(d))
			end
		end
		local image = love.graphics.newImage(data)
		image:setFilter('linear', 'linear')
		return image
	end

	visuals.glow = makeRadialSprite(32, 32, function(d) return (1 - d) ^ 2 end)
	local glowSpan = cell.width * 2.6
	visuals.glowScale = glowSpan / visuals.glow:getWidth()
	visuals.glowPad = (glowSpan - cell.width) / 2
	visuals.vignette = makeRadialSprite(40, 24, function(d) return math.min(d * d * 1.6, 0.7) end)

	function grid:generateEmpty()
		for x = -1, grid.width + 1 do
			grid.data[x] = {}
			grid.heat[x] = {}
			for y = -1, grid.height + 1 do
				grid.data[x][y] = 0
				grid.heat[x][y] = 0
			end
		end

		for x = -1, grid.width + 1 do
			grid.data[x][-1] = 0
			grid.data[x][grid.height+1] = 0
		end
		for y = -1, grid.height + 1 do
			grid.data[-1][y] = 0
			grid.data[grid.width+1][y] = 0
		end


	end

	function grid:generateRandom(chance)
		local r = math.random()
		for x = -1, grid.width + 1 do
			grid.data[x] = {}
			grid.heat[x] = {}
			for y = -1, grid.height + 1 do
				grid.heat[x][y] = 0
				if r >= chance then
					grid.data[x][y] = 1
					r = math.random()
				else
					grid.data[x][y] = 0
					r = math.random()
				end
			end
		end

		for x = -1, grid.width + 1 do
			grid.data[x][-1] = 0
			grid.data[x][grid.height+1] = 0
		end
		for y = -1, grid.height + 1 do
			grid.data[-1][y] = 0
			grid.data[grid.width+1][y] = 0
		end

	end

	-- Conway's rules, indexed by live neighbour count.
	SURVIVE = {[2] = true, [3] = true}
	BIRTH = {[3] = true}

	function neighbors(x, y)
		local n = 0
		if grid.data[x-1][y-1] == 1 then n = n + 1 end --TOP LEFT
		if grid.data[x][y-1] == 1 then n = n + 1 end --TOP CENTER
		if grid.data[x+1][y-1] == 1 then n = n + 1 end --TOP RIGHT
		if grid.data[x-1][y] == 1 then n = n + 1 end --LEFT
		if grid.data[x+1][y] == 1 then n = n + 1 end --RIGHT
		if grid.data[x-1][y+1] == 1 then n = n + 1 end --BOTTOM LEFT
		if grid.data[x][y+1] == 1 then n = n + 1 end --BOTTOM CENTER
		if grid.data[x+1][y+1] == 1 then n = n + 1 end --BOTTOM RIGHT
		return n
	end

	function grid:draw()
		-- Cull to the cells the viewport can actually see.
		local x0 = math.max(math.floor(camera.x / cell.width), 0)
		local y0 = math.max(math.floor(camera.y / cell.height), 0)
		local x1 = math.min(math.floor((camera.x + screen.width - 1) / cell.width), grid.width)
		local y1 = math.min(math.floor((camera.y + screen.height - 1) / cell.height), grid.height)

		-- Additive halo behind the cells that have been alive for a while.
		love.graphics.setBlendMode('add')
		for x = x0, x1 do
			local px = x * cell.width - camera.x
			for y = y0, y1 do
				local heat = grid.heat[x][y] or 0
				if heat > 0.5 and grid.data[x][y] == 1 then
					local a = (heat - 0.5) * 2 * 0.5
					love.graphics.setColor(visuals.glowColor[1] * a, visuals.glowColor[2] * a, visuals.glowColor[3] * a, 1)
					love.graphics.draw(visuals.glow, px - visuals.glowPad, y * cell.height - camera.y - visuals.glowPad, 0, visuals.glowScale, visuals.glowScale)
				end
			end
		end
		love.graphics.setBlendMode('alpha')

		for x = x0, x1 do
			local px = x * cell.width - camera.x
			for y = y0, y1 do
				local py = y * cell.height - camera.y
				local heat = grid.heat[x][y] or 0
				if grid.data[x][y] == 0 then
					-- Dead cells fade their trail back into the dark.
					love.graphics.setColor(
						cell.deadColor[1] + (visuals.trail[1] - cell.deadColor[1]) * heat,
						cell.deadColor[2] + (visuals.trail[2] - cell.deadColor[2]) * heat,
						cell.deadColor[3] + (visuals.trail[3] - cell.deadColor[3]) * heat, 1)
				else
					-- Newborn cells flash bright and settle into the base green.
					love.graphics.setColor(
						visuals.birth[1] + (cell.aliveColor[1] - visuals.birth[1]) * heat,
						visuals.birth[2] + (cell.aliveColor[2] - visuals.birth[2]) * heat,
						visuals.birth[3] + (cell.aliveColor[3] - visuals.birth[3]) * heat, 1)
				end
				love.graphics.rectangle('fill', px, py, cell.width, cell.height)
				if grid.showGrid == true then
					love.graphics.setColor(0, 0, 0, 0.35)
					love.graphics.rectangle('line', px, py, cell.width, cell.height)
				end
			end
		end
	end

	function stepSimulation()
		game.generations = game.generations + 1
		local temp = {}
		temp.data = {}
		for x = -1, grid.width + 1 do
			temp.data[x] = {}
			for y = -1, grid.height + 1 do
				temp.data[x][y] = grid.data[x][y]
			end
		end

		for x = 0, grid.width do
			grid.data[x][-1] = grid.data[x][grid.height]
			grid.data[x][grid.height+1] = grid.data[x][0]
		end

		for y = 0, grid.height do
			grid.data[-1][y] = grid.data[grid.width][y]
			grid.data[grid.width+1][y] = grid.data[0][y]
		end

		-- The loops above wrap the edges but not the corners of the halo ring,
		-- which the corner cells read, so wrap those by hand.
		grid.data[-1][-1] = grid.data[grid.width][grid.height]
		grid.data[-1][grid.height+1] = grid.data[grid.width][0]
		grid.data[grid.width+1][-1] = grid.data[0][grid.height]
		grid.data[grid.width+1][grid.height+1] = grid.data[0][0]

		for x = 0, grid.width do
			for y = 0, grid.height do
				local n = neighbors(x, y)
				if grid.data[x][y] == 1 then
					temp.data[x][y] = SURVIVE[n] and 1 or 0
				else
					temp.data[x][y] = BIRTH[n] and 1 or 0
				end

				-- Heat rises while a cell stays alive and decays once it dies, so
				-- births flash bright, established cells glow and deaths leave a trail.
				local heat = grid.heat[x][y] or 0
				if temp.data[x][y] == 1 then
					heat = math.min(heat + HEAT_RISE, 1)
				else
					heat = heat * HEAT_DECAY
					if heat < HEAT_CUTOFF then heat = 0 end
				end
				grid.heat[x][y] = heat
			end
		end
		grid.data = {}
		grid.data = temp.data
		temp.data = {}
	end

	function game:drawDebug()
		love.graphics.setColor(1, 1, 1, 0.25)
		love.graphics.rectangle('fill', 0, 0, screen.width, screen.height)
		love.graphics.setColor(0.2, 0.2, 0.2, 1)
		love.graphics.rectangle('line', 0, 0, screen.width, screen.height)
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.printf("FPS : " .. love.timer.getFPS(), 0, 3, screen.width, 'center')
		love.graphics.printf("Generation : " .. game.generations, 0, 16, screen.width, 'center')
		love.graphics.printf("MX["..math.floor((love.mouse.getX() + camera.x)/cell.width).."]["..math.floor((love.mouse.getY() + camera.y)/cell.height).."]", 0, 32, screen.width, 'center')
	
		love.graphics.printf('Press [ / ] To Slow Down / Speed Up The Simulation', 0, screen.height - 220, screen.width, 'center')
		love.graphics.printf('Press Space To Start/Pause The Simulation', 0, screen.height - 200, screen.width, 'center')
		love.graphics.printf('Press Enter To Step 1 Generation While Simulation is Paused', 0, screen.height - 180, screen.width, 'center')
		love.graphics.printf('Press Escape To Open/Close This Screen', 0, screen.height - 160, screen.width, 'center')
		love.graphics.printf('Press G to Toggle Grid Lines (Drops FPS)', 0, screen.height - 140, screen.width, 'center')
		love.graphics.printf('Press R to Generate Random Data', 0, screen.height - 120, screen.width, 'center')
		love.graphics.printf('Press E to Clear The Grid', 0, screen.height - 100, screen.width, 'center')
		love.graphics.printf('Left Click to Draw Cells, Right Click to Remove Cells (While Paused)', 0, screen.height - 80, screen.width, 'center')
		love.graphics.printf('Middle Click and Drag to Pan The Canvas', 0, screen.height - 60, screen.width, 'center')
		love.graphics.printf('Mouse Wheel to Scroll The Canvas', 0, screen.height - 40, screen.width, 'center')

		menuButton:draw()
		exitButton:draw()
	end

	-- Always-visible readout of whether the sim is running and how fast.
	function game:drawHud()
		local status = game.running and "RUNNING" or "PAUSED"
		local color = game.running and {0.266, 0.537, 0.101, 1} or {0.9, 0.6, 0.15, 1}
		local text = status .. "   " .. game.gps .. " gen/s"
		love.graphics.setFont(mainMenu.smallFont)
		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.print(text, 13, 11)
		love.graphics.setColor(color)
		love.graphics.print(text, 12, 10)
	end
end

function love.update(dt)
	local mouse = {x = love.mouse.getX(), y = love.mouse.getY(), pressed = love.mouse.isDown(1), delete = love.mouse.isDown(2)}
	if game.state == 'menu' then
		if mouse.x > button.emptyButton.x and mouse.x < button.emptyButton.x + button.emptyButton.width and mouse.y > button.emptyButton.y and mouse.y < button.emptyButton.y + button.emptyButton.height then
			button.emptyButton.borderColor = {0, 0.245, 0, 1}
			button.emptyButton.color = {0.266, 0.537, 0.101, 1}
			if mouse.pressed then
				grid:generateEmpty()
				game.state = 'simulate'
			end
		else
			button.emptyButton.borderColor = {0.12, 0.12, 0.12, 1}
			button.emptyButton.color = {0.5, 0.5, 0.5, 1}
		end

		if mouse.x > button.randomButton.x and mouse.x < button.randomButton.x + button.randomButton.width and mouse.y > button.randomButton.y and mouse.y < button.randomButton.y + button.randomButton.height then
			button.randomButton.borderColor = {0, 0.245, 0, 1}
			button.randomButton.color = {0.266, 0.537, 0.101, 1}
			if mouse.pressed then
				grid:generateRandom(game.chance)
				game.state = 'simulate'
			end
		else
			button.randomButton.borderColor = {0.12, 0.12, 0.12, 1}
			button.randomButton.color = {0.5, 0.5, 0.5, 1}
		end

		if mouse.x > button.quitButton.x and mouse.x < button.quitButton.x + button.quitButton.width and mouse.y > button.quitButton.y and mouse.y < button.quitButton.y + button.quitButton.height then
			button.quitButton.borderColor = {0, 0.245, 0, 1}
			button.quitButton.color = {0.266, 0.537, 0.101, 1}
			if mouse.pressed then
				love.event.push('quit')
			end
		else
			button.quitButton.borderColor = {0.12, 0.12, 0.12, 1}
			button.quitButton.color = {0.5, 0.5, 0.5, 1}
		end
	elseif game.state == 'simulate' then
		if game.running then
			local interval = 1 / game.gps
			-- Cap the backlog so a stalled frame or a window drag can't burn
			-- through hundreds of generations in one go.
			game.time = math.min(game.time + dt, interval * MAX_CATCHUP)
			while game.time >= interval do
				stepSimulation()
				game.time = game.time - interval
			end
		end
		if game.showHints then
			if mouse.x > menuButton.x and mouse.x < menuButton.x + menuButton.width and mouse.y > menuButton.y and mouse.y < menuButton.y + menuButton.height then
				menuButton.borderColor = {0, 0.245, 0, 1}
				menuButton.color = {0.266, 0.537, 0.101, 1}
				if mouse.pressed then
					love.mouse.setPosition(screen.width/2, screen.height/2)
					game.state = 'menu'
				end
			else
				menuButton.borderColor = {0.12, 0.12, 0.12, 1}
				menuButton.color = {0.5, 0.5, 0.5, 1}
			end
			if mouse.x > exitButton.x and mouse.x < exitButton.x + exitButton.width and mouse.y > exitButton.y and mouse.y < exitButton.y + exitButton.height then
				exitButton.borderColor = {0, 0.245, 0, 1}
				exitButton.color = {0.266, 0.537, 0.101, 1}
				if mouse.pressed then
					love.event.push('quit')
				end
			else
				exitButton.borderColor = {0.12, 0.12, 0.12, 1}
				exitButton.color = {0.5, 0.5, 0.5, 1}
			end
		elseif not game.running then
			-- Painting is only allowed while the simulation is paused and the
			-- hints panel is closed, so clicks can't paint under its buttons.
			local gx = math.min(math.max(math.floor((mouse.x + camera.x) / cell.width), 0), grid.width)
			local gy = math.min(math.max(math.floor((mouse.y + camera.y) / cell.height), 0), grid.height)
			if mouse.pressed then
				grid.data[gx][gy] = 1
				grid.heat[gx][gy] = 1
			elseif mouse.delete then
				grid.data[gx][gy] = 0
				grid.heat[gx][gy] = 0
			end
		end
	end
end

function love.draw()
	if game.state == 'menu' then
		mainMenu:draw()
		button:draw()
	elseif game.state == 'simulate' then
		grid:draw()
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.draw(visuals.vignette, 0, 0, 0, screen.width / visuals.vignette:getWidth(), screen.height / visuals.vignette:getHeight())
		game:drawHud()
		if game.showHints then
			game:drawDebug(screen.width / 2 - 300 / 2, 0)
		end
	end
end

function love.keypressed(key)
	if key == 'escape' then
		game.showHints = not game.showHints
	elseif key == 'space' then
		if game.running == true then
			game.running = false
		else
			game.running = true
		end
	elseif key == 'return' then
		if game.running == false then
			stepSimulation()
		end
	elseif key == 'r' then
		game.generations = 0
		grid:generateRandom(game.chance)
	elseif key == 'e' then
		game.generations = 0
		grid:generateEmpty()
	elseif key == 'g' then
		if grid.showGrid == true then
			grid.showGrid = false
		else
			grid.showGrid = true
		end
	elseif key == '[' or key == ']' then
		game.speedIndex = math.min(math.max(game.speedIndex + (key == ']' and 1 or -1), 1), #game.speeds)
		game.gps = game.speeds[game.speedIndex]
	end
end

local SCROLL_STEP = 3 -- cells panned per wheel notch

local function panBy(dx, dy)
	camera.x = math.min(math.max(camera.x + dx, 0), camera.maxX)
	camera.y = math.min(math.max(camera.y + dy, 0), camera.maxY)
end

function love.wheelmoved(dx, dy)
	if game.state ~= 'simulate' then return end
	panBy(-dx * SCROLL_STEP * cell.width, -dy * SCROLL_STEP * cell.height)
end

function love.mousepressed(x, y, button)
	if button == 3 then
		game.dragging = true
	end
end

function love.mousemoved(x, y, dx, dy)
	if game.dragging then
		panBy(-dx, -dy)
	end
end

function love.mousereleased(x, y, button)
	if button == 3 then
		game.dragging = false
	end
end
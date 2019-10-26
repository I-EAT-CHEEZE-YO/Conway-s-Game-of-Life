local Class = require('30log')

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
	game.debug = true
	game.running = false
	game.state = 'menu'
	game.time = 0
	game.simulationTime = 0.02
	game.generations = 0
	game.chance = 0.45

	mainMenu = {}
	mainMenu.titleFont = love.graphics.newFont('assets/fonts/VT323.ttf', 64)
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
		love.graphics.setNewFont('assets/fonts/VT323.ttf', 22)
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.print("Created By I_EAT_CHEEZE_YO ", screen.width - 240, screen.height - 25)
		love.graphics.setColor(1, 1, 1, 1)
	end

	cell = {width = 8, height = 8}
	cell.aliveColor = {0.266, 0.537, 0.101, 1}
	cell.deadColor = {0.2, 0.2, 0.2, 1}

	grid = {}
	grid.showGrid = false
	grid.width = screen.width / cell.width
	grid.height = screen.height / cell.height
	grid.data = {}

	function grid:generateEmpty()
		for x = -1, grid.width + 1 do
			grid.data[x] = {}
			for y = -1, grid.height + 1 do
				grid.data[x][y] = 0
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
			for y = -1, grid.height + 1 do
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
		for x = 0, grid.width do
			for y = 0, grid.height do
				if grid.data[x][y] == 0 then
					love.graphics.setColor(cell.deadColor)
					love.graphics.rectangle('fill', x * cell.width, y * cell.height, cell.width, cell.height)
					if grid.showGrid == true then
						love.graphics.setColor(0, 0, 0, 1)
						love.graphics.rectangle('line', x * cell.width, y * cell.height, cell.width, cell.height)
					end
				elseif grid.data[x][y] == 1 then
					love.graphics.setColor(cell.aliveColor)
					love.graphics.rectangle('fill', x * cell.width, y * cell.height, cell.width, cell.height)
					if grid.showGrid == true then
						love.graphics.setColor(0, 0, 0, 1)
						love.graphics.rectangle('line', x * cell.width, y * cell.height, cell.width, cell.height)
					end
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

		for x = 0, grid.width do
			for y = 0, grid.height do
				if grid.data[x][y] == 1 then
					if neighbors(x, y) < 2 then
						temp.data[x][y] = 0
					end
					if neighbors(x, y) == 2 or neighbors(x, y) == 3 then
						temp.data[x][y] = 1
					end
					if neighbors(x, y) > 3 then
						temp.data[x][y] = 0
					end
				elseif grid.data[x][y] == 0 then
					if neighbors(x, y) == 3 then
						temp.data[x][y] = 1
					end
				end
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
		love.graphics.printf("MX["..math.floor(love.mouse.getX()/cell.width).."]["..math.floor(love.mouse.getY()/cell.height).."]", 0, 32, screen.width, 'center')
	
		love.graphics.printf('Press Space To Start/Pause The Simulation', 0, screen.height - 200, screen.width, 'center')
		love.graphics.printf('Press Enter To Step 1 Generation While Simulation is Paused', 0, screen.height - 180, screen.width, 'center')
		love.graphics.printf('Press Escape To Open/Close This Screen', 0, screen.height - 160, screen.width, 'center')
		love.graphics.printf('Press G to Toggle Grid Lines (Drops FPS)', 0, screen.height - 140, screen.width, 'center')
		love.graphics.printf('Press R to Generate Random Data', 0, screen.height - 120, screen.width, 'center')
		love.graphics.printf('Press E to Clear The Grid', 0, screen.height - 100, screen.width, 'center')
		love.graphics.printf('Left Click to Draw Cells, Right Click to Remove Cells', 0, screen.height - 80, screen.width, 'center')

		menuButton:draw()
		exitButton:draw()
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
			game.time = game.time + 0.2 * dt
			if game.time > game.simulationTime then
				stepSimulation()
				game.time = 0
			end
		end
		if game.debug then
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
		else
			if mouse.pressed then
				grid.data[math.floor(mouse.x/cell.width)][math.floor(mouse.y/cell.height)] = 1
			elseif mouse.delete then
				grid.data[math.floor(mouse.x/cell.width)][math.floor(mouse.y/cell.height)] = 0
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
		if game.debug then
			game:drawDebug(screen.width / 2 - 300 / 2, 0)
		end
	end
end

function love.keypressed(key)
	if key == 'escape' then
		if game.debug == true then
			game.debug = false
		else
			game.debug = true
		end
	elseif key == 'space' then
		if game.running == true then
			game.running = false
		else
			game.running = true
			game.debug = false
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
	end
end
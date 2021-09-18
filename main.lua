local lg = love.graphics
lg.setDefaultFilter("nearest","nearest")
lg.setFont(lg.newImageFont("font.png", "GAMEOVRHISCLNPUD 0123456789.-+"))
local tiles = require "tiles"
local bit32 = require "bit"
local band = bit32.band

local function sign(n) return n < 0 and -1 or 1 end

local function r(n) return love.math.random(1, n) end

local tileimage = lg.newImage("tiles.png")
local quads = {}
for y = 0, 7 do
	for x = 0, 15 do
		quads[y * 16 + x] = lg.newQuad(x * 4, y * 4, 4, 4, 64, 32)
	end
end

local bg = require "1155"
local background = lg.newCanvas(24*4, 24*4)
lg.setCanvas(background)
for y = 0, 23 do
	for x = 0, 23 do
		lg.draw(tileimage, quads[bg[y*24+x]], x*4, y*4)
	end
end
lg.setCanvas()

local loadedhiscore = tonumber(love.filesystem.read "hiscore.txt" or 0)

local icon = lg.newCanvas(64, 64)
lg.setCanvas(icon)
lg.draw(tileimage, quads[r(7) * 16], 0, 0, 0, 16, 16)
lg.setCanvas()
love.window.setIcon(icon:newImageData())

local w, h = 10, 18

local tilesize = 16

local m = {}

local function bound(x, y) return 0 <= x and x < w and 0 <= y and y < h end
local function mget(x, y) return m[y * w + x] end
local function mset(v, x, y) m[y * w + x] = v end

local function testpiecebottom(t, y)
	for i = 0, 3 do
		if y+tiles[t+i+4] < 0 then
			return false
		end
	end
	return true
end

local function testpiecetop(t, y)
	for i = 0, 3 do
		if y+tiles[t+i+4] >= h then
			return false
		end
	end
	return true
end

local function testpieceside(t, x)
	for i = 0, 3 do
		local x = x+tiles[t+i]
		if x < 0 or w <= x then
			return false
		end
	end
	return true
end

local function boundpiece(t, x, y) return testpiecetop(t, y) and testpieceside(t, x) and testpiecebottom(t, y) end

local function fitpiece(t, x, y)
	if not boundpiece(t, x, y) then
		return false
	end
	for i = 0, 3 do
		local x, y = x + tiles[t + i], y + tiles[t + i + 4]
		if mget(x, y) then
			return false
		end
	end
	return true
end

local function placepiece(t, x, y)
	for i = 0, 3 do
		local t, x, y = tiles[t + i + 8], x + tiles[t + i], y + tiles[t + i + 4]
		mset(t, x, y)
	end
end

local _initbag = {}
local _bag = {}

for i = 0, 4*7-1 do
	_initbag[i+1] = i * 12
end

local function takebag()
	local l = #_bag
	if l <= 0 then
		for k,v in pairs(_initbag) do
			_bag[k] = v
		end
	end
	return table.remove(_bag, r(#_bag))
end

local function drawtile(i, x, y)
	lg.draw(tileimage, quads[i], x * 4, (h - y - 1) * 4)
end

local function drawpiece(t, x, y)
	for i = 0, 3 do
		drawtile(tiles[t + i + 8], x + tiles[t + i], y + tiles[t + i + 4])
	end
end

local function mdraw()
	for k,v in pairs(m) do
		if v then
			local y = math.floor(k / w)
			local x = k - y * w
			drawtile(v, x, y)
		end
	end
end

local lowmask, highmask = -3, -9
local lines, score, hiscore = 0, 0, loadedhiscore

local spawnx = math.floor(w / 2)
local spawny = h + 3

local nextt
local tilet, tilex, tiley = 0, 0, 0
local _gameover, _pause = false, false

local time, timer = 0, .5

local function gameover()
	_gameover = true
	if score > hiscore then
		hiscore = score
	end
	time = math.huge
end

local function spawnpiece()
	if not nextt then nextt = takebag() end
	local t = nextt
	nextt = takebag()
	local x, y = spawnx, spawny
	while not boundpiece(t, x, y) and y > 0 do
		y = y - 1
	end
	tilet, tilex, tiley = t, x, y
	if not fitpiece(t, x, y) then
		placepiece(t, x, y)
		gameover()
	end
end

local basespeed = .5
local speedmult = .001
local fastspeed = 1

local function scorefunc(cleared) return cleared == 0 and 0 or (cleared * 2 - 1) * 100 end

local function clearlines()
	local cleared = 0
	local ry, wy = 0, 0
	for i = 1, h do
		local full = true
		for x = 0, w-1 do
			if not mget(x, ry) then
				full = false
				break
			end
		end
		if full then
			cleared = cleared + 1
			if ry > 0 then
				for x = 0, w-1 do
					local v = mget(x, ry-1)
					if v then
						mset(band(v, highmask), x, ry-1)
					end
				end
			end
			if ry < h-1 then
				for x = 0, w-1 do
					local v = mget(x, ry+1)
					if v then
						mset(band(v, lowmask), x, ry+1)
					end
				end
			end
		else
			if wy ~= ry then
				local f, t = ry * w, wy * w
				for x = 0, w-1 do
					m[t+x] = m[f+x]
				end
			end
			wy = wy + 1
		end
		ry = ry + 1
	end
	for y = h-cleared, h-1 do
		for x = 0, w-1 do
			mset(false, x, y)
		end
	end
	score = score + scorefunc(cleared)
	lines = lines + cleared
	timer = basespeed - speedmult * lines
end

local function update()
	local y = tiley - 1
	if fitpiece(tilet, tilex, y) then
		tiley = y
	else
		score = score + 10
		placepiece(tilet, tilex, tiley)
		spawnpiece()
	end
	clearlines()
end

function love.update(dt)
	if _pause then return end
	time = time - dt * fastspeed
	if time < 0 then
		time = time + timer
		update()
	end
end

function love.draw()
	lg.scale(8)
	lg.draw(background)
	lg.translate(12,12)
	mdraw()
	drawpiece(nextt, w + 4, h - 4)
	if not _gameover then
		drawpiece(tilet, tilex, tiley)
	end
	lg.scale(.5)
	lg.print("LINES", (w + 3) * 8, (7) * 8)
	lg.print("SCORE", (w + 3) * 8, (7 + 4) * 8)
	lg.print("HISCORE", (w + 2) * 8, (7 + 8) * 8)
	lg.printf(tostring(lines), (w + 1) * 8, (8) * 8, 7 * 8, "right")
	lg.printf(tostring(score), (w + 2) * 8, (8 + 4) * 8, 7 * 8, "right")
	lg.printf(tostring(hiscore), (w + 2) * 8, (8 + 8) * 8, 7 * 8, "right")
	if _gameover then
		lg.print("GAME OVER", w * 4 - 32, h * 4 - 8)
	end
	if _pause then
		lg.print("PAUSED", w * 4 - 24, h * 4 - 8)
	end
end

function love.keyreleased(key)
	if key == "down" then
		fastspeed = 1
	end
end

local function resetgame()
	_gameover = false
	m = {}
	score = 0
	lines = 0
	timer = basespeed
	time = timer
	nextt = false
	spawnpiece()
end
resetgame()

function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
		return
	end
	local t, x, y = tilet, tilex, tiley
	if not _pause then
		if key == "left" then
			if fitpiece(t, x - 1, y) then
				tilex = x - 1
			end
		elseif key == "right" then
			if fitpiece(t, x + 1, y) then
				tilex = x + 1
			end
		elseif key == "space" or key == "up" then
			if _gameover then
				resetgame()
			else
				t = math.floor(t / 12)
				t = math.floor(t / 4) * 4 + (t + 1) % 4
				t = t * 12
				while not testpiecetop(t, y) do
					y = y - 1
				end
				while not testpieceside(t, x) do
					x = x + sign(spawnx - x)
				end
				if fitpiece(t, x, y) then
					tilet, tilex, tiley = t, x, y
				end
			end
		elseif key == "down" then
			fastspeed = 8
		end
	end
	if key == "return"  or (_pause and key == "space") then
		_pause = not _pause
	end
end

function love.quit()
	local score = score > hiscore and score or hiscore
	if score > loadedhiscore then
		love.filesystem.write("hiscore.txt", tostring(score))
	end
end

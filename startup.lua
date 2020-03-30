_G.biosVersion = 1
_G.biosVersionString = "1.0"

--- Default Functions to ONLY use here

local fsopen = fs.open
local ioopen = io.open
local fsronly = fs.isReadOnly
local fsmv = fs.move
local fsexists = fs.exists
local fslist = fs.list
local fsdel = fs.delete

--- Restoreables (will be set on unlock to allow re-locking)
local LOCKfsopen = nil
local LOCKioopen = nil
local LOCKfsronly = nil
local LOCKfsmv = nil
local LOCKfsexists = nil
local LOCKfslist = nil
local LOCKfsdel = nil


--- Bios config Entries
local biosPassword = "0000"
local defaultBootEntry = 0
local bootEntries = "CRAFTOS,/startup_os,/disk/os,/disk/startup"

function BIOS.unlockRoot(passwd)
	if passwd == biosPassword then
		if LOCKfsdel == nil or LOCKioopen == nil or LOCKfsronly == nil or LOCKfsmv == nil or LOCKfsexists == nil or LOCKfslist == nil or LOCKfsopen == nil then
			LOCKfsopen = fs.open
			LOCKfslist = fs.list
			LOCKfsdel = fs.delete
			LOCKfsexists = fs.exists
			LOCKfsmv = fs.move
			LOCKioopen = io.open
			LOCKfsronly = io.isReadOnly
			fs.open = fsopen
			fs.list = fslist
			fs.delete = fsdel
			fs.exists = fsexists
			fs.move = fsmv
			io.open = ioopen
			fs.isReadOnly = fsronly
		else
			error("BIOS is already unlocked!", 2)
		end
	end
end

function BIOS.lockRoot()
	if LOCKfsdel == nil or LOCKioopen == nil or LOCKfsronly == nil or LOCKfsmv == nil or LOCKfsexists == nil or LOCKfslist == nil or LOCKfsopen == nil then
		error("BIOS is already locked!", 2)
	else
		fs.open = LOCKfsopen
		fs.list = LOCKfslist
		fs.delete = LOCKfsdel
		fs.exists = LOCKfsexists
		fs.move = LOCKfsmv
		io.open = LOCKioopen
		fs.isReadOnly = LOCKfsronly
		LOCKfsopen = nil
		LOCKfslist = nil
		LOCKfsdel = nil
		LOCKfsexists = nil
		LOCKfsmv = nil
		LOCKioopen = nil
		LOCKfsronly = nil
	end
end

--- Settings File API used to parse and interpret and save settings files. 
--- Entirely created by bwhodle
--- Forum post: http://www.computercraft.info/forums2/index.php?/topic/14311-preferences-settings-configuration-store-them-all-settings-file-api/
--- Modified to write to protected files
local function trimComments(line)
	local commentstart = string.len(line)
	for i = 1, string.len(line) do
		if string.byte(line, i) == string.byte(";") then
			commentstart = i - 1
			break
		end
	end
	return string.sub(line, 0, commentstart)
end

local function split(line)
	local equalssign = nil
	for i = 1, string.len(line) do
		if string.byte(line, i) == string.byte("=") or string.byte(line, i) == string.byte(":") then
			equalssign = i - 1
		end
	end
	if equalssign == nil then
		return nil, nil
	end
	return string.sub(line, 1, equalssign - 1), string.sub(line, equalssign + 2)
end

local function Trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function RemoveQuotes(s)
	if string.byte(s, 1) == string.byte("\"") and string.byte(s, string.len(s)) == string.byte("\"") then
		return string.sub(s, 2, -2)
	end
	return s
end

local function openSettingsFile(path)
	--print("Attempted to load settings file at "..path)
	local settings = {}
	local currentsection = {}
	local currentsectionname = nil
	local file = fsopen(path, "r")
	local lines = true
	settings["content"] = {}
	while lines do
		local currentline = file.readLine()
		if currentline == nil then
			lines = false
			break
		end
		currentline = trimComments(currentline)
		if Trim(currentline) ~= "" then
			if string.byte(currentline, 1) == string.byte("[") then
				if currentsectionname ~= nil then
					settings["content"][currentsectionname] = currentsection
					currentsection = {}
				elseif currentsectionname == nil then
					settings["content"][1] = currentsection
					currentsection = {}
				end
				currentsectionname = string.sub(currentline, 2, -2)
			else
				local key, value = split(currentline)
				if Trim(key) ~= nil and Trim(value) ~= nil then
					local x = Trim(value)
					if tonumber(x) then
						x = tonumber(x)
					else
						x = RemoveQuotes(x)
					end
					if x ~= nil and tostring(Trim(key)) ~= nil then
						currentsection[Trim(key)] = x
					end
				end
			end
		end
	end
	if currentsectionname ~= nil then
		settings["content"][currentsectionname] = currentsection
		currentsection = {}
	elseif currentsectionname == nil then
		settings["content"][1] = currentsection
		currentsection = {}
	end

	function settings.addSection(name)
		settings["content"][name] = {}
	end

	function settings.getValue(key)
		local x = settings["content"][1]
		return x[key]
	end

	function settings.getSectionedValue(section, key)
		return settings["content"][section][key]
	end

	function settings.setValue(key, value)
		settings["content"][1][key] = value
	end

	function settings.setSectionedValue(section, key, value)
		settings["content"][section][key] = value
	end

	function settings.save(path)
		local file = fsopen(path, "w")
		local d = settings["content"][1]
		if d ~= nil then
			for k, v in pairs(d) do
				local x = v
				if string.byte(v, 1) == string.byte(" ") or string.byte(v, string.len(v)) == string.byte(" ") then
					x = "\"" .. v .. "\""
				end
				file.writeLine(k .. " = " .. x)
			end
		end
		for k, v in pairs(settings["content"]) do
			if k ~= 1 then
				file.writeLine("")
				file.writeLine("[" .. k .. "]")
				for j, l in pairs(v) do
					local x = l
					if string.byte(l, 1) == string.byte(" ") or string.byte(l, string.len(l)) == string.byte(" ") then
						x = "\"" .. l .. "\""
					end
					file.writeLine(j .. " = " .. x)
				end
			end
		end
		file.close()
	end

	return settings
end

-------- Replacement of default calls and adding new ones
local function getAttribute(file, attr)
	local setfile = ""
	if file == nil or file == "" or attr == nil or attr == "" then
		return false
	end
	if fs.isDir(file) then
		setfile = file .. "/attrib.cfg"
	else
		setfile = file .. ".attrib.cfg"
	end
	if fsexists(setfile) and setfile ~= "" and fs.isDir(setfile) == false then
		local s = openSettingsFile(setfile)
		local att = s.getValue(attr, 0)
	else return false
	end
	if att == nil then return false end
	if att > 0 then return true
	else return false
	end
end

local function getAttribPath(file)
	local attribpath = ""
	if fs.isDir(file) then
		attribpath = file .. "/attrib.cfg"
	else
		attribpath = file .. ".attrib.cfg"
	end
	return attribpath
end

function setAttribute(file, attr, val)
	if file == nil or file == "" or attr == nil or attr == "" then
		return
	end
	local setfile = getAttribPath(file)
	if fsexists(setfile) == false then
		local file = fsopen(setfile, "w")
		file.close()
	end
	local s = openSettingsFile(setfile)
	local att = s.setValue(attr, val)
	s.save(setfile)
end

function fs.open(file, mode)
	if (fs.getName(file) == "startup" and fs.getDir(file) == "") then
		file = "startup_os"
	end
	if fs.isSystem(file) then return {} end
	return fsopen(file, mode)
end

function io.open(file, mode)
	if (fs.getName(file) == "startup" and fs.getDir(file) == "") then
		file = "startup_os"
	end
	if fs.isSystem(file) then return {} end
	return ioopen(file, mode)
end

function fs.isHidden(file)
	if getAttribute(file, "hidden") then return true end
	if fs.isSystem(file) then return true end
	return false
end

function fs.isSystem(file)
	if getAttribute(file, "system") then return true end
	if fs.getName(file) == "attrib.cfg" or string.find(file, ".attrib.cfg") or (fs.getName(file) == "startup" and fs.getDir(file) == "") or (fs.getName(file) == "bios.cfg" and fs.getDir(file) == "") then return true end
	if fs.getDir(file) ~= "" then
		return fs.isSystem(fs.getDir(file))
	end
	return false
end

function fs.list(dir)
	return fs.list(dir, false)
end

function fs.list(dir, showHidden)
	local rawlist = fslist(dir)
	local newlist = {}
	for k, v in pairs(rawlist) do
		if fs.isSystem(dir .. "/" .. v) == false or (showHidden and fs.isHidden(dir .. "/" .. v)) == false then
			table.insert(newlist, v)
		end
	end
	return newlist
end

function fs.isReadOnly(file)
	if (fs.getName(file) == "startup" and fs.getDir(file) == "") then
		file = "startup_os"
	end
	if fsronly(file) then
		return true
	else
		if getAttribute(file, "read-only") then return true end
	end
	if fs.isSystem(file) then return true end
	if fs.getDir(file) ~= "" then
		return fs.isReadOnly(fs.getDir(file))
	end
	return false
end

function fs.exists(file)
	if (fs.getName(file) == "startup" and fs.getDir(file) == "") then
		file = "startup_os"
	end
	if getAttribute(file, "system") or fs.getName(file) == "attrib.cfg" or (fs.getName(file) == "startup" and fs.getDir(file) == "") or string.find(file, ".attrib.cfg") then return false end
	return fsexists(file)
end

function fs.move(src, dst)
	if (fs.getName(src) == "startup" and fs.getDir(src) == "") then
		src = "startup_os"
	elseif (fs.getName(dst) == "startup" and fs.getDir(dst) == "") then
		src = "startup_os"
	end
	if fs.isReadOnly(src) then
		error("Source is read only", 2)
	end
	if fs.isReadOnly(dst) then
		error("Destination is read-only", 2)
	end
	fsmv(src, dst)
	if fsexists(getAttribPath(src)) then
		fsmv(getAttribPath(src), getAttribPath(dst))
	end
end

function fs.delete(file)
	if (fs.getName(file) == "startup" and fs.getDir(file) == "") then
		file = "startup_os"
	end
	if not fs.isReadOnly(file) then
		fsdel(file)
	end
end

function fs.download(url, file)
	local attempts = 0
	while attempts < 10 do
		local conn = http.get(url)
		if conn then
			local handler = io.open(file, "w")
			handler:write(conn.readAll())
			handler:close()
			return true
		else
			attempts = attempts + 1
		end
	end
end

local function fsdownload(url, file)
	local attempts = 0
	while attempts < 10 do
		local conn = http.get(url)
		if conn then
			local handler = ioopen(file, "w")
			handler:write(conn.readAll())
			handler:close()
			return true
		else
			attempts = attempts + 1
		end
	end
end

function shell.runURL(url)
	if (fsexists("/tmp")) then fsdel("/tmp") end
	fsdownload(url, "/tmp")
	fsdel("/tmp")
end




-- Util functions
function string.split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end





--- Boot script for configs and such

-- Prevent disk/startup being run on newer CC versions
local function preventDiskStartup()
	settings.set("shell.allow_disk_startup", false)
end


local function biosError(ms)
	term.setBackgroundColor(colors.blue)
	term.clear()

	term.setCursorPos(11, 5)
	term.setBackgroundColor(colors.white)
	term.setTextColor(colors.blue)
	print(" Looks like an Error occured...")
	term.setBackgroundColor(colors.blue)
	term.setTextColor(colors.white)
	term.setCursorPos(14, 8)
	print("For more information, see")
	term.setCursorPos(15, 9)
	print("the below error message")
	term.setCursorPos(5, 12)
	local s, msg = pcall(function()
		error(ms, 4)
	end)
	printError(msg)
	term.setCursorPos(13, 14)
	term.setBackgroundColor(colors.white)
	term.setTextColor(colors.blue)
	pcall(function()
		term.setCursorBlink(false)
		print(" Press any key to shutdown")
		os.pullEvent("key")
		os.shutdown()
	end)
end



--- On Boot
term.clear()
term.setCursorPos(1, 1)
pcall(preventDiskStartup)

-- Load BIOS Config or create new one
local isnew = false
if not fsexists("/bios.cfg") then
	local tmpfile = fsopen("/bios.cfg", "w")
	tmpfile.close()
end
if not fsexists("/bios.cfg") then
	biosError("Fatal Boot Error!\nCould not create new BIOS configuration")
end
local sett = openSettingsFile("/bios.cfg")

if not isnew then
	-- Check if config is older and update it if it is
	if sett.getValue("version") == nil or sett.getValue("version") < biosVersion then
		isnew = true
	end

	-- Load config
	if sett.getValue("bios-passwd") ~= nil then biosPassword = sett.getValue("bios-passwd") end
	if sett.getValue("default-boot-entry") ~= nil then defaultBootEntry = sett.getValue("default-boot-entry") end
	if sett.getValue("boot-entries") ~= nil then bootEntries = sett.getValue("boot-entries") end
end

--Write default or updated values to config
if isnew then
	sett.setValue("bios-passwd", biosPassword)
	sett.setValue("default-boot-entry", defaultBootEntry)
	sett.setValue("boot-entries", bootEntries)
	sett.setValue("version", biosVersion)
	sett.save("/bios.cfg")

	-- Load config again in case it was not already loaded
	biosPassword = sett.getValue("biosPasswd")
	defaultBootEntry = sett.getValue("default-boot-entry")
	bootEntries = sett.getValue("boot-entries")
end

-- Check if an update disk is inserted and run BIOS update if it does
if fsexists("/disk/bios.bin") then
	print("Update disk detected!")
	print("Enter BIOS password to install the update")
	write("> ")
	local pwd = io.read("*")
	if pwd == biosPassword then
		print("Installing update from disk. DO NOT REMOVE DISK!")
		BIOS.unlockRoot(pwd)
		fs.move("/disk/bios.bin", "/startup")
		fs.delete("/disk/startup")
		fs.delete(getAttribPath("/disk/bios.bin"))
		fs.move("/disk/startupOS", "/disk/startup")
		print("Installation successful, rebooting")
		BIOS.lockRoot()
		sleep(2)
		os.reboot()
	else
		print("Invalid Password.")
		sleep(2)
		os.reboot()
	end
	sleep(3)
end

local bootoptions = string.split(bootEntries, ",")
if defaultBootEntry > #bootoptions or defaultBootEntry < 0 then
	defaultBootEntry = 0
end
print("Boot options:")
for k, entry in pairs(bootoptions) do
	if i == defaultBootEntry then write("->") end
	print(entry)
end
sleep(5)
term.clear()
term.setCursorPos(1, 1)
if bootoptions[defaultBootEntry + 1] == "CRAFTOS" then
	shell.run("shell")
	sleep(4)
	biosError("OS did not shut down")
else
	if fs.exists(bootoptions[defaultBootEntry + 1]) then shell.run(bootoptions[defaultBootEntry + 1]) sleep(4) biosError("OS did not shut down") end
	for k, entry in pairs(bootoptions) do
		if k ~= defaultBootEntry + 1 then
			if entry == "CRAFTOS" then shell.run("shell") sleep(4) biosError("OS did not shut down") end
			if fs.exists(entry) then shell.run(entry) sleep(4) biosError("OS did not shut down") end
		end
	end
end
biosError("No bootable device/file found!")

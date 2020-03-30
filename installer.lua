local function download(url, file)
    local conn = http.get(url)
    local attempts = 0
    while attempts < 10 do
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

local function preventDiskStartup()
    settings.set("shell.allow_disk_startup", false)
end

term.clear()
term.setCursorPos(1, 1)
if biosVersion == nil then
    print("Installing BIOS...")
    pcall(preventDiskStartup)
    if fs.exists("/startup") then
        fs.move("/startup", "/startup_os")
    end
    if download("https://raw.githubusercontent.com/ErdbeerbaerLP/CC-Bios/master/startup.lua", "/startup") then
        print("Installation Finished!")
        print("Rebooting...")
        sleep(2)
        os.reboot()
    else
        error("Installation failed :/ Check your internet connection!")
    end
else
    print("Do you want to create an update disk? (Insert disk 0 into drive A)")
    write("y/n> ")
    local txt = io.read()
    if txt == "y" then
        if fs.exists("/disk") and fs.isDir("/disk") then
            if download("https://raw.githubusercontent.com/ErdbeerbaerLP/CC-Bios/master/startup.lua", "/disk/bios.bin") then
                setAttribute("/disk/bios.bin", "system", 1)
                local startupE = fs.exists("/disk/startup")
                if startupE then
                    fs.move("/disk/startup", "/disk/startupOS")
                end
                local f = fs.open("/disk/startup", "w")
                f.writeLine("shell.run(\"/startup\") -- For compatibility with older craftos versions")
                f.close()
            else
                print("Download failed...")
            end
        else
            print("No disk found! Exiting...")
        end
    else
    end
end
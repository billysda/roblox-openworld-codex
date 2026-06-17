local StationService = {}
StationService.__index = StationService
local HomeCfg = require(script.Parent:WaitForChild("HomeCfg"))
function StationService.new() return setmetatable({}, StationService) end
function StationService:EnsureStations(house)
	local f = house:FindFirstChild(HomeCfg.Names.Stations) or Instance.new("Folder")
	f.Name = HomeCfg.Names.Stations
	f.Parent = house
	for _, name in ipairs(HomeCfg.DefaultStations) do
		if not f:FindFirstChild(name) then
			local s = Instance.new("Folder")
			s.Name = name
			s.Parent = f
		end
	end
	return f
end
function StationService:GetStationSummary(house)
	local result = {}
	local f = house and house:FindFirstChild(HomeCfg.Names.Stations)
	for _, name in ipairs(HomeCfg.DefaultStations) do
		table.insert(result, { Name = name, Exists = f and f:FindFirstChild(name) ~= nil or false })
	end
	return result
end
return StationService

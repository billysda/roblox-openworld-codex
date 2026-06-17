task.delay(10, function()
    print("[DragonRaidTest] Buscando oveja para lanzar evento en 5 segundos...")
    local raid = require(game.ServerScriptService.Homestead.M.DragonRaidService)
    while not raid:FindValidSheepTarget() do
        task.wait(2)
    end
    print("[DragonRaidTest] Oveja encontrada. Iniciando Raid...")
    raid:StartDragonRaid()
end)
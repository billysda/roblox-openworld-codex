import sys
import os

repo_dir = r'E:\Games\clone\roblox-openworld-codex'
pasture_dir = os.path.join(repo_dir, 'snapshots', 'CodexAvanceTest_Current', 'ServerScriptService', 'Pasture')

with open(os.path.join(pasture_dir, 'M', 'Cfg.lua'), 'r', encoding='utf-8') as f:
    cfg_src = f.read()

with open(os.path.join(pasture_dir, 'M', 'GrazingService.lua'), 'r', encoding='utf-8') as f:
    grazing_src = f.read()

lua_code = f"""
local sss = game:GetService("ServerScriptService")
local pasture = sss:FindFirstChild("Pasture")
local M = pasture:FindFirstChild("M")

local cfg = M:FindFirstChild("Cfg")
local grazing = M:FindFirstChild("GrazingService")

cfg.Source = [==========[{cfg_src}]==========]
grazing.Source = [==========[{grazing_src}]==========]

return "Updated Studio Polish Successfully"
"""

with open('lua_update_polish.lua', 'w', encoding='utf-8') as f:
    f.write(lua_code)

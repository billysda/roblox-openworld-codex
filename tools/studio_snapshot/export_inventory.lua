-- Exportación de inventario Roblox Studio -> JSON (sin modificaciones en DataModel).
-- Uso: Antigravity ejecuta mediante Studio MCP execute_luau, en Edit, cambiando
-- SERVICE_NAME/START_INDEX/PAGE_LIMIT. Guardar cada respuesta en disco,
-- repetir hasta hasMore=false; repetir para los servicios de interés.
-- NO contiene ni exporta Source de scripts, secretos, DataStores ni datos de jugadores.

local SERVICE_NAME = "Workspace" -- "ReplicatedStorage", "ServerScriptService", etc.
local START_INDEX = 1          -- 1-based, inclusivo
local PAGE_LIMIT = 80          -- reducir si el transporte MCP trunca respuestas

local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local root = game:GetService(SERVICE_NAME)
local entries = {}
local totalNodes = 0
local captureErrors = {}

local function safe(fn)
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local function rounded(n)
    return math.floor(n * 10000 + (n >= 0 and 0.5 or -0.5)) / 10000
end

local function v3(v)
    return {rounded(v.X), rounded(v.Y), rounded(v.Z)}
end

local function cf(c)
    local vals = {c:GetComponents()}
    for i, n in ipairs(vals) do vals[i] = rounded(n) end
    return vals
end

local function encodeValue(value, depth)
    depth = depth or 0
    if depth > 6 then return "<depth-limit>" end
    local kind = typeof(value)
    if kind == "nil" then return nil end
    if kind == "string" then
        -- No exportar contenidos de StringValue ni otros valores potencialmente privados.
        return value
    end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return tostring(value)
        end
        return rounded(value)
    end
    if kind == "boolean" then return value end
    if kind == "Vector3" then return {type="Vector3",value=v3(value)} end
    if kind == "Vector2" then return {type="Vector2",value={rounded(value.X),rounded(value.Y)}} end
    if kind == "CFrame" then return {type="CFrame",value=cf(value)} end
    if kind == "Color3" then return {type="Color3",value={rounded(value.R),rounded(value.G),rounded(value.B)}} end
    if kind == "UDim" then return {type="UDim",value={rounded(value.Scale),value.Offset}} end
    if kind == "UDim2" then
        return {type="UDim2",value={rounded(value.X.Scale),value.X.Offset,rounded(value.Y.Scale),value.Y.Offset}}
    end
    if kind == "EnumItem" then return tostring(value) end
    if kind == "BrickColor" then return tostring(value) end
    if kind == "Instance" then
        return {type="InstanceRef",fullName=safe(function() return value:GetFullName() end)}
    end
    if kind == "NumberRange" then return {type="NumberRange",value={rounded(value.Min),rounded(value.Max)}} end
    if kind == "Rect" then return {type="Rect",value={rounded(value.Min.X),rounded(value.Min.Y),rounded(value.Max.X),rounded(value.Max.Y)}} end
    if kind == "table" then
        local output = {}
        for k,v in pairs(value) do
            if type(k) == "string" or type(k) == "number" then
                output[tostring(k)] = encodeValue(v, depth + 1)
            end
        end
        return output
    end
    return {type=kind,value=tostring(value)}
end

local function escapeSegment(name)
    return tostring(name):gsub("%%","%%25"):gsub("/","%%2F"):gsub("#","%%23"):gsub("\n","%%0A")
end

local PROPERTY_NAMES = {
    -- Instancias espaciales y físicas
    "CFrame", "Size", "Position", "Orientation", "Anchored",
    "CanCollide", "CanTouch", "CanQuery", "CollisionGroup",
    "Massless", "RootPriority", "Transparency", "LocalTransparencyModifier",
    "Color", "Material", "MaterialVariant", "Reflectance", "CastShadow",
    "Shape", "PivotOffset", "PrimaryPart", "WorldPivot",
    -- Assets e imágenes, sin copiar binarios
    "MeshId", "TextureID", "TextureId", "MeshType", "Scale", "Offset",
    "AnimationId", "SoundId", "Image", "Face", "Texture",
    -- Relación entre partes, constraints y attachments
    "Attachment0", "Attachment1", "Part0", "Part1", "Adornee",
    "Axis", "SecondaryAxis", "WorldCFrame", "Position0", "Position1",
    "Transform", "Enabled", "Disabled", "RelativeTo",
    -- Luces, GUI y algunos ajustes importantes
    "Brightness", "Range", "Angle", "Shadows",
    "FieldOfView", "CameraType", "CameraSubject",
    "Visible", "ZIndex", "BackgroundTransparency", "TextTransparency",
    "LightingStyle", "NameDisplayDistance", "HealthDisplayType",
}

local function makeRecord(instance, path, parentPath, siblingIndex, depth)
    local record = {
        path=path,
        parentPath=parentPath,
        siblingIndex=siblingIndex,
        depth=depth,
        name=instance.Name,
        className=instance.ClassName,
        fullName=safe(function() return instance:GetFullName() end),
        properties={},
        attributes={},
        tags={},
    }
    for _, prop in ipairs(PROPERTY_NAMES) do
        local value = safe(function() return instance[prop] end)
        if value ~= nil then
            record.properties[prop] = encodeValue(value)
        end
    end
    local attrs = safe(function() return instance:GetAttributes() end) or {}
    for key,value in pairs(attrs) do
        -- Evitar atributos con nombres sugestivos de secretos o datos personales.
        local lower = tostring(key):lower()
        if not lower:find("token") and not lower:find("secret")
            and not lower:find("password") and not lower:find("apikey")
            and not lower:find("userid") and not lower:find("email") then
            record.attributes[key] = encodeValue(value)
        end
    end
    record.tags = safe(function() return CollectionService:GetTags(instance) end) or {}
    table.sort(record.tags)
    if instance:IsA("LuaSourceContainer") then
        record.sourceExported = false
    end
    return record
end

local function visit(instance, path, parentPath, siblingIndex, depth)
    totalNodes += 1
    if totalNodes >= START_INDEX and totalNodes < START_INDEX + PAGE_LIMIT then
        local ok, result = pcall(makeRecord, instance, path, parentPath, siblingIndex, depth)
        if ok then
            table.insert(entries, result)
        else
            table.insert(captureErrors, {path=path,error=tostring(result)})
        end
    end
    local children = safe(function() return instance:GetChildren() end)
    if not children then
        table.insert(captureErrors, {path=path,error="GetChildren failed"})
        return
    end
    for i,child in ipairs(children) do
        local childPath = path .. "/" .. escapeSegment(child.Name) .. "#" .. tostring(i)
        visit(child, childPath, path, i, depth + 1)
    end
end

visit(root, escapeSegment(SERVICE_NAME).."#root", nil, 0, 0)

return HttpService:JSONEncode({
    schemaVersion=1,
    service=SERVICE_NAME,
    placeId=game.PlaceId,
    gameId=game.GameId,
    startIndex=START_INDEX,
    pageLimit=PAGE_LIMIT,
    totalNodes=totalNodes,
    nextStartIndex=START_INDEX + PAGE_LIMIT,
    hasMore=(START_INDEX + PAGE_LIMIT <= totalNodes),
    records=entries,
    captureErrors=captureErrors,
    caveats={
        "Snapshot estructural de instancias; no captura voxels Terrain, geometria ni Source.",
        "No demuestra contenido runtime en Play; exportar Play aparte.",
        "No mantener objetos mutando mientras se paginan resultados.",
        "Revisar datos y filtrado de privacidad antes de publicar a GitHub publico."
    }
})

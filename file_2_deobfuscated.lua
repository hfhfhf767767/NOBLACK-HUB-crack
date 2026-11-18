local NB_API = "https://bolt.0x00string.workers.dev"

local NB_ENV = ...
local NB_TOKEN = (type(NB_ENV) == "table" and NB_ENV.token) or getgenv().NB_TOKEN

if type(NB_TOKEN) ~= "string" or NB_TOKEN == "" then
    warn("[noblack] нет доступа")
    return
end

do
    local hs = game:GetService("HttpService")
    local rq = rawget(_G, "request") or request or rawget(_G, "http_request") or http_request or (syn and syn.request) or (http and http.request)
    local ok, res = pcall(function()
        if type(rq) ~= "function" then return nil end
        local r = rq({
            Url = NB_API .. "/verify",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json", Authorization = "Bearer " .. NB_TOKEN },
            Body = "{}",
        })
        return hs:JSONDecode(r.Body)
    end)
    if not (ok and res and res.ok == true) then
        warn("[noblack] доступ отклонён")
        return
    end
end

do
    local prev = getgenv().NB_HUB_UI
    local screen = type(prev) == "table" and prev.Screen
    if screen and screen.Parent and #screen:GetDescendants() > 0 then
        task.spawn(function()
            local opened = pcall(function() prev.Window:Open() end)
            if not opened then pcall(function() prev.Window:Toggle() end) end
        end)
        print("[noblack] hub already running - menu reopened")
        getgenv().NB_REUSED = true
        return
    end
end

local prevRun = getgenv().NB_RUN
if type(prevRun) == "table" then prevRun.alive = false end

if type(getgenv().NB_UNLOAD) == "function" then
    task.spawn(function() pcall(getgenv().NB_UNLOAD) end)
end

local RUN = { alive = true }
getgenv().NB_RUN = RUN

local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local VIM         = game:GetService("VirtualInputManager")
local Camera      = workspace.CurrentCamera
local player      = Players.LocalPlayer

pcall(function()
    local c = rawget(_G, "CPT")
    if c then
        c.auto = false
        c.autoIdx = nil
        c.autoArg2 = nil
        c.records = {}
        c.maxRec = 0
    end
    _G.CPT = nil
end)
pcall(function() restorefunction(game, "__namecall") end)

local S = {
    fastHits       = true,
    hitDelay       = 0, 

    antiRagdoll     = true,
    antiRagdollRate = 10,

    magnet      = true,
    magnetSize  = 100,
    magnetRange = 200,

    
    reachEnabled = true,
    reach        = 10, 

    
    noAnims          = false, 
    animSpeedEnabled = true,  
    animSpeed        = 5,     

    aimEnabled      = false,
    aimSmooth       = 0,
    aimBind         = Enum.KeyCode.R,
    aimPart         = "Head",
    teamCheck       = true,
    fovRadius       = 200,
    lockedTarget    = nil,

    
    blockAnimId = "124329027374810",
    blockDebug  = false,
    blockGuard  = true, 

    
    qAttack     = true,
    qInRotation = false, 
    qKey        = Enum.KeyCode.Q,
    qCooldown   = 0.25, 
    eAttack     = true, 
    eKey        = Enum.KeyCode.E,
    eCooldown   = 0.25,
    qHold       = 0.03, 
    qConfirm    = 0.15, 
    qMaxWait    = 1.20, 

    
    blockSnipe  = false, 
    blockGrace  = 0.08,  
    attackLead  = 0.15, 

    
    tpEnabled   = true,
    tpKey       = Enum.KeyCode.LeftControl, 
    tpButton    = Enum.UserInputType.MouseButton1,
    tpCooldown  = 0.20, 
    tpRaiseY    = 0,    

    
    speedFix         = true,
    speedNormal      = 16, 
    speedBoost       = 18, 
    speedSkipRagdoll = false, 
}

local FistRemote
pcall(function()
    local Packet = require(RS:WaitForChild("Packet", 10))
    FistRemote = Packet("FistRemote", "String", "Any", "Any", "Any", "Any", "Any")
end)

local FIST_ANIM_IDS = {}
do
    local known = {
        "122008594977996", 
        "108390712390287", 
        "92024825578627",  
        "119650753709805", 
        "119160927304691", 
        "138434473879558", 
        "124329027374810", 
        "103033879938569", 
        "131500781441036", 
        "135718907408051", 
    }
    for _, id in ipairs(known) do FIST_ANIM_IDS[id] = true end

    local rf = RS:FindFirstChild("FistAnims")
    if rf then
        for _, a in ipairs(rf:GetChildren()) do
            if a:IsA("Animation") then
                local id = tostring(a.AnimationId):match("%d+")
                if id then FIST_ANIM_IDS[id] = true end
            end
        end
    end
end

local kickEvent = { q = 0, e = 0, untilT = 0 }
local kickCd = { q = 0, e = 0 }
if FistRemote then
    FistRemote.OnClientEvent:Connect(function(action, a1, a2)
        local now = os.clock()
        if action == "bar" then
            local dur = tonumber(a2) or 0
            if dur > 0 then
                if a1 == "leftkick" then
                    kickCd.q = math.max(kickCd.q, now + dur)
                elseif a1 == "rightkick" then
                    kickCd.e = math.max(kickCd.e, now + dur)
                end
            end
            return
        end
        if action ~= "startray" then return end
        local dur = tonumber(a2) or 0.45
        if a1 == "Left Leg" then
            kickEvent.q = now
            kickEvent.untilT = math.max(kickEvent.untilT, now + dur + 0.05)
        elseif a1 == "Right Leg" then
            kickEvent.e = now
            kickEvent.untilT = math.max(kickEvent.untilT, now + dur + 0.05)
        end
    end)
end

local function hideFightAnim(track)
    if not S.noAnims then return end
    if not track or not track.IsPlaying then return end
    local anim = track.Animation
    if not anim then return end
    local id = tostring(anim.AnimationId):match("%d+")
    if id and FIST_ANIM_IDS[id] then
        pcall(function() track:Stop(0) end)
    end
end

local function bindNoAnims(char)
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
    if not animator then return end
    animator.AnimationPlayed:Connect(hideFightAnim)
end

player.CharacterAdded:Connect(function(char)
    task.spawn(bindNoAnims, char)
end)
if player.Character then task.spawn(bindNoAnims, player.Character) end

RunService.RenderStepped:Connect(function()
    if not RUN.alive then return end
    if not S.noAnims then return end
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
        if t.IsPlaying then
            local anim = t.Animation
            if anim then
                local id = tostring(anim.AnimationId):match("%d+")
                if id and FIST_ANIM_IDS[id] then
                    pcall(function() t:Stop(0) end)
                end
            end
        end
    end
end)

local FAST_ANIM_IDS = {
    ["122008594977996"] = true, 
    ["108390712390287"] = true, 
    ["92024825578627"]  = true, 
    ["119650753709805"] = true, 
    ["119160927304691"] = true, 
    ["138434473879558"] = true, 
    ["103033879938569"] = true, 
}

local function isFastAnim(track)
    local anim = track and track.Animation
    if not anim then return false end
    local id = tostring(anim.AnimationId):match("%d+")
    return id ~= nil and FAST_ANIM_IDS[id] == true
end

local function applyAnimSpeed(track)
    if not S.animSpeedEnabled then return end
    if not track or not track.IsPlaying then return end
    if not isFastAnim(track) then return end
    pcall(function() track:AdjustSpeed(S.animSpeed) end)
end

local function bindAnimSpeed(char)
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
    if not animator then return end

    animator.AnimationPlayed:Connect(function(track)
        task.delay(0.01, function() applyAnimSpeed(track) end)
    end)

    for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
        applyAnimSpeed(t)
    end
end

player.CharacterAdded:Connect(function(char)
    task.spawn(bindAnimSpeed, char)
end)
if player.Character then task.spawn(bindAnimSpeed, player.Character) end

task.spawn(function()
    while RUN.alive do
        if S.animSpeedEnabled and not S.noAnims then
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            local animator = hum and hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                    applyAnimSpeed(t)
                end
            end
        end
        task.wait(0.1)
    end
end)

local ARM_NAMES = {
    "Left Arm", "Right Arm",
    "LeftUpperArm", "RightUpperArm",
    "LeftLowerArm", "RightLowerArm",
}

local function ensureReach(arm)
    if not arm or not arm:IsA("BasePart") then return end
    local base = arm.Size.Y / 2
    for i = 1, 3 do
        local att
        for _, c in ipairs(arm:GetChildren()) do
            if c:IsA("Attachment") and c:GetAttribute("nbReach") == i then
                att = c
                break
            end
        end
        if not att then
            att = Instance.new("Attachment")
            att.Name = "DmgPoint" 
            att:SetAttribute("nbReach", i)
            att.Parent = arm
        end
        att.Position = Vector3.new(0, -(base + S.reach * i / 3), 0)
    end
end

local function refreshReach()
    if not S.reachEnabled then return end
    local char = player.Character
    if not char then return end
    for _, name in ipairs(ARM_NAMES) do
        local arm = char:FindFirstChild(name)
        if arm then ensureReach(arm) end
    end
end

player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    refreshReach()
end)
task.spawn(function()
    while RUN.alive do
        refreshReach()
        task.wait(1)
    end
end)

local Block = {
    range       = 20,
    closeRange  = 6,
    facing      = false, 
    facingAngle = 75,
    hold        = 0.38,  
    linger      = 0.15,  
    guardRange  = 16,    
    scan        = 0.05,
    stateCheck  = false,
    stateWords  = { "block", "guard", "shield", "parry", "defend" },
}

local blockUntil = {}
local stateCache = {}

local TARGET_ANIM = tostring(S.blockAnimId):match("%d+") or ""

local function numId(id)
    if not id then return "" end
    return tostring(id):match("%d+") or ""
end

local function isBlockTrack(track)
    if TARGET_ANIM == "" then return false end
    local anim = track and track.Animation
    if not anim then return false end
    return numId(anim.AnimationId):find(TARGET_ANIM, 1, true) ~= nil
end

local function animPlayingBlock(plr)
    local char = plr.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return false end
    for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
        if t.IsPlaying and isBlockTrack(t) then return true end
    end
    return false
end

local function markBlockStart(plr, track)
    local now = os.clock()
    local untilT = now + Block.hold

    local len = track and track.Length
    local spd = track and track.Speed
    if len and len > 0 then
        if not spd or spd <= 0 then spd = 1 end
        untilT = math.max(untilT, now + len / spd + Block.linger)
    end

    if (blockUntil[plr] or 0) < untilT then
        blockUntil[plr] = untilT
        if S.blockDebug then
            print(string.format("[block] %s start, hold %.2fs", plr.Name, untilT - now))
        end
    end
end

local function markBlockAlive(plr)
    local now = os.clock()
    local target = now + Block.linger
    if (blockUntil[plr] or 0) < target then
        blockUntil[plr] = target
    end
end

local function scanBlockState(plr)
    local char = plr.Character
    if not char then return false end

    local function hitName(n)
        n = tostring(n):lower()
        for _, w in ipairs(Block.stateWords) do
            if n:find(w, 1, true) then return true end
        end
        return false
    end

    for _, obj in ipairs(char:GetDescendants()) do
        if hitName(obj.Name) then
            if obj:IsA("BoolValue") then
                if obj.Value then return true end
            elseif obj:IsA("ObjectValue") then
                if obj.Value then return true end
            elseif obj:IsA("BasePart") and obj.Transparency < 1 then
                return true
            end
        end
    end

    for name, val in pairs(char:GetAttributes()) do
        if hitName(name) then
            if val == true then return true end
            if type(val) == "number" and val > 0 then return true end
        end
    end

    return false
end

local function blockStateCached(plr)
    if not Block.stateCheck then return false end
    local now = os.clock()
    local c = stateCache[plr]
    if c and (now - c.t) < 0.2 then return c.v end
    local v = scanBlockState(plr)
    stateCache[plr] = { t = now, v = v }
    return v
end

local function playerBlocking(plr)
    if (blockUntil[plr] or 0) > os.clock() then return true end
    if animPlayingBlock(plr) then
        markBlockAlive(plr)
        return true
    end
    if blockStateCached(plr) then
        markBlockAlive(plr)
        return true
    end
    return false
end

local function blockRemaining(plr)
    local char = plr.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
            if t.IsPlaying and isBlockTrack(t) then
                local spd = t.Speed or 1
                if spd <= 0 then spd = 1 end
                local len = t.Length or 0
                if t.Looped or len <= 0 then
                    return math.huge
                end
                return math.max((len - t.TimePosition) / spd, 0)
            end
        end
    end
    local untilT = blockUntil[plr] or 0
    return math.max(untilT - os.clock(), 0)
end

local function playerOfPart(part)
    local char = part and part.Parent
    if not char then return nil end
    return Players:GetPlayerFromCharacter(char)
end

local function validTarget(plr)
    if plr == player or not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function inFront(plr)
    if not Block.facing then return true end
    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local root   = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not (myRoot and root) then return true end

    local dir = root.Position - myRoot.Position
    if dir.Magnitude < 0.1 then return true end

    local look = myRoot.CFrame.LookVector
    return look:Dot(dir.Unit) >= math.cos(math.rad(Block.facingAngle))
end

local function getHitTarget()
    local aim = playerOfPart(S.lockedTarget)
    if aim and validTarget(aim) then
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local root   = aim.Character:FindFirstChild("HumanoidRootPart")
        if myRoot and root and (myRoot.Position - root.Position).Magnitude <= Block.range then
            return aim
        end
    end

    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if validTarget(p) then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (myRoot.Position - root.Position).Magnitude
                if d <= Block.range and (d <= Block.closeRange or inFront(p)) then
                    if d < bestD then bestD, best = d, p end
                end
            end
        end
    end
    return best
end

local function anyBlockerNear()
    if not S.blockGuard then return false end
    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        if validTarget(p) then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (myRoot.Position - root.Position).Magnitude
                if d <= Block.guardRange and playerBlocking(p) then
                    return true
                end
            end
        end
    end
    return false
end

local function getMagnetTarget()
    local aim = playerOfPart(S.lockedTarget)
    if aim and validTarget(aim) then
        return aim
    end

    local hit = getHitTarget()
    if hit then
        return hit
    end

    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local best, bestD = nil, S.magnetRange
    for _, p in ipairs(Players:GetPlayers()) do
        if validTarget(p) then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (myRoot.Position - root.Position).Magnitude
                if d <= bestD then
                    bestD, best = d, p
                end
            end
        end
    end
    return best
end

local function bindPlayer(plr)
    if plr == player then return end

    local function onTrack(track)
        if isBlockTrack(track) then
            markBlockStart(plr, track)
        end
    end

    local function bindChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
        if not animator then return end
        animator.AnimationPlayed:Connect(onTrack)
        
        for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
            if t.IsPlaying and isBlockTrack(t) then
                markBlockStart(plr, t)
            end
        end
    end

    if plr.Character then task.spawn(bindChar, plr.Character) end

    plr.CharacterAdded:Connect(function(char)
        blockUntil[plr] = nil
        stateCache[plr] = nil
        task.spawn(bindChar, char)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do bindPlayer(p) end
Players.PlayerAdded:Connect(bindPlayer)
Players.PlayerRemoving:Connect(function(p)
    blockUntil[p] = nil
    stateCache[p] = nil
end)

task.spawn(function()
    while RUN.alive do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and animPlayingBlock(p) then
                    markBlockAlive(p)
                end
            end
        end
        task.wait(Block.scan)
    end
end)

local lastQ = 0

local function pressKey(key)
    local ok = pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(S.qHold)
        VIM:SendKeyEvent(false, key, false, game)
    end)
    if ok then return true end

    
    local vk
    if key == Enum.KeyCode.Q then vk = 0x51
    elseif key == Enum.KeyCode.E then vk = 0x45
    else return false end
    local kp = rawget(_G, "keypress")
    local kr = rawget(_G, "keyrelease")
    if type(kp) == "function" then
        pcall(kp, vk)
        task.wait(S.qHold)
        if type(kr) == "function" then pcall(kr, vk) end
        return true
    end
    return false
end

local function qReady()
    return (os.clock() - lastQ) >= S.qCooldown and os.clock() >= kickCd.q
end

local function pressQ()
    if not S.qAttack or not qReady() then return false end
    lastQ = os.clock()
    if S.blockDebug then print("[q] pressed") end
    task.spawn(pressKey, S.qKey)
    return true
end

local lastE = 0

local function eReady()
    return (os.clock() - lastE) >= S.eCooldown and os.clock() >= kickCd.e
end

local function pressE()
    if not S.eAttack or not eReady() then return false end
    lastE = os.clock()
    if S.blockDebug then print("[e] pressed") end
    task.spawn(pressKey, S.eKey)
    return true
end

local KICK_ANIM_IDS = {
    "119160927304691", 
    "138434473879558", 
}

local function kickPlaying()
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return false end
    for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
        if t.IsPlaying then
            local id = t.Animation and tostring(t.Animation.AnimationId) or ""
            for _, kickId in ipairs(KICK_ANIM_IDS) do
                if id:find(kickId, 1, true) then return true end
            end
        end
    end
    return false
end

local function waitKickStart(kind, tPress)
    local t0 = os.clock()
    while os.clock() - t0 < S.qConfirm do
        if kind == "q" and kickEvent.q >= tPress then return true end
        if kind == "e" and kickEvent.e >= tPress then return true end
        if not S.noAnims and kickPlaying() then return true end
        task.wait(0.01)
    end
    return false
end

local function startKick()
    if anyBlockerNear() then return false end
    local t = os.clock()
    if pressQ() then
        if waitKickStart("q", t) then return true end
    end

    t = os.clock()
    if pressE() then
        if waitKickStart("e", t) then return true end
    end

    return false
end

local function waitKickDone()
    if S.noAnims then
        local left = kickEvent.untilT - os.clock()
        if left > 0 then task.wait(left) end
        return
    end
    local t0 = os.clock()
    while os.clock() - t0 < S.qMaxWait do
        if not kickPlaying() then
            task.wait(0.05)
            return
        end
        task.wait(0.02)
    end
end

local function fireLmb()
    if not FistRemote then return false end
    
    if anyBlockerNear() then return false end
    pcall(function() FistRemote:Fire("lmb") end)
    return true
end

local function combatReady()
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("Fists") then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if player:GetAttribute("canAttack") == false then return false end
    return true
end

if FistRemote then
    task.spawn(function()
        while RUN.alive do
            if S.fastHits then
                if combatReady() then
                    local target = getHitTarget()
                    local kicked = false

                    
                    
                    if anyBlockerNear() then
                        while anyBlockerNear() do
                            task.wait(0.02)
                        end

                        task.wait(S.blockGrace)
                        target = getHitTarget()

                        if target and not anyBlockerNear() then
                            kicked = startKick()
                            if not kicked then
                                fireLmb()
                            end
                        end

                    else
                        
                        
                        if S.qInRotation then
                            kicked = startKick()
                        end
                        if not kicked and not anyBlockerNear() then
                            fireLmb()
                        end
                    end

                    
                    
                    if kicked then
                        waitKickDone()
                    end
                end
                task.wait(S.hitDelay)
            else
                task.wait(0.1)
            end
        end
    end)
end

task.spawn(function()
    while RUN.alive do
        if S.antiRagdoll then
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                local state = hum:GetState()
                if state == Enum.HumanoidStateType.Physics
                   or state == Enum.HumanoidStateType.FallingDown
                   or state == Enum.HumanoidStateType.Ragdoll then
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
                end
                if hum.PlatformStand then
                    hum.PlatformStand = false
                end
            end
        end
        task.wait(S.antiRagdollRate / 1000)
    end
end)

local Magnets = {}

local function removeMagnetFor(target)
    local m = Magnets[target]
    if m then
        pcall(function() m:Destroy() end)
        Magnets[target] = nil
    end
end

local function createMagnetFor(target)
    local char = target.Character
    if not char then return end
    if Magnets[target] and Magnets[target].Parent then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local magnet = Instance.new("Part")
    magnet.Name         = "MagnetHitbox"
    magnet.Size         = Vector3.new(S.magnetSize, S.magnetSize, S.magnetSize)
    magnet.CFrame       = head.CFrame
    magnet.Shape        = Enum.PartType.Ball
    magnet.Transparency = 1
    magnet.CanCollide   = false
    magnet.CanQuery     = false 
    magnet.Anchored     = false
    magnet.Massless     = true
    magnet.Parent       = workspace

    local weld = Instance.new("WeldConstraint")
    weld.Part0  = head
    weld.Part1  = magnet
    weld.Parent = magnet

    Magnets[target] = magnet
end

task.spawn(function()
    while RUN.alive and task.wait(0.2) do
        if S.magnet then
            local target = getMagnetTarget()
            for p in pairs(Magnets) do
                if p ~= target then removeMagnetFor(p) end
            end
            if target then
                createMagnetFor(target)
            end
        else
            for p in pairs(Magnets) do removeMagnetFor(p) end
        end
    end
end)

player.CharacterRemoving:Connect(function()
    for p in pairs(Magnets) do removeMagnetFor(p) end
end)

local function getCenter()
    return Camera.ViewportSize / 2
end

local function insideCircle(sp)
    local c = getCenter()
    return (Vector2.new(sp.X, sp.Y) - c).Magnitude <= S.fovRadius
end

local function getAimPart(char)
    local pn = S.aimPart
    return char:FindFirstChild(pn)
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Head")
end

local function isEnemy(plr)
    if not S.teamCheck then return true end
    if not plr.Team then return true end
    if player.Team and plr.Team == player.Team then return false end
    return true
end

local function getTarget()
    if S.lockedTarget then
        local part = S.lockedTarget
        local char = part.Parent
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if char and hum and hum.Health > 0 then
            return part
        end
        S.lockedTarget = nil
    end

    local nearest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local char = plr.Character
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and isEnemy(plr) then
                local part = getAimPart(char)
                if part then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on and insideCircle(sp) then
                        local d = (Vector2.new(sp.X, sp.Y) - getCenter()).Magnitude
                        if d < minDist then
                            minDist = d
                            nearest = part
                        end
                    end
                end
            end
        end
    end

    if nearest then
        S.lockedTarget = nearest
    end
    return nearest
end

local function smoothLookAt(targetPos)
    local current = Camera.CFrame
    local goal    = CFrame.lookAt(current.Position, targetPos)
    if S.aimSmooth <= 0 then
        Camera.CFrame = goal
    else
        local alpha = math.clamp(S.aimSmooth / 100, 0.01, 1)
        Camera.CFrame = current:Lerp(goal, alpha)
    end
end

RunService.RenderStepped:Connect(function()
    if not RUN.alive then return end
    if not S.aimEnabled then
        S.lockedTarget = nil
        return
    end
    local target = getTarget()
    if target then
        smoothLookAt(target.Position)
    end
end)

local uiAimToggle = nil

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == S.aimBind then
        S.aimEnabled = not S.aimEnabled
        if not S.aimEnabled then
            S.lockedTarget = nil
        end
        if uiAimToggle then
            pcall(function() uiAimToggle:Set(S.aimEnabled) end)
        end
    end
end)

local Mouse = player:GetMouse()

local lastTp = 0

local function teleportTo(pos)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local ok = pcall(function()
        char:MoveTo(pos)
    end)
    return ok
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if not S.tpEnabled then return end
    if input.UserInputType ~= S.tpButton then return end
    if not UIS:IsKeyDown(S.tpKey) then return end

    
    if gameProcessed or UIS:GetFocusedTextBox() then return end

    local now = os.clock()
    if now - lastTp < S.tpCooldown then return end
    lastTp = now

    local hit = Mouse.Hit
    if not hit then return end

    local pos = hit.Position + Vector3.new(0, S.tpRaiseY, 0)
    teleportTo(pos)
end)

RunService.Heartbeat:Connect(function()
    if not RUN.alive then return end
    if not S.speedFix then return end

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    if S.speedSkipRagdoll then
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Physics
            or st == Enum.HumanoidStateType.FallingDown
            or st == Enum.HumanoidStateType.Ragdoll then
            return
        end
    end

    if hum.WalkSpeed < S.speedNormal then
        hum.WalkSpeed = S.speedBoost
    end
end)

local lang = "en"

local LONG = {
    credits_desc = {
        ru = "Боевой хаб: удары, блок-гард, магнит, аим, телепорт и фикс скорости в одном скрипте.\nСтатус ALPHA: возможны баги, баланс и хоткеи ещё меняются.\nМеню: LeftAlt — открыть/закрыть. Крестик в окне уничтожает его — вернуть можно кнопкой «Пересоздать меню».",
        en = "Combat hub: hits, block guard, magnet, aim, teleport and speed fix in one script.\nALPHA status: bugs, balance and hotkeys may change.\nMenu: LeftAlt to open/close. The X button destroys the window — use \"Rebuild menu\" to bring it back.",
    },
    hotkeys = {
        ru = "LeftAlt — меню\nR — аим вкл/выкл\nCtrl + ЛКМ — телепорт\nQ — кик после блока, E — запасной кик",
        en = "LeftAlt — menu\nR — aim on/off\nCtrl + LMB — teleport\nQ — kick after block, E — backup kick",
    },
}

local EN = {
    ["Бой"] = "Combat",
    ["Удары"] = "Hits",
    ["Анимации"] = "Animations",
    ["Магнит"] = "Magnet",
    ["Защита"] = "Protection",
    ["Аим"] = "Aim",
    ["Движение"] = "Movement",
    ["Телепорт"] = "Teleport",
    ["Скорость"] = "Speed",
    ["Меню"] = "Menu",
    ["Креды"] = "Credits",
    ["Команда"] = "Team",
    ["Хоткеи"] = "Hotkeys",
    ["Быстрые удары"] = "Fast hits",
    ["lmb каждый кадр, кики после блока"] = "lmb every frame, kicks after block",
    ["Блок-гард"] = "Block guard",
    ["не бить, если рядом кто-то в блоке"] = "don't hit if someone nearby is blocking",
    ["Q/E в обычной ротации"] = "Q/E in normal rotation",
    ["OFF: Q только после блока"] = "OFF: Q only after block",
    ["Доставание ударов"] = "Hit reach",
    ["Дистанция удара"] = "Hit distance",
    ["стадов сверх кулака"] = "studs beyond the fist",
    ["Показывать удары"] = "Show hits",
    ["OFF: боевые анимации скрыты"] = "OFF: combat animations hidden",
    ["Ускорение анимаций"] = "Animation speed",
    ["Скорость анимаций"] = "Animation multiplier",
    ["множитель"] = "multiplier",
    ["Магнит на цель"] = "Magnet to target",
    ["хитбокс тащится к цели удара"] = "hitbox follows the hit target",
    ["Размер хитбокса"] = "Hitbox size",
    ["Радиус поиска"] = "Search radius",
    ["вставать из стана / рэгдолла"] = "get up from stun / ragdoll",
    ["Плавность"] = "Smoothness",
    ["0 = мгновенно, 100 = плавно"] = "0 = instant, 100 = smooth",
    ["радиус, в котором ищется цель"] = "radius to search for a target",
    ["Часть тела"] = "Body part",
    ["Проверка команды"] = "Team check",
    ["не целиться в своих"] = "don't aim at teammates",
    ["Клавиша аима"] = "Aim key",
    ["по умолчанию R"] = "default R",
    ["Ctrl + ЛКМ по точке"] = "Ctrl + LMB on a spot",
    ["Кулдаун"] = "Cooldown",
    ["пауза между прыжками, сек"] = "delay between jumps, sec",
    ["Телепорт на курсор"] = "Teleport to cursor",
    ["Фикс скорости в блоке"] = "Block speed fix",
    ["не тормозить, когда держишь блок"] = "don't slow down while blocking",
    ["Нормальная скорость"] = "Normal speed",
    ["Скорость в блоке"] = "Block speed",
    ["Не трогать в рэгдолле"] = "Skip in ragdoll",
    ["ON: не поднимать скорость в стане"] = "ON: don't boost speed while stunned",
    ["Клавиша меню"] = "Menu key",
    ["по умолчанию LeftAlt"] = "default LeftAlt",
    ["Пересоздать меню"] = "Rebuild menu",
    ["если окно закрылось крестиком"] = "if you closed the window with X",
    ["Скрыть меню"] = "Hide menu",
    ["ALPHA — сборка в разработке"] = "ALPHA — build in progress",
    ["код · боевая логика"] = "code · combat logic",
    ["идеи · тесты"] = "ideas · tests",
    ["LeftAlt — открыть/закрыть меню"] = "LeftAlt — open/close menu",
    ["Язык"] = "Language",
    ["Язык интерфейса"] = "Interface language",
    ["Ссылка на Discord скопирована"] = "Discord link copied",
}

local function T(s)
    if lang == "en" and EN[s] then return EN[s] end
    return s
end

local function TL(key)
    local v = LONG[key]
    if not v then return key end
    return v[lang] or v.ru
end

local function destroyUI()
    local list = getgenv().NB_SCREENS
    if type(list) == "table" then
        for i = #list, 1, -1 do
            local s = list[i]
            if s then
                pcall(function()
                    if s.Parent then s:Destroy() end
                end)
            end
            list[i] = nil
        end
    end
    _G.NB_HUB_UI = nil

    
    
    local roots = { game:GetService("CoreGui"), player:FindFirstChild("PlayerGui") }
    local robloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
    if robloxGui then table.insert(roots, robloxGui) end
    local stale = { WindUI = true, Notifications = true, Dropdowns = true, Tooltips = true }
    for _, root in ipairs(roots) do
        if root then
            for _, g in ipairs(root:GetChildren()) do
                if g:IsA("ScreenGui") and stale[g.Name] then
                    pcall(function() g:Destroy() end)
                end
            end
        end
    end
    getgenv().NB_WINDUI = nil
end

getgenv().NB_UNLOAD = function()
    RUN.alive = false
    pcall(destroyUI)
end

local building = false
local buildingSince = 0
local buildUI
buildUI = function()
        if building and (os.clock() - buildingSince) < 4 then return end
        building = true
        buildingSince = os.clock()

        
        pcall(destroyUI)

        local roots = { game:GetService("CoreGui") }
        local robloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
        if robloxGui then table.insert(roots, robloxGui) end
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then table.insert(roots, playerGui) end

        
        local beforeGuis = {}
        for _, root in ipairs(roots) do
            for _, g in ipairs(root:GetChildren()) do
                if g:IsA("ScreenGui") then beforeGuis[g] = true end
            end
        end

        
        
        local WindUI
        do
            local ok, res = pcall(function()
                return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
            end)
            if ok then WindUI = res end
        end
        if not WindUI then error("WindUI failed to load") end

        WindUI:SetNotificationLower(true)

        local Window = WindUI:CreateWindow({
            Title        = "NOBLACK HUB",
            Author       = "by zenin & 0x00string",
            Icon         = "swords",
            Folder       = "NoblackHub",
            Size         = UDim2.fromOffset(620, 520),
            Theme        = "Dark",
            NewElements  = true,
            Acrylic      = true,
            HideSearchBar = false,
            ToggleKey    = Enum.KeyCode.LeftAlt, 
            Topbar       = { Height = 46, ButtonsType = "Mac" },
            Background   = WindUI:Gradient({
                ["0"]   = { Color = Color3.fromHex("#1B1033"), Transparency = 0.2 },
                ["55"]  = { Color = Color3.fromHex("#0E0E14"), Transparency = 0.2 },
                ["100"] = { Color = Color3.fromHex("#0A1F2E"), Transparency = 0.2 },
            }, { Rotation = 115 }),
            User = { Enabled = true, Anonymous = false },
        })

        
        
        getgenv().NB_SCREENS = getgenv().NB_SCREENS or {}
        local screen = nil
        for _, root in ipairs(roots) do
            for _, g in ipairs(root:GetChildren()) do
                if g:IsA("ScreenGui") and not beforeGuis[g] then
                    table.insert(getgenv().NB_SCREENS, g)
                    if not screen and #g:GetDescendants() > 50 then screen = g end
                end
            end
        end
        if not screen then
            building = false
            error("WindUI did not render the window")
        end
        screen.ResetOnSpawn = false
        screen.IgnoreGuiInset = true

        _G.NB_HUB_UI = { Window = Window, WindUI = WindUI, Screen = screen, Rebuild = buildUI }

        
        Window:Tag({
            Title = "v1.0",
            Icon = "solar:file-text-bold",
            Color = Color3.fromHex("#257AF7"),
            Border = true,
        })
        Window:Tag({
            Title = "ALPHA · in development",
            Icon = "triangle-alert",
            Color = Color3.fromHex("#EF4F1D"),
            Border = true,
        })

        
        
        
        local FightTab = Window:Tab({ Title = T("Бой"), Icon = "swords" })
        local StrikeSec = FightTab:Section({ Title = T("Удары"), Icon = "swords" })

        StrikeSec:Toggle({
            Title = T("Быстрые удары"),
            Desc = T("lmb каждый кадр, кики после блока"),
            Value = S.fastHits,
            Callback = function(v) S.fastHits = v end,
        })
        StrikeSec:Toggle({
            Title = T("Блок-гард"),
            Desc = T("не бить, если рядом кто-то в блоке"),
            Value = S.blockGuard,
            Callback = function(v) S.blockGuard = v end,
        })
        StrikeSec:Toggle({
            Title = T("Q/E в обычной ротации"),
            Desc = T("OFF: Q только после блока"),
            Value = S.qInRotation,
            Callback = function(v) S.qInRotation = v end,
        })
        StrikeSec:Toggle({
            Title = T("Доставание ударов"),
            Value = S.reachEnabled,
            Callback = function(v) S.reachEnabled = v end,
        })
        StrikeSec:Slider({
            Title = T("Дистанция удара"),
            Desc = T("стадов сверх кулака"),
            Value = { Min = 0, Max = 30, Default = S.reach },
            Step = 1,
            Callback = function(v) S.reach = v end,
        })

        local AnimSec = FightTab:Section({ Title = T("Анимации"), Icon = "sparkles" })

        AnimSec:Toggle({
            Title = T("Показывать удары"),
            Desc = T("OFF: боевые анимации скрыты"),
            Value = not S.noAnims,
            Callback = function(v) S.noAnims = not v end,
        })
        AnimSec:Toggle({
            Title = T("Ускорение анимаций"),
            Value = S.animSpeedEnabled,
            Callback = function(v) S.animSpeedEnabled = v end,
        })
        AnimSec:Slider({
            Title = T("Скорость анимаций"),
            Desc = T("множитель"),
            Value = { Min = 1, Max = 10, Default = S.animSpeed },
            Step = 1,
            Callback = function(v) S.animSpeed = v end,
        })

        local MagSec = FightTab:Section({ Title = T("Магнит"), Icon = "magnet" })

        MagSec:Toggle({
            Title = T("Магнит на цель"),
            Desc = T("хитбокс тащится к цели удара"),
            Value = S.magnet,
            Callback = function(v) S.magnet = v end,
        })
        MagSec:Slider({
            Title = T("Размер хитбокса"),
            Value = { Min = 20, Max = 200, Default = S.magnetSize },
            Step = 5,
            Callback = function(v)
                S.magnetSize = v
                for p in pairs(Magnets) do removeMagnetFor(p) end
            end,
        })
        MagSec:Slider({
            Title = T("Радиус поиска"),
            Value = { Min = 20, Max = 400, Default = S.magnetRange },
            Step = 5,
            Callback = function(v) S.magnetRange = v end,
        })

        local DefSec = FightTab:Section({ Title = T("Защита"), Icon = "shield" })

        DefSec:Toggle({
            Title = "Anti-Ragdoll",
            Desc = T("вставать из стана / рэгдолла"),
            Value = S.antiRagdoll,
            Callback = function(v) S.antiRagdoll = v end,
        })

        
        
        
        local AimTab = Window:Tab({ Title = T("Аим"), Icon = "crosshair" })
        local AimSec = AimTab:Section({ Title = T("Аим"), Icon = "crosshair" })

        local AimToggle = AimSec:Toggle({
            Title = T("Аим"),
            Value = S.aimEnabled,
            Callback = function(v)
                S.aimEnabled = v
                if not v then S.lockedTarget = nil end
            end,
        })
        uiAimToggle = AimToggle

        AimSec:Slider({
            Title = T("Плавность"),
            Desc = T("0 = мгновенно, 100 = плавно"),
            Value = { Min = 0, Max = 100, Default = S.aimSmooth },
            Step = 1,
            Callback = function(v) S.aimSmooth = v end,
        })
        AimSec:Slider({
            Title = "FOV",
            Desc = T("радиус, в котором ищется цель"),
            Value = { Min = 50, Max = 500, Default = S.fovRadius },
            Step = 10,
            Callback = function(v) S.fovRadius = v end,
        })
        AimSec:Dropdown({
            Title = T("Часть тела"),
            Values = { "Head", "Torso", "HumanoidRootPart" },
            Value = S.aimPart,
            Callback = function(v) S.aimPart = v end,
        })
        AimSec:Toggle({
            Title = T("Проверка команды"),
            Desc = T("не целиться в своих"),
            Value = S.teamCheck,
            Callback = function(v) S.teamCheck = v end,
        })
        AimSec:Keybind({
            Title = T("Клавиша аима"),
            Desc = T("по умолчанию R"),
            Value = S.aimBind.Name,
            Callback = function(v)
                local kc = (typeof(v) == "EnumItem" and v) or Enum.KeyCode[v]
                if kc then S.aimBind = kc end
            end,
        })

        
        
        
        local MoveTab = Window:Tab({ Title = T("Движение"), Icon = "move" })
        local TpSec = MoveTab:Section({ Title = T("Телепорт"), Icon = "map-pin" })

        TpSec:Toggle({
            Title = T("Телепорт"),
            Desc = T("Ctrl + ЛКМ по точке"),
            Value = S.tpEnabled,
            Callback = function(v) S.tpEnabled = v end,
        })
        TpSec:Slider({
            Title = T("Кулдаун"),
            Desc = T("пауза между прыжками, сек"),
            Value = { Min = 0.05, Max = 1, Default = S.tpCooldown },
            Step = 0.05,
            Callback = function(v) S.tpCooldown = v end,
        })
        TpSec:Button({
            Title = T("Телепорт на курсор"),
            Icon = "map-pin",
            Callback = function()
                local hit = Mouse.Hit
                if hit then
                    teleportTo(hit.Position + Vector3.new(0, S.tpRaiseY, 0))
                end
            end,
        })

        local SpdSec = MoveTab:Section({ Title = T("Скорость"), Icon = "gauge" })

        SpdSec:Toggle({
            Title = T("Фикс скорости в блоке"),
            Desc = T("не тормозить, когда держишь блок"),
            Value = S.speedFix,
            Callback = function(v) S.speedFix = v end,
        })

        local BoostSlider
        SpdSec:Slider({
            Title = T("Нормальная скорость"),
            Value = { Min = 8, Max = 32, Default = S.speedNormal },
            Step = 1,
            Callback = function(v)
                S.speedNormal = v
                if S.speedBoost < v + 1 then
                    S.speedBoost = v + 1
                    if BoostSlider then
                        pcall(function()
                            BoostSlider:SetMin(S.speedNormal)
                            BoostSlider:Set(S.speedBoost)
                        end)
                    end
                end
            end,
        })
        BoostSlider = SpdSec:Slider({
            Title = T("Скорость в блоке"),
            Value = { Min = S.speedNormal, Max = 80, Default = S.speedBoost },
            Step = 1,
            Callback = function(v) S.speedBoost = v end,
        })
        SpdSec:Toggle({
            Title = T("Не трогать в рэгдолле"),
            Desc = T("ON: не поднимать скорость в стане"),
            Value = S.speedSkipRagdoll,
            Callback = function(v) S.speedSkipRagdoll = v end,
        })

        local MenuSec = MoveTab:Section({ Title = T("Меню"), Icon = "settings" })

        MenuSec:Keybind({
            Title = T("Клавиша меню"),
            Desc = T("по умолчанию LeftAlt"),
            Value = "LeftAlt",
            Callback = function(v)
                local kc = (typeof(v) == "EnumItem" and v) or Enum.KeyCode[v]
                if kc then Window:SetToggleKey(kc) end
            end,
        })
        MenuSec:Button({
            Title = T("Пересоздать меню"),
            Desc = T("если окно закрылось крестиком"),
            Icon = "refresh-cw",
            Callback = function()
                task.delay(0.15, function()
                    building = false
                    pcall(buildUI)
                end)
            end,
        })
        MenuSec:Button({
            Title = T("Скрыть меню"),
            Icon = "x",
            Callback = function() Window:Close() end,
        })

        
        
        
        local CreditTab = Window:Tab({ Title = T("Креды"), Icon = "users" })

        CreditTab:Section({
            Title = "NOBLACK HUB v1.0",
            Desc = T("ALPHA — сборка в разработке"),
            TextSize = 22,
            FontWeight = Enum.FontWeight.SemiBold,
        })
        CreditTab:Section({
            Title = TL("credits_desc"),
            TextSize = 15,
            TextTransparency = 0.3,
        })

        local TeamSec = CreditTab:Section({ Title = T("Команда"), Icon = "users" })

        TeamSec:Section({
            Title = "zenin",
            Desc = T("код · боевая логика"),
            TextSize = 19,
            FontWeight = Enum.FontWeight.SemiBold,
        })
        TeamSec:Section({
            Title = "0x00string",
            Desc = T("идеи · тесты"),
            TextSize = 19,
            FontWeight = Enum.FontWeight.SemiBold,
        })

        local HotkeySec = CreditTab:Section({ Title = T("Хоткеи"), Icon = "keyboard" })

        HotkeySec:Section({
            Title = TL("hotkeys"),
            TextSize = 15,
            TextTransparency = 0.3,
        })

        
        task.delay(0.6, function()
            pcall(function()
                WindUI:Notify({
                    Title = "NOBLACK HUB v1.0 (ALPHA)",
                    Content = "LeftAlt — открыть/закрыть меню",
                    Icon = "triangle-alert",
                    Duration = 6,
                })
            end)
        end)

        building = false
end

do
    local uiOk, uiErr = pcall(buildUI)
    building = false
    if not uiOk then
        
        warn("[noblack hub] menu build failed: " .. tostring(uiErr) .. " - retry")
        task.wait(0.5)
        building = false
        local ok2, err2 = pcall(buildUI)
        building = false
        if not ok2 then
            warn("[noblack hub] menu build failed again: " .. tostring(err2))
        end
    end
end

print("[noblack hub v1.0] loaded. MAX hits, anims ON, block guard ALL players, Ctrl+LMB teleport, LeftAlt menu.")

task.spawn(function()
    local fails = 0
    while RUN.alive do
        task.wait(45)

        local tok = (type(NB_ENV) == "table" and NB_ENV.token) or getgenv().NB_TOKEN
        if type(tok) ~= "string" or tok == "" then
            fails = fails + 1
        else
            local ok, res = pcall(function()
                local hs = game:GetService("HttpService")
                local rq = rawget(_G, "request") or request or rawget(_G, "http_request") or http_request or (syn and syn.request) or (http and http.request)
                if type(rq) ~= "function" then return nil end
                local r = rq({
                    Url = NB_API .. "/verify",
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json", Authorization = "Bearer " .. tok },
                    Body = "{}",
                })
                return hs:JSONDecode(r.Body)
            end)

            if ok and res and res.ok == true then
                fails = 0
            else
                fails = fails + 1
            end
        end

        if fails >= 3 then
            S.fastHits = false
            S.qAttack = false
            S.eAttack = false
            S.aimEnabled = false
            S.magnet = false
            S.tpEnabled = false
            S.speedFix = false
            S.antiRagdoll = false
            pcall(destroyUI)
            break
        end
    end
end)

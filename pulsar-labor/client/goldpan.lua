local _joiner = nil
local _working = false
local _actionLabel = nil
local _actionBaseDur = nil
local _actionAnim = nil
local _tasks = 0
local _blip = nil
local eventHandlers = {}
local _nodes = nil
local _state = 0
local _promptVisible = false

local function getSupervisor()
    return GoldPanSupervisor or {
        coords = vector3(-1105.772, 2696.657, 17.613),
        heading = 227.977,
    }
end

local function getGoldPanItem()
    return (GoldPanTool and GoldPanTool.item) or "goldpan"
end

local function getGoldPanPrice()
    return (GoldPanTool and GoldPanTool.price) or 250
end

local function hasGoldPan()
    local item = getGoldPanItem()
    local ok, result = pcall(function()
        return exports.ox_inventory:ItemsHas(item, 1)
    end)

    return ok and result == true
end

AddEventHandler("Labor:Client:Setup", function()
    local supervisor = getSupervisor()

    exports['pulsar-pedinteraction']:Remove("GoldpanJob")
    exports['pulsar-pedinteraction']:Add(
        "GoldpanJob",
        `s_m_y_construct_02`,
        supervisor.coords,
        supervisor.heading,
        25.0,
        {
            {
                icon = "cart-shopping",
                text = string.format("Buy Gold Pan ($%s)", getGoldPanPrice()),
                event = "Goldpan:Client:BuyGoldPan",
                tempjob = "Goldpan",
                isEnabled = function()
                    return not hasGoldPan()
                end,
            },
            {
                icon = "hand-holding-droplet",
                text = "Start Job",
                event = "Goldpan:Client:StartJob",
                tempjob = "Goldpan",
                isEnabled = function()
                    return not _working
                end,
            },
            {
                icon = "handshake",
                text = "Finish Job",
                event = "Goldpan:Client:TurnIn",
                tempjob = "Goldpan",
                isEnabled = function()
                    return _working and _state == 2
                end,
            },
        },
        "gem",
        "WORLD_HUMAN_CLIPBOARD"
    )
end)

local _doing = false
function DoGoldPanAction(id)
    exports['pulsar-hud']:ProgressWithTickEvent({
        name = "goldpan_action",
        duration = (math.random(5) + _actionBaseDur) * 1000,
        label = _actionLabel,
        tickrate = 1000,
        useWhileDead = false,
        canCancel = true,
        vehicle = false,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableCombat = true,
        },
        animation = _actionAnim,
    }, function()
        if not _doing then return end
        if _nodes ~= nil then
            for _, v in ipairs(_nodes) do
                if v.id == id then
                    return
                end
            end
        end
        exports['pulsar-hud']:ProgressCancel()
    end, function(cancelled)
        _doing = false
        if not cancelled then
            exports["pulsar-core"]:ServerCallback("Goldpan:CompleteNode", id)
        end
    end)
end

RegisterNetEvent("Goldpan:Client:OnDuty", function(joiner, time)
    _joiner = joiner
    local supervisor = getSupervisor()
    DeleteWaypoint()
    SetNewWaypoint(supervisor.coords.x, supervisor.coords.y)

    local blipCfg = GoldPanBlip or {}
    _blip = exports["pulsar-blips"]:Add(
        "GoldpanStart",
        blipCfg.label or "Gold Panning",
        { x = supervisor.coords.x, y = supervisor.coords.y, z = 0 },
        blipCfg.sprite or 467,
        blipCfg.color or 5,
        blipCfg.scale or 0.8
    )

    eventHandlers["keypress"] = AddEventHandler("Keybinds:Client:KeyUp:primary_action", function()
        if _doing then return end
        if _working and _state == 1 and _nodes ~= nil then
            local closest = nil
            for _, v in ipairs(_nodes) do
                local dist = #(
                    vector3(LocalPlayer.state.myPos.x, LocalPlayer.state.myPos.y, LocalPlayer.state.myPos.z)
                    - vector3(v.coords.x, v.coords.y, v.coords.z)
                )
                if dist <= 2.0 then
                    if closest == nil or dist < closest.dist then
                        closest = {
                            dist = dist,
                            point = v,
                        }
                    end
                end
            end

            if closest ~= nil then
                if not hasGoldPan() then
                    exports['pulsar-hud']:Notification("error", "You need a gold pan. Buy one from the supervisor.")
                    return
                end

                _doing = true
                TaskTurnPedToFaceCoord(
                    LocalPlayer.state.ped,
                    closest.point.coords.x,
                    closest.point.coords.y,
                    closest.point.coords.z,
                    1.0
                )
                Citizen.Wait(1000)
                DoGoldPanAction(closest.point.id)
            else
                _doing = false
            end
        end
    end)

    eventHandlers["startup"] = RegisterNetEvent(string.format("Goldpan:Client:%s:Startup", joiner), function(nodes, actionLabel, baseDur, anim)
        exports["pulsar-blips"]:Remove("GoldpanStart")

        if _nodes ~= nil then
            for _, v in ipairs(_nodes) do
                exports["pulsar-blips"]:Remove(string.format("GoldpanNode-%s", v.id))
            end
        end

        _actionLabel = actionLabel
        _actionBaseDur = baseDur
        _actionAnim = anim
        _working = true
        _state = 1
        _tasks = 0
        _nodes = nodes

        for _, v in ipairs(_nodes) do
            exports["pulsar-blips"]:Add(string.format("GoldpanNode-%s", v.id), "Gold Panning Spot", v.coords, 594, 0, 0.8)
        end

        Citizen.CreateThread(function()
            while _working and _state == 1 do
                local nearPoint = false
                for _, v in ipairs(_nodes) do
                    local dist = #(
                        vector3(LocalPlayer.state.myPos.x, LocalPlayer.state.myPos.y, LocalPlayer.state.myPos.z)
                        - vector3(v.coords.x, v.coords.y, v.coords.z)
                    )
                    if dist <= 20 then
                        DrawMarker(
                            1,
                            v.coords.x,
                            v.coords.y,
                            v.coords.z,
                            0,
                            0,
                            0,
                            0,
                            0,
                            0,
                            0.5,
                            0.5,
                            1.0,
                            255,
                            215,
                            0,
                            250,
                            false,
                            false,
                            2,
                            false,
                            false,
                            false,
                            false
                        )
                    end
                    if dist <= 2.0 then
                        nearPoint = true
                    end
                end

                if nearPoint and not _promptVisible then
                    exports['pulsar-hud']:ActionShow("goldpan_action", string.format("{keybind}primary_action{/keybind} %s", _actionLabel or "Pan For Gold"))
                    _promptVisible = true
                elseif not nearPoint and _promptVisible then
                    exports['pulsar-hud']:ActionHide("goldpan_action")
                    _promptVisible = false
                end

                Citizen.Wait(5)
            end

            if _promptVisible then
                exports['pulsar-hud']:ActionHide("goldpan_action")
                _promptVisible = false
            end
        end)
    end)

    eventHandlers["actions"] = RegisterNetEvent(string.format("Goldpan:Client:%s:Action", joiner), function(nodeId)
        for k, v in ipairs(_nodes) do
            if v.id == nodeId then
                exports["pulsar-blips"]:Remove(string.format("GoldpanNode-%s", v.id))
                table.remove(_nodes, k)
                break
            end
        end
    end)

    eventHandlers["return"] = RegisterNetEvent(string.format("Goldpan:Client:%s:EndGoldpan", joiner), function()
        _tasks = _tasks + 1
        _nodes = {}
        _state = 2
        local supervisor = getSupervisor()
        DeleteWaypoint()
        SetNewWaypoint(supervisor.coords.x, supervisor.coords.y)
        _blip = exports["pulsar-blips"]:Add(
            "GoldpanStart",
            "Gold Panning Supervisor",
            { x = supervisor.coords.x, y = supervisor.coords.y, z = 0 },
            480,
            2,
            1.4
        )
    end)
end)

AddEventHandler("Goldpan:Client:StartJob", function()
    if not hasGoldPan() then
        exports['pulsar-hud']:Notification("error", "You need a gold pan. Buy one from the supervisor.")
        return
    end

    exports["pulsar-core"]:ServerCallback("Goldpan:StartJob", _joiner, function(success)
        if not success then
            exports['pulsar-hud']:Notification("error", "Unable To Start Job")
        end
    end)
end)

AddEventHandler("Goldpan:Client:BuyGoldPan", function()
    TriggerServerEvent("Goldpan:Server:BuyGoldPan")
end)

AddEventHandler("Goldpan:Client:TurnIn", function()
    exports["pulsar-core"]:ServerCallback("Goldpan:TurnIn", _joiner, function(success)
        if not success then
            exports['pulsar-hud']:Notification("error", "Unable To Complete Job")
        end
    end)
end)

RegisterNetEvent("Goldpan:Client:OffDuty", function(time)
    for _, handler in pairs(eventHandlers) do
        RemoveEventHandler(handler)
    end

    if _nodes ~= nil then
        for _, v in ipairs(_nodes) do
            exports["pulsar-blips"]:Remove(string.format("GoldpanNode-%s", v.id))
        end
    end

    if _blip ~= nil then
        exports["pulsar-blips"]:Remove("GoldpanStart")
    end

    if _promptVisible then
        exports['pulsar-hud']:ActionHide("goldpan_action")
        _promptVisible = false
    end

    _joiner = nil
    _working = false
    _state = 0
    _tasks = 0
    eventHandlers = {}
    _nodes = nil
end)

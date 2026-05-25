local _JOB = "Goldpan"
local _joiners = {}
local _goldpan = {}

local function getGoldPanItem()
    return (GoldPanTool and GoldPanTool.item) or "goldpan"
end

local function getGoldPanPrice()
    return (GoldPanTool and GoldPanTool.price) or 250
end

local function hasGoldPan(sid)
    return (exports.ox_inventory:ItemsGetCount(sid, 1, getGoldPanItem()) or 0) >= 1
end

local function grantGoldPanLoot(sid, loot)
    if not loot or #loot == 0 then
        return false
    end

    return exports.ox_inventory:LootCustomSetWithCount(loot, sid, 1) == true
end

AddEventHandler("Labor:Server:Startup", function()
    exports["pulsar-core"]:RegisterServerCallback("Goldpan:StartJob", function(source, data, cb)
        local char = exports['pulsar-characters']:FetchCharacterSource(source)
        if not char or char:GetData("TempJob") ~= _JOB then
            cb(false)
            return
        end

        local sid = char:GetData("SID")
        if not hasGoldPan(sid) then
            exports['pulsar-hud']:Notification(source, "error", "You need a gold pan. Buy one from the supervisor.")
            cb(false)
            return
        end

        if _goldpan[data] and _goldpan[data].state == 0 then
            _goldpan[data].state = 1
            _goldpan[data].tasks = 0
            _goldpan[data].job = deepcopy(availableGoldpanJobs[1])
            _goldpan[data].nodes = deepcopy(availableGoldpanJobs[1].locationSets[1])

            exports['pulsar-labor']:StartOffer(data, _JOB, _goldpan[data].job.objective, #_goldpan[data].nodes)
            exports['pulsar-labor']:SendWorkgroupEvent(
                data,
                string.format("Goldpan:Client:%s:Startup", data),
                _goldpan[data].nodes,
                _goldpan[data].job.action,
                _goldpan[data].job.durationBase,
                _goldpan[data].job.animation
            )

            cb(true)
        else
            cb(false)
        end
    end)

    exports["pulsar-core"]:RegisterServerCallback("Goldpan:CompleteNode", function(source, data, cb)
        local char = exports['pulsar-characters']:FetchCharacterSource(source)
        local joiner = _joiners[source]
        local jobState = joiner and _goldpan[joiner] or nil

        if not char or not jobState or char:GetData("TempJob") ~= _JOB then
            cb(false)
            return
        end

        local sid = char:GetData("SID")

        if not hasGoldPan(sid) then
            exports['pulsar-hud']:Notification(source, "error", "You need a gold pan to pan for gold.")
            cb(false)
            return
        end

        for k, v in ipairs(jobState.nodes) do
            if v.id == data then
                local loot = RollGoldPanLoot()
                if not grantGoldPanLoot(sid, loot) then
                    exports['pulsar-hud']:Notification(source, "error", "Not enough inventory space")
                    cb(false)
                    return
                end

                exports['pulsar-labor']:SendWorkgroupEvent(
                    joiner,
                    string.format("Goldpan:Client:%s:Action", joiner),
                    data
                )

                table.remove(jobState.nodes, k)

                if exports['pulsar-labor']:UpdateOffer(joiner, _JOB, 1, true) then
                    jobState.tasks = jobState.tasks + 1
                    jobState.state = 2
                    exports['pulsar-labor']:SendWorkgroupEvent(joiner, string.format("Goldpan:Client:%s:EndGoldpan", joiner))
                    exports['pulsar-labor']:TaskOffer(joiner, _JOB, "Return to the Gold Panning Supervisor")
                end

                cb(true)
                return
            end
        end

        cb(false)
    end)

    exports["pulsar-core"]:RegisterServerCallback("Goldpan:TurnIn", function(source, data, cb)
        local joiner = _joiners[source]
        local jobState = joiner and _goldpan[joiner] or nil

        if not joiner or not jobState or jobState.state ~= 2 then
            exports['pulsar-hud']:Notification(source, "error", "Unable To Complete Job")
            cb(false)
            return
        end

        local char = exports['pulsar-characters']:FetchCharacterSource(source)
        if not char or char:GetData("TempJob") ~= _JOB then
            cb(false)
            return
        end

        jobState.state = 3
        exports['pulsar-labor']:ManualFinishOffer(joiner, _JOB)
        cb(true)
    end)
end)

AddEventHandler("Goldpan:Server:OnDuty", function(joiner, members)
    _joiners[joiner] = joiner
    _goldpan[joiner] = {
        joiner = joiner,
        joiners = { joiner },
        state = 0,
        tasks = 0,
    }

    if members and #members > 0 then
        for _, member in ipairs(members) do
            table.insert(_goldpan[joiner].joiners, member.ID)
            _joiners[member.ID] = joiner
        end
    end

    local char = exports['pulsar-characters']:FetchCharacterSource(joiner)
    char:SetData("TempJob", _JOB)
    exports['pulsar-phone']:NotificationAdd(joiner, "Job Activity", "You started a job", os.time(), 6000, "labor", {})
    TriggerClientEvent("Goldpan:Client:OnDuty", joiner, joiner, os.time())

    exports['pulsar-labor']:TaskOffer(joiner, _JOB, "Buy a gold pan, then speak with the supervisor")

    for _, member in ipairs(_goldpan[joiner].joiners) do
        if member ~= joiner then
            local memberChar = exports['pulsar-characters']:FetchCharacterSource(member)
            if memberChar then
                memberChar:SetData("TempJob", _JOB)
                exports['pulsar-phone']:NotificationAdd(member, "Job Activity", "You started a job", os.time(), 6000, "labor", {})
                TriggerClientEvent("Goldpan:Client:OnDuty", member, joiner, os.time())
            end
        end
    end
end)

AddEventHandler("Goldpan:Server:OffDuty", function(source, joiner)
    _joiners[source] = nil
    TriggerClientEvent("Goldpan:Client:OffDuty", source)
end)

AddEventHandler("Goldpan:Server:FinishJob", function(joiner)
    _goldpan[joiner] = nil
end)

RegisterNetEvent("Goldpan:Server:BuyGoldPan")
AddEventHandler("Goldpan:Server:BuyGoldPan", function()
    local source = source
    local char = exports['pulsar-characters']:FetchCharacterSource(source)

    if not char then
        return
    end

    if char:GetData("TempJob") ~= _JOB then
        exports['pulsar-hud']:Notification(source, "error", "You must be on the gold panning job to buy a pan.")
        return
    end

    local sid = char:GetData("SID")
    local item = getGoldPanItem()
    local price = getGoldPanPrice()

    if hasGoldPan(sid) then
        exports['pulsar-hud']:Notification(source, "error", "You already have a gold pan.")
        return
    end

    local bankAcc = exports['pulsar-finance']:AccountsGetPersonal(sid)
    if not bankAcc or bankAcc.Balance < price then
        exports['pulsar-hud']:Notification(source, "error", "You don't have enough money in your bank.")
        return
    end

    if not grantGoldPanLoot(sid, {
        { name = item, min = 1, max = 1 },
    }) then
        exports['pulsar-hud']:Notification(source, "error", "Not enough inventory space.")
        return
    end

    exports['pulsar-finance']:BalanceWithdraw(bankAcc.Account, price, {
        type = "withdraw",
        title = "Gold Pan Purchase",
        description = "Purchased a gold pan for panning work",
    })
    exports['pulsar-hud']:Notification(source, "success", string.format("You purchased a gold pan for $%s.", price))
end)

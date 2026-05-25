GoldPanSupervisor = {
    coords = vector3(-1105.772, 2696.657, 17.613),
    heading = 227.977,
}

GoldPanBlip = {
    label = "Gold Panning",
    sprite = 467,
    color = 5,
    scale = 0.8,
}

GoldPanTool = {
    item = "goldpan",
    label = "Gold Pan",
    price = 250,
}

GoldPanRewards = {
    { name = "goldore", min = 1, max = 1, chance = 15 },
    { name = "scrapmetal", min = 1, max = 1, chance = 18 },
    { name = "petrock", min = 1, max = 1, chance = 6 },
    { name = "earrings", min = 1, max = 1, chance = 3 },
    { name = "meth_pipe", min = 1, max = 1, chance = 9 },
    { name = "foodbag", min = 1, max = 1, chance = 21 },
    { name = "crushedrock", min = 1, max = 1, chance = 28 },
}

availableGoldpanJobs = {
    {
        objective = "Pan For Gold",
        action = "Pan For Gold",
        durationBase = 10,
        animation = {
            task = "WORLD_HUMAN_GARDENER_PLANT",
        },
        locationSets = {
            {
                { id = 1, coords = vector3(-1405.742, 2005.706, 59.134) },
                { id = 2, coords = vector3(-1402.233, 2005.656, 59.647) },
                { id = 3, coords = vector3(-1399.038, 2005.125, 61.130) },
                { id = 4, coords = vector3(-1395.635, 2004.368, 61.669) },
                { id = 5, coords = vector3(-1391.128, 2003.450, 61.343) },
                { id = 6, coords = vector3(-1385.883, 2002.539, 62.060) },
                { id = 7, coords = vector3(-1380.055, 2001.782, 62.840) },
                { id = 8, coords = vector3(-1373.792, 2000.391, 63.739) },
            },
        },
    },
}

function RollGoldPanLoot()
    local totalChance = 0
    for _, reward in ipairs(GoldPanRewards) do
        totalChance = totalChance + reward.chance
    end

    local roll = math.random(totalChance)
    local cumulative = 0

    for _, reward in ipairs(GoldPanRewards) do
        cumulative = cumulative + reward.chance
        if roll <= cumulative then
            return {
                { name = reward.name, min = reward.min, max = reward.max },
            }
        end
    end

    return {
        { name = "crushedrock", min = 1, max = 1 },
    }
end

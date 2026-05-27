# pulsar-goldpanning

Copy the files from this pulsar-labor folder into the matching client and server and configs folders inside your pulsar-labor.

Also, open startup.lua, copy the RegisterJob export, and add it into your pulsar-labor/server/startup.lua so the job registers properly on startup.

add the item into ox_inventory/data/pulsar-items/labor

	{
		name = "goldpan",
		label = "Gold Pan",
		price = 250,
		isUsable = false,
		isStackable = false,
		type = 7,
		rarity = 2,
		closeUi = true,
		metalic = true,
		weight = 3.0,
	},

Add the image into ox_inventory/web/images

# Credits
Credits to Nolix for creating the original script

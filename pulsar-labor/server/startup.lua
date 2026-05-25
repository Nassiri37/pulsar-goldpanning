	
    AddEventHandler("Labor:Server:Startup", function()
    
    exports['pulsar-labor']:RegisterJob("Goldpan", "Gold Panning", 0, 1200, 75, false, {
		{ label = "Rank 1",   value = 1500 },
		{ label = "Rank 2",   value = 3000 },
		{ label = "Rank 3",   value = 7000 },
		{ label = "Rank 4",   value = 10000 },
		{ label = "Rank 5",   value = 12000 },
	})
    
end)
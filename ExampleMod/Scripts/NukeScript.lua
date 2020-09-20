
local epsTweakWMDResistanceIndex = -1;
if (GameInfo.UnitAbilities["ABILITY_UNIT_WMD_RESISTANCE"] ~= nil) then
	epsTweakWMDResistanceIndex = GameInfo.UnitAbilities["ABILITY_UNIT_WMD_RESISTANCE"].Index
end

---------------------------------------------------------------------------------------------------------

function EpsTweak_OnNuclearWeaponDetonated(playerID, x, y, nukeType)

	local nuke = GameInfo.WMDs[nukeType]
	if (nuke ~= nil) then
		EpsTweak_DealNuclearDamageInArea(x, y, nuke.BlastRadius)
	end
end

---------------------------------------------------------------------------------------------------------

function EpsTweak_DealNuclearDamageInArea(x, y, radius)

	local buildingCache = {}
	local targetIndex = Map.GetPlot(x, y):GetIndex()

	local plots = Map.GetNeighborPlots(x, y, radius);
	for i, plot in ipairs(plots) do
		local damage = 75 * (1 + radius - Map.GetPlotDistance(targetIndex, plot:GetIndex()))
		if (damage > 0) then
			EpsTweak_DealNuclearDamageToPlot(plot, damage, buildingCache)
		end
	end
end

---------------------------------------------------------------------------------------------------------

function EpsTweak_DealNuclearDamageToPlot(plot, damage, buildingCache)
	
	local district = CityManager.GetDistrictAt(plot:GetX(), plot:GetY())
	if (district ~= nil) then
		
		local defensesHP = district:GetMaxDamage(DefenseTypes.DISTRICT_OUTER) - district:GetDamage(DefenseTypes.DISTRICT_OUTER)
				
		if (defensesHP > 0) then
			district:ChangeDamage(DefenseTypes.DISTRICT_OUTER, damage)

			local halfDamage = math.floor(damage / 2)
			if (defensesHP > halfDamage) then defensesHP = halfDamage end
			damage = damage - defensesHP
			if (damage < 0) then damage = 0 end
		end

		if (district:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON) > 0) then
			district:ChangeDamage(DefenseTypes.DISTRICT_GARRISON, damage)
		end
	end

	if (damage <= 0) then return end

	local city = Cities.GetPlotWorkingCity(plot)
	if (city ~= nil) then
		local buildingsObject = city:GetBuildings()
		local buildingsInCity = EpsTweak_NukeScriptGetCityBuildings(city, buildingsObject, buildingCache)
		EpsTweak_DealNuclearDamageToBuildingsInPlot(district, buildingsObject, buildingsInCity, plot, damage)
	end

	EpsTweak_DealNuclearDamageToUnitsInPlot(plot, damage)
	EpsTweak_CreateFalloutInPlot(plot, damage)
end

---------------------------------------------------------------------------------------------------------

function EpsTweak_NukeScriptGetCityBuildings(city, buildingsObject, buildingCache)

	local cityID = city:GetID()
	local buildings = buildingCache[cityID]

	if (buildings == nil) then
		buildings = {}
		for row in GameInfo.Buildings() do
			if (buildingsObject:HasBuilding(row.Index)) then
				local plotIndex = buildingsObject:GetBuildingLocation(row.Index)
				table.insert(buildings, { Row = row, PlotIndex = plotIndex })
			end
		end
		if (table.count(buildings) > 0) then
			table.sort(buildings, function (left, right) return left.Row.Cost > right.Row.Cost end)
		end

		buildingCache[cityID] = buildings
	end

	return buildings
end

---------------------------------------------------------------------------------------------------------

function EpsTweak_DealNuclearDamageToBuildingsInPlot(district, buildingsObject, buildingsInCity, plot, damage)

	local damage = damage - 25
	local plotIndex = plot:GetIndex()

	for i, building in ipairs(buildingsInCity) do
		if (damage >= 25) and (building.PlotIndex == plotIndex) and (not buildingsObject:IsPillaged(building.Row.Index)) then
			damage = damage - 25
			buildingsObject:SetPillaged(building.Row.Index, true)
		end
	end
	
	if (damage >= 25) and (district ~= nil) then
		district:SetPillaged(true)
	end
end

---------------------------------------------------------------------------------------------------------

function EpsTweak_DealNuclearDamageToUnitsInPlot(plot, damage)

	local units = Units.GetUnitsInPlot(plot)
	for i, unit in ipairs(units) do
	
		if (unit:GetAbility():HasAbility(epsTweakWMDResistanceIndex)) then
			unit:ChangeDamage(math.floor(damage / 2))
		else
			unit:ChangeDamage(damage)
		end

		if (unit:GetDamage() >= unit:GetMaxDamage()) then
			UnitManager.Kill(unit)
		end
	end
end

---------------------------------------------------------------------------------------------------------

function EpsTweak_CreateFalloutInPlot(plot, damage)

	damage = damage - 15
	if (damage <= 0) then return end

	local duration = math.floor(damage / 12)
	if (duration > 0) then
		Game.GetFalloutManager():AddFallout(plot:GetIndex(), duration)
	end
end

---------------------------------------------------------------------------------------------------------

GameEvents.OnNuclearWeaponDetonated.Add(EpsTweak_OnNuclearWeaponDetonated);
print("loaded")
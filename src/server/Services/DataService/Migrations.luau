--!strict
-- Profile schema migrations. Steps[n] upgrades a profile from version n to n + 1.
-- Example for a future bump to version 2:
--   Steps[1] = function(data) data.NewField = data.OldField; data.OldField = nil end
-- Reconcile() runs after migration, so purely new fields need no step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameMath"))

local Migrations = {}

Migrations.Steps = {} :: { [number]: (data: any) -> () }

-- v1 -> v2: life stages now come from age. Creatures saved as Adults with age 0 start at adult age.
Migrations.Steps[1] = function(data: any)
	for _, creature in data.Creatures or {} do
		if creature.Stage == "Adult" and (creature.AgeMinutes or 0) == 0 then
			creature.AgeMinutes = GameMath.StageStartMinutes(creature, "Adult")
		end
	end
end

-- Returns false when the profile cannot be used by this server version.
function Migrations.Migrate(data: any, targetVersion: number): (boolean, string?)
	local version = if type(data.SchemaVersion) == "number" then data.SchemaVersion else 1

	if version > targetVersion then
		-- Saved by a newer server; an old server must not touch it
		return false, `profile version {version} is newer than server version {targetVersion}`
	end

	while version < targetVersion do
		local step = Migrations.Steps[version]
		if not step then
			return false, `missing migration step from version {version}`
		end
		step(data)
		version += 1
		data.SchemaVersion = version
	end

	return true, nil
end

return Migrations

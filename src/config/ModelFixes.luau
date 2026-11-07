--!strict
-- Per-model fixes for 3D models in assets/models (see Resources/Model-Names.md).
-- Turn: degrees to spin the model if its front (door, face) points the wrong way.
--       Try 90, 180 or -90. Scale: make it bigger (1.2) or smaller (0.8) than the default fit.
-- Example: Cottage = { Turn = 180, Scale = 1.1 },
-- Gates (Building_wood_fence, Building_reinforced_fence) turn themselves automatically so their
-- long side runs along the fence, so they need no entry here.

return {
	Bench = { Turn = 90 }, -- benches faced sideways around the fountain; now they face the water
	Creature_sheep = { Turn = 180 }, -- sheep walked backwards
	Creature_boar = { Turn = 180 }, -- boar (pig) walked backwards
	Creature_dog = { Turn = 180 }, -- dog walked backwards
	Creature_pip = { Turn = -90 }, -- Tamed Swarmer walked sideways
	Creature_tricky = { Turn = -90 }, -- Tamed Trickster walked sideways
	Creature_bruno = { Turn = 90 }, -- Tamed Brute walked sideways
	Monster_alpha = { Turn = 180 }, -- Alpha (dragon) walked backwards
	Monster_brute = { Turn = -90 }, -- Brute (stone golem) faced left; turned 90 degrees to the right
	Monster_trickster = { Turn = -90 }, -- Trickster (blue robed figure): 90 degrees to the right
	Monster_swarmer = { Turn = -90 }, -- Swarmer (pink fluffy): 90 degrees to the right
} :: { [string]: { Turn: number?, Scale: number? } }

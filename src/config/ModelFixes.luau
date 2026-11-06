--!strict
-- Per-model fixes for 3D models in assets/models (see Resources/Model-Names.md).
-- Turn: degrees to spin the model if its front (door, face) points the wrong way.
--       Try 90, 180 or -90. Scale: make it bigger (1.2) or smaller (0.8) than the default fit.
-- Example: Cottage = { Turn = 180, Scale = 1.1 },

return {
	Building_wood_fence = { Turn = 90 }, -- gate stood across the path instead of in line with the fence
	Building_reinforced_fence = { Turn = 90 }, -- same kind of gate model
	Bench = { Turn = 90 }, -- benches faced sideways around the fountain; now they face the water
} :: { [string]: { Turn: number?, Scale: number? } }

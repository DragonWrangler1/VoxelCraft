# Bonus Chests for mineclonia

- `vlf_bonus_chest.bonus_loot`
This is a loot table (see vlf_loot) which specifies the items to be placed in the bonus chest.

- `vlf_bonus_chest.place_chest(pos, loot, pr)`
This function places a bonus chest with surrounding torches at near pos.
The pr and loot arguments are optional and specify a loot table to be used and a minetest PseudoRandom object.
By default vlf_bonus_chest.bonus_loot is used as the loot table and a position based PseudoRandom object for pr.

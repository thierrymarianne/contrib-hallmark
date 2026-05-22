:- use_module(library(clpfd)).
:- dynamic has_item/2.
trusted_pred(has_item).
:- dynamic level/2.
trusted_pred(level).
:- dynamic attuned/2.
trusted_pred(attuned).
rule(_).
hero(aria).
hero(bron).
hero(cael).
hero(dara).
hero(elis).
hero(finn).
hero(gwen).
hero(hale).
hero(iris).
hero(jace).
hero(kira).
hero(luna).
element(fire).
element(ice).
element(lightning).
element(earth).
element(shadow).
element(light).
region(village).
region(forest).
region(cave).
region(mountain).
region(swamp).
region(volcano).
region(ruins).
region(tower).
region(lake).
region(abyss).
monster(goblin).
monster(wolf).
monster(troll).
monster(wyrm).
monster(specter).
monster(drake).
monster(lich).
monster(golem).
monster(hydra).
monster(phoenix).
item(sword).
item(shield).
item(bow).
item(staff).
item(cloak).
item(lantern).
item(rope).
item(key_stone).
item(elixir).
item(amulet).
item(tome).
weakness(goblin, fire).
weakness(wolf, fire).
weakness(troll, fire).
weakness(wyrm, ice).
weakness(specter, light).
weakness(drake, ice).
weakness(lich, light).
weakness(lich, fire).
weakness(golem, lightning).
weakness(hydra, lightning).
weakness(hydra, fire).
weakness(phoenix, ice).
connects(village, forest).
connects(forest, cave).
connects(forest, swamp).
connects(cave, mountain).
connects(mountain, volcano).
connects(swamp, ruins).
connects(ruins, tower).
connects(village, lake).
connects(lake, swamp).
connects(tower, abyss).
connects(volcano, abyss).
inhabits(goblin, forest).
inhabits(wolf, forest).
inhabits(wolf, cave).
inhabits(troll, cave).
inhabits(troll, swamp).
inhabits(wyrm, mountain).
inhabits(specter, ruins).
inhabits(specter, tower).
inhabits(drake, volcano).
inhabits(lich, tower).
inhabits(golem, ruins).
inhabits(hydra, swamp).
inhabits(hydra, lake).
inhabits(phoenix, volcano).
power(goblin, 3).
power(wolf, 5).
power(troll, 10).
power(wyrm, 15).
power(specter, 12).
power(drake, 20).
power(lich, 25).
power(golem, 18).
power(hydra, 22).
power(phoenix, 30).
min_level(village, 1).
min_level(forest, 1).
min_level(lake, 3).
min_level(cave, 5).
min_level(swamp, 8).
min_level(mountain, 12).
min_level(ruins, 10).
min_level(volcano, 18).
min_level(tower, 15).
min_level(abyss, 25).
grants_access(lantern, cave).
grants_access(rope, mountain).
grants_access(cloak, swamp).
grants_access(key_stone, tower).
grants_access(amulet, ruins).
grants_access(tome, abyss).
can_damage(X0, X1) :- rule(exploit_weakness), attuned(X0, X2), weakness(X1, X2).
can_enter(X0, X1) :- rule(enter_by_level), level(X0, X2), min_level(X1, X3), clpfd_check(X3 #=< X2).
can_enter(X0, X1) :- rule(enter_by_item), has_item(X0, X2), grants_access(X2, X1).
can_defeat(X0, X1) :- rule(overpower), can_damage(X0, X1), level(X0, X2), power(X1, X3), clpfd_check(X3 #=< X2).
can_hunt(X0, X1, X2) :- rule(hunt), can_enter(X0, X2), inhabits(X1, X2), can_defeat(X0, X1).
trail(arrive) :- rule(arrive), region().
trail(through) :- rule(through), region(), trail().
traversable(X0, arrive(X2)) :- rule(traversable_arrive), connects(X0, X2).
traversable(X0, through(X2, X3)) :- rule(traversable_through), connects(X0, X2), traversable(X2, X3).
ctor_witness(aria, hero(aria), [], app(aria, [])).
ctor_witness(bron, hero(bron), [], app(bron, [])).
ctor_witness(cael, hero(cael), [], app(cael, [])).
ctor_witness(dara, hero(dara), [], app(dara, [])).
ctor_witness(elis, hero(elis), [], app(elis, [])).
ctor_witness(finn, hero(finn), [], app(finn, [])).
ctor_witness(gwen, hero(gwen), [], app(gwen, [])).
ctor_witness(hale, hero(hale), [], app(hale, [])).
ctor_witness(iris, hero(iris), [], app(iris, [])).
ctor_witness(jace, hero(jace), [], app(jace, [])).
ctor_witness(kira, hero(kira), [], app(kira, [])).
ctor_witness(luna, hero(luna), [], app(luna, [])).
ctor_witness(fire, element(fire), [], app(fire, [])).
ctor_witness(ice, element(ice), [], app(ice, [])).
ctor_witness(lightning, element(lightning), [], app(lightning, [])).
ctor_witness(earth, element(earth), [], app(earth, [])).
ctor_witness(shadow, element(shadow), [], app(shadow, [])).
ctor_witness(light, element(light), [], app(light, [])).
ctor_witness(village, region(village), [], app(village, [])).
ctor_witness(forest, region(forest), [], app(forest, [])).
ctor_witness(cave, region(cave), [], app(cave, [])).
ctor_witness(mountain, region(mountain), [], app(mountain, [])).
ctor_witness(swamp, region(swamp), [], app(swamp, [])).
ctor_witness(volcano, region(volcano), [], app(volcano, [])).
ctor_witness(ruins, region(ruins), [], app(ruins, [])).
ctor_witness(tower, region(tower), [], app(tower, [])).
ctor_witness(lake, region(lake), [], app(lake, [])).
ctor_witness(abyss, region(abyss), [], app(abyss, [])).
ctor_witness(goblin, monster(goblin), [], app(goblin, [])).
ctor_witness(wolf, monster(wolf), [], app(wolf, [])).
ctor_witness(troll, monster(troll), [], app(troll, [])).
ctor_witness(wyrm, monster(wyrm), [], app(wyrm, [])).
ctor_witness(specter, monster(specter), [], app(specter, [])).
ctor_witness(drake, monster(drake), [], app(drake, [])).
ctor_witness(lich, monster(lich), [], app(lich, [])).
ctor_witness(golem, monster(golem), [], app(golem, [])).
ctor_witness(hydra, monster(hydra), [], app(hydra, [])).
ctor_witness(phoenix, monster(phoenix), [], app(phoenix, [])).
ctor_witness(sword, item(sword), [], app(sword, [])).
ctor_witness(shield, item(shield), [], app(shield, [])).
ctor_witness(bow, item(bow), [], app(bow, [])).
ctor_witness(staff, item(staff), [], app(staff, [])).
ctor_witness(cloak, item(cloak), [], app(cloak, [])).
ctor_witness(lantern, item(lantern), [], app(lantern, [])).
ctor_witness(rope, item(rope), [], app(rope, [])).
ctor_witness(key_stone, item(key_stone), [], app(key_stone, [])).
ctor_witness(elixir, item(elixir), [], app(elixir, [])).
ctor_witness(amulet, item(amulet), [], app(amulet, [])).
ctor_witness(tome, item(tome), [], app(tome, [])).
ctor_witness(w_goblin_fire, weakness(goblin, fire), [], app(w_goblin_fire, [])).
ctor_witness(w_wolf_fire, weakness(wolf, fire), [], app(w_wolf_fire, [])).
ctor_witness(w_troll_fire, weakness(troll, fire), [], app(w_troll_fire, [])).
ctor_witness(w_wyrm_ice, weakness(wyrm, ice), [], app(w_wyrm_ice, [])).
ctor_witness(w_specter_light, weakness(specter, light), [], app(w_specter_light, [])).
ctor_witness(w_drake_ice, weakness(drake, ice), [], app(w_drake_ice, [])).
ctor_witness(w_lich_light, weakness(lich, light), [], app(w_lich_light, [])).
ctor_witness(w_lich_fire, weakness(lich, fire), [], app(w_lich_fire, [])).
ctor_witness(w_golem_lightning, weakness(golem, lightning), [], app(w_golem_lightning, [])).
ctor_witness(w_hydra_lightning, weakness(hydra, lightning), [], app(w_hydra_lightning, [])).
ctor_witness(w_hydra_fire, weakness(hydra, fire), [], app(w_hydra_fire, [])).
ctor_witness(w_phoenix_ice, weakness(phoenix, ice), [], app(w_phoenix_ice, [])).
ctor_witness(c_village_forest, connects(village, forest), [], app(c_village_forest, [])).
ctor_witness(c_forest_cave, connects(forest, cave), [], app(c_forest_cave, [])).
ctor_witness(c_forest_swamp, connects(forest, swamp), [], app(c_forest_swamp, [])).
ctor_witness(c_cave_mountain, connects(cave, mountain), [], app(c_cave_mountain, [])).
ctor_witness(c_mountain_volcano, connects(mountain, volcano), [], app(c_mountain_volcano, [])).
ctor_witness(c_swamp_ruins, connects(swamp, ruins), [], app(c_swamp_ruins, [])).
ctor_witness(c_ruins_tower, connects(ruins, tower), [], app(c_ruins_tower, [])).
ctor_witness(c_village_lake, connects(village, lake), [], app(c_village_lake, [])).
ctor_witness(c_lake_swamp, connects(lake, swamp), [], app(c_lake_swamp, [])).
ctor_witness(c_tower_abyss, connects(tower, abyss), [], app(c_tower_abyss, [])).
ctor_witness(c_volcano_abyss, connects(volcano, abyss), [], app(c_volcano_abyss, [])).
ctor_witness(i_goblin_forest, inhabits(goblin, forest), [], app(i_goblin_forest, [])).
ctor_witness(i_wolf_forest, inhabits(wolf, forest), [], app(i_wolf_forest, [])).
ctor_witness(i_wolf_cave, inhabits(wolf, cave), [], app(i_wolf_cave, [])).
ctor_witness(i_troll_cave, inhabits(troll, cave), [], app(i_troll_cave, [])).
ctor_witness(i_troll_swamp, inhabits(troll, swamp), [], app(i_troll_swamp, [])).
ctor_witness(i_wyrm_mountain, inhabits(wyrm, mountain), [], app(i_wyrm_mountain, [])).
ctor_witness(i_specter_ruins, inhabits(specter, ruins), [], app(i_specter_ruins, [])).
ctor_witness(i_specter_tower, inhabits(specter, tower), [], app(i_specter_tower, [])).
ctor_witness(i_drake_volcano, inhabits(drake, volcano), [], app(i_drake_volcano, [])).
ctor_witness(i_lich_tower, inhabits(lich, tower), [], app(i_lich_tower, [])).
ctor_witness(i_golem_ruins, inhabits(golem, ruins), [], app(i_golem_ruins, [])).
ctor_witness(i_hydra_swamp, inhabits(hydra, swamp), [], app(i_hydra_swamp, [])).
ctor_witness(i_hydra_lake, inhabits(hydra, lake), [], app(i_hydra_lake, [])).
ctor_witness(i_phoenix_volcano, inhabits(phoenix, volcano), [], app(i_phoenix_volcano, [])).
ctor_witness(p_goblin, power(goblin, 3), [], app(p_goblin, [])).
ctor_witness(p_wolf, power(wolf, 5), [], app(p_wolf, [])).
ctor_witness(p_troll, power(troll, 10), [], app(p_troll, [])).
ctor_witness(p_wyrm, power(wyrm, 15), [], app(p_wyrm, [])).
ctor_witness(p_specter, power(specter, 12), [], app(p_specter, [])).
ctor_witness(p_drake, power(drake, 20), [], app(p_drake, [])).
ctor_witness(p_lich, power(lich, 25), [], app(p_lich, [])).
ctor_witness(p_golem, power(golem, 18), [], app(p_golem, [])).
ctor_witness(p_hydra, power(hydra, 22), [], app(p_hydra, [])).
ctor_witness(p_phoenix, power(phoenix, 30), [], app(p_phoenix, [])).
ctor_witness(ml_village, min_level(village, 1), [], app(ml_village, [])).
ctor_witness(ml_forest, min_level(forest, 1), [], app(ml_forest, [])).
ctor_witness(ml_lake, min_level(lake, 3), [], app(ml_lake, [])).
ctor_witness(ml_cave, min_level(cave, 5), [], app(ml_cave, [])).
ctor_witness(ml_swamp, min_level(swamp, 8), [], app(ml_swamp, [])).
ctor_witness(ml_mountain, min_level(mountain, 12), [], app(ml_mountain, [])).
ctor_witness(ml_ruins, min_level(ruins, 10), [], app(ml_ruins, [])).
ctor_witness(ml_volcano, min_level(volcano, 18), [], app(ml_volcano, [])).
ctor_witness(ml_tower, min_level(tower, 15), [], app(ml_tower, [])).
ctor_witness(ml_abyss, min_level(abyss, 25), [], app(ml_abyss, [])).
ctor_witness(ga_lantern_cave, grants_access(lantern, cave), [], app(ga_lantern_cave, [])).
ctor_witness(ga_rope_mountain, grants_access(rope, mountain), [], app(ga_rope_mountain, [])).
ctor_witness(ga_cloak_swamp, grants_access(cloak, swamp), [], app(ga_cloak_swamp, [])).
ctor_witness(ga_key_tower, grants_access(key_stone, tower), [], app(ga_key_tower, [])).
ctor_witness(ga_amulet_ruins, grants_access(amulet, ruins), [], app(ga_amulet_ruins, [])).
ctor_witness(ga_tome_abyss, grants_access(tome, abyss), [], app(ga_tome_abyss, [])).
ctor_witness(exploit_weakness, can_damage(X0, X1), [attuned(X0, X2), weakness(X1, X2)], app(exploit_weakness, [X0, X1, X2, pf(0), pf(1)])).
ctor_witness(enter_by_level, can_enter(X0, X1), [level(X0, X2), min_level(X1, X3), clpfd_check(X3 #=< X2)], app(enter_by_level, [X0, X1, X2, X3, pf(0), pf(1), lia])).
ctor_witness(enter_by_item, can_enter(X0, X1), [has_item(X0, X2), grants_access(X2, X1)], app(enter_by_item, [X0, X1, X2, pf(0), pf(1)])).
ctor_witness(overpower, can_defeat(X0, X1), [can_damage(X0, X1), level(X0, X2), power(X1, X3), clpfd_check(X3 #=< X2)], app(overpower, [X0, X1, X2, X3, pf(0), pf(1), pf(2), lia])).
ctor_witness(hunt, can_hunt(X0, X1, X2), [can_enter(X0, X2), inhabits(X1, X2), can_defeat(X0, X1)], app(hunt, [X0, X1, X2, pf(0), pf(1), pf(2)])).
ctor_witness(arrive, trail(arrive), [region()], app(arrive, [pf(0)])).
ctor_witness(through, trail(through), [region(), trail()], app(through, [pf(0), pf(1)])).
fix_witness(traversable_arrive, traversable(X0, arrive(X2)), [connects(X0, X2)], 0).
fix_witness(traversable_through, traversable(X0, through(X2, X3)), [connects(X0, X2), traversable(X2, X3)], 1).

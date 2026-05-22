%% Fantasy_facts.pl — dynamic hero state
%%
%% Load alongside the generated Fantasy program:
%%   swipl generated.pl Fantasy_facts.pl

%% --- Hero levels ---
:- assertz(level(aria, 20)).
:- assertz(level(bron, 25)).
:- assertz(level(cael, 8)).
:- assertz(level(dara, 15)).
:- assertz(level(elis, 30)).
:- assertz(level(finn, 5)).
:- assertz(level(gwen, 18)).
:- assertz(level(hale, 12)).
:- assertz(level(iris, 22)).
:- assertz(level(jace, 10)).
:- assertz(level(kira, 28)).
:- assertz(level(luna, 3)).

%% --- Elemental attunements ---
:- assertz(attuned(aria, fire)).
:- assertz(attuned(bron, earth)).
:- assertz(attuned(cael, lightning)).
:- assertz(attuned(dara, ice)).
:- assertz(attuned(elis, light)).
:- assertz(attuned(finn, shadow)).
:- assertz(attuned(gwen, fire)).
:- assertz(attuned(hale, ice)).
:- assertz(attuned(iris, lightning)).
:- assertz(attuned(jace, earth)).
:- assertz(attuned(kira, light)).
:- assertz(attuned(luna, fire)).

%% --- Inventories ---

%% Aria — fire warrior, well-equipped
:- assertz(has_item(aria, sword)).
:- assertz(has_item(aria, shield)).
:- assertz(has_item(aria, elixir)).
:- assertz(has_item(aria, lantern)).

%% Bron — earth mage, exploration gear
:- assertz(has_item(bron, staff)).
:- assertz(has_item(bron, cloak)).
:- assertz(has_item(bron, rope)).
:- assertz(has_item(bron, lantern)).

%% Cael — lightning archer, light travel
:- assertz(has_item(cael, bow)).
:- assertz(has_item(cael, rope)).

%% Dara — ice swordfighter, amulet bearer
:- assertz(has_item(dara, sword)).
:- assertz(has_item(dara, amulet)).
:- assertz(has_item(dara, elixir)).

%% Elis — light sage, fully loaded
:- assertz(has_item(elis, staff)).
:- assertz(has_item(elis, tome)).
:- assertz(has_item(elis, lantern)).
:- assertz(has_item(elis, key_stone)).
:- assertz(has_item(elis, amulet)).
:- assertz(has_item(elis, cloak)).

%% Finn — shadow rogue, minimal gear
:- assertz(has_item(finn, cloak)).
:- assertz(has_item(finn, rope)).

%% Gwen — fire knight, combat heavy
:- assertz(has_item(gwen, sword)).
:- assertz(has_item(gwen, shield)).
:- assertz(has_item(gwen, lantern)).
:- assertz(has_item(gwen, rope)).

%% Hale — ice ranger
:- assertz(has_item(hale, bow)).
:- assertz(has_item(hale, elixir)).
:- assertz(has_item(hale, cloak)).

%% Iris — lightning mage, key and tome
:- assertz(has_item(iris, staff)).
:- assertz(has_item(iris, tome)).
:- assertz(has_item(iris, key_stone)).

%% Jace — earth defender
:- assertz(has_item(jace, shield)).
:- assertz(has_item(jace, rope)).
:- assertz(has_item(jace, amulet)).

%% Kira — light paladin, loaded
:- assertz(has_item(kira, sword)).
:- assertz(has_item(kira, staff)).
:- assertz(has_item(kira, tome)).
:- assertz(has_item(kira, lantern)).
:- assertz(has_item(kira, amulet)).
:- assertz(has_item(kira, key_stone)).

%% Luna — fire apprentice, barely starting
:- assertz(has_item(luna, cloak)).

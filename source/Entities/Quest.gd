extends Node2D

"""
# Was supposed to represent a single quest. With all quest data encapsulated.
# Lots of stuff are variables instead of consts so we can deserialize them.
"""

const AreaType = preload("res://Scripts/Enums/AreaType.gd")
const Boss = preload("res://Entities/Battle/Boss.gd")
const KeyItem = preload("res://Entities/KeyItem.gd")

const NPCS = {
	"Mama": preload("res://Entities/MapEntities/Mom.tscn"),
	"Bandit-Dungeon1": preload("res://Entities/MapEntities/Bandit/Dungeon1.tscn"),
	"Bandit-Dungeon2": preload("res://Entities/MapEntities/Bandit/Dungeon2.tscn"),
	"Umayyah": preload("res://Entities/MapEntities/FinalBoss.tscn"),
	"Baba": preload("res://Entities/MapEntities/Dad.tscn")
}

# Number and order of bosses. Eg. [null, {...}, null] means we have to replace
# the second boss with the data from this array. [{...}] means replace only first boss.
# Can't be const because we have to set it when we load game.
var bosses = [
	{
		"type": "Bandit",
		"health": 300,
		"strength": 30,
		"defense": 12,
		"turns": 2,
		"experience points": 200,
		
		"skill_probability": 40,
		"skills": {
			"roar": 60,
			"poison": 30
		},
		"skill_messages": {
			"poison": "stabs you with a poisoned dagger!"
		},
		"drops": {
			"name": "Bandit Bandanna",
			"description": "A small red square of cloth decorated  with white circles"
		}
	},
]

# Again, not const because of saving. Each entry represents dungeon N, array to attach.
# These NPCs show up around the boss, before you fight him.
# "load" sucks with export, so preload up top and reference here.
var attach_quest_npcs = [
	["Mama"],
	["Bandit-Dungeon2"],
	["Umayyah", "Baba"]
]

# What to replace the boss with when he dies and player returns to the map.
var replacement_npcs = ["Bandit-Dungeon1"]

var final_boss_data = {
	"type": "Mufsid",
	"health": 500,
	"strength": 35,
	"defense": 18,
	"turns": 1,
	"experience points": 500,
	
	"skill_probability": 50,
	"skills": {
		"freeze": 50,
		"poison": 20,
		"armour break": 20,
        "vampire": 10
	}
}

# Number and order of boss events. Null means ignored/nothing.
# Note that, like the above, this is *per dungeon* not per boss.
# This is a limited-context grammar. For current story, we just support a few events:
# 1) messages (show message boxes with text)
# 2) run away (flee from player until off-screen)
const  BOSS_EVENTS = [
	# First boss
	{
		"pre-fight": [
			{ "messages": [
				["Bandit", "Rats! How did you find me so fast?"],
				["Mama", "I never lost faith that you would find us!"],
				["Bandit", "No matter! Your days are over, punk!"]
			] }
		],
		"post-fight": [
			{ "messages": [
				["Bandit", "Ugh! You're stronger than you look, runt!"],
				["Bandit", "You may have defeated me, but The Master already got what he needed from {map1}!"]
			] },
			{ "die": "Bandit-Dungeon1" },
			{ "messages": [
				["Aisha", "Are you okay? Did they hurt you?"],
				["Mama", "I'm fine. Don't worry about me, you have to stop them!"],
				["Mama", "I heard them saying they're summoning a monster from {map2} ..."],
				["Aisha", "Okay. InshaAllah (God willing), we will catch them. Let's get you home."]
			] }
		]
	},
	# Second boss
	{
		"pre-fight": [
			{ "messages": [
				["Bandit", "I ..."],
				["Bandit", "I couldn't ... defeat it ..."],
				["Bandit", "The Master ..."],
				["Aisha", "?!"],
				["Aisha", "The Master what?!"],
				["Bandit", "..."]
			] }
		],
		"post-fight": [
			{ "messages": [
				["Bandit", "You killed it ... thank you ..."],
				["Bandit", "The Master ... made us do it ..."],
				["Aisha", "Where is he? I need to save Mama!"],
				["Bandit", "I don't ... {map3} ..."],
				["Bandit", "..."],
			] },
			{"die": "Bandit-Dungeon2" }
		]
	},
	# Third boss
	{
		"pre-fight": [
			{ "messages": [
				["Umayyah", "Fwahaha, I've been waiting for you!"],
				["Aisha", "Baba! If you hurt him ..."],
				["Umayyah", "Do as I say and nobody gets hurt!"],
				["Umayyah", "See that creature over there? You're going to kill it."],
				["Aisha", "..."],
				["Baba", "Don't do it!"],
				["Umayyah", "SILENCE! Do it, child, or he dies."],
				["Aisha", "Baba ... forgive me ..."],
				["Aisha", "I'll do it, just let him go ..."],
				["Umayyah", "Enough talk. The monster, kid."],
				["Aisha", "..."]
			] }
		],
		"post-fight": [
			{ "messages": [
				["Umayyah", "That's a good child. Now hand it over! All of them monster parts!"],
				["Aisha", "..."]
			] },
			{ "audio": "give-items" },
			{ "messages": [
				["", "Aisha" + " gave up the monster parts."],
				["Umayyah", "At last ... the true power ... !"],
				["Aisha", "Let him go!"],
				["Umayyah", "Fwahaha! Fool, you will all perish! The true power is mine!"]
			] },
			{"escape": "Umayyah" },
			{ "messages": [
				["Aisha", "Baba!"],
				["Baba", "I'm ... okay. I guess I am too old to go chasing after villains ..."],
				["Baba", "It's up to you now, daughter. You have to stop him before it's too late."],
				["Baba", "He said something about ... {finalmap}, wherever that is."],
				["Aisha", "Ok Baba, I'll find him and put a stop to this."]
			] }
		]
	}
]

# Hints after beating 0, 1, ... 3 bosses as to where to go next
const POST_BOSS_CUTSCENES = [
	# No bosses defeated
	[
		["Baba", "That ... thing ... headed towards {map1}! Aisha, you have to save her!"]
	],
	# 1 boss defeated
	[
		["Baba", "Alhamdulillah, praise Allah, she is safe!"],
		["Aisha", "Yes, it's a big blessing nobody was hurt. What did that thing want, though?"],
		["Baba", "And who is this mysterious 'Master' it mentioned?"],
		["Mama", "It said they're summoning a monster from {map2} ..."],
		["Aisha", "..."],
		["Baba", "It's dangerous, but you should check it out. We can't let monsters just run rampant."],
		["Mama", "Be careful!"]
	],
	# 2 bosses defeated
	[
		["Aisha", "I found the bandit that kidnapped Mama. It said something about 'The Master', and {map3}."],
		["Baba", "Hmm ... this 'Master' sounds like no good. It could be a trap. Be careful ... you are in a prayers."],
		["Aisha", "I will."]
	],
	# 3 bosses defeated
	[
		["Baba", "Alhamdulillah, I'm okay. But you must stop him before it's too late!"],
		["Baba", "He said something about '{finalmap},' wherever that is."],
		["Aisha", "Ok Baba, I'll find him and put a stop to this."],
		["Mama", "My daughter, we are so proud of you! You grew up into such a strong warrior, like our Zulu ancestors."],
		["Aisha", "Thanks, Mama."]
	]
]

static func add_quest_content_if_applicable(map, variation):
	var dungeon_type = map.map_type + "/" + variation
	var dungeon_number = Globals.world_areas.find(dungeon_type)
	
	var bosses = Globals.quest.bosses
	var npcs = Globals.quest.attach_quest_npcs
	var replacement_npcs = Globals.quest.replacement_npcs
	
	# Add quest boss if there's one specified
	if map.area_type == AreaType.AREA_TYPE.BOSS:
		# Separate bosses from events. Non-quest-bosses have events/attachments too.
		if dungeon_number < len(bosses):
			var quest_boss = bosses[dungeon_number]
			# should be only one key/type/boss. Dictionary of type => data
			for key in map.bosses.keys():
				var item_data = quest_boss["drops"]
				var key_item  = KeyItem.new()
				key_item.initialize(item_data["name"], item_data["description"])
				
				# It's just one element. But it's an array, so ...
				# This seems weird. Replace all bosses with the quest boss?
				var replaced_bosses = []
				for old_boss in map.bosses[key]:
					var boss = Boss.new()
					# Replace at the old boss' coordinates
					boss.initialize(old_boss.x, old_boss.y, quest_boss, key_item)
					replaced_bosses.append(boss)
					
				map.bosses[key] = replaced_bosses
		
		if dungeon_number < len(BOSS_EVENTS):
			for key in map.bosses.keys():
				for boss in map.bosses[key]:
					var events = BOSS_EVENTS[dungeon_number]
					if events != null:
						boss.set_events(events)
		
		if dungeon_number < len(npcs):
			for key in map.bosses.keys():
				for boss in map.bosses[key]:
					boss.attach_quest_npcs = npcs[dungeon_number]
		
		if dungeon_number < len(replacement_npcs):
			for key in map.bosses.keys():
				for boss in map.bosses[key]:
					boss.replace_with_npc = replacement_npcs[dungeon_number]
		

func to_dict():
	return {
		"bosses": self.bosses,
		"attach_quest_npcs": self.attach_quest_npcs,
		"final_boss_data": self.final_boss_data
	}

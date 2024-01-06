/*
*					Commander AI
*
*  			by CapITanJAC / Sandman[SA] / Noshadow / Random1
*  				 orginal code base by Seather
*			Building Electrify used from combat buildings
*
*
* Changelog:
*		Version 1.0 : Inital Release
*
*		Version 1.1 : Added health and ammo delivery
*			Added JP and HA delivery when protolab is built
*			Added dispensing of weapons when armory is built
*			Fixed CVAR to enable/disable commai
*
*		Version 1.2 : Added advanced turretfactory when TF is built
*			Fixed bug that caused TF and Res to not electrify
*
*		Version 1.3 : Bugfix + various optimizations
*			Updated to support AmxmodX 1.8.1
*
*		Version 1.4 : Fixed crashing issue. Error: backward mins/maxs
*			Fixed bug that caused sieges to fail to activate if siege was built first
*			Added medpack call support
*			Added ability to pause commai when player enters comm chair
*			Fixed plugin not disabiling on combat maps, again
*			More opptimizations
* 
*		Version 1.5:  Added commander bot mode, spawn mode, and alien buff cvars
*			Alien buff: adds res every time an alien (or bot) dies.
*				30 res for 1 hive
*				20 res for 2 hives
*				10 res for 3 hives
*				*can be disabled using the cvar amx_commai_alien_buff_mode 0*
*			Changed methods to only work with bots so that REAL players are not affected while on marines		
*			Added spawn effects like a real commander is dropping the buildings.
*			Tweaked the timing, so the buildings drop like a human would. further tweaking with cvar.
*			Optimizations for bots.
* 
*		Version 1.6(12/19/2021):  Added psudo-res bank and cost system. Uses res like a human.
*			Added whole new res cost system. buildings/upgrades etc...
*			Added cvars for electrifing and upgrading buildings for more flexability.
*			Added cost for resupply option.
*			Fixed bug where resupply would not always work.
* 			Added catalyst to resupply
* 			Added psudo upgrade system
* 			Added regenerating armor like Nano armor from Extralevels 3
* 			Changed Alien buff so that Aliens get res passively. (Limit 50 res, 100 for gorges).*Can be reverted to older style.
* 			Added vote for CommAI at start of round
* 			Cleaned up code
* 
* 		Version 1.7(5/13/2022): Added New weapon res reserve for marines
* 			Added random angle for buildings like player commander
* 			Added REAL upgrade system
* 			Fixed advanced Turret Factory upgrades not working consistantly
* 			Added advanced Armory upgrade for advanded weapons
* 			Changed Console Variables for readability
* 			Removed varied resource gains
* 
* 		Version 1.8: Added upgrade animations for buildings
* 			Bug fixes
* 			Balance changes
* 			Tweaked the spawning effects to match the players dropping the buildings 
* 			Added a chance to get mines & grenades
* 			Tweaked the weapon res balance
* 			Changed how plugin handles building upgrades
*
*/

//CVARS
#define disabled 0
#define enabled 1
//comm mode
#define weapons_only 2
#define hybrid 3
#define always 4	
//electricity
#define RTs 5
#define TFs 6
#define both 7
#define all 8
//weapons
#define bots_only 9
//alien buff
#define old 10
#define gorges_only 11
#define bot_gorges_only 12

//Base
/*
* AI Command mode (amx_commai_comm_mode)
* disabled, hybrid, only weapons, always
* hybrid: disabled when human is in command.
* always: enabled wether or not human is in command.
*/ 
#define CVAR_COMM_MODE hybrid

/*
* Resources management system (amx_commai_cost)
* Makes buildings, upgrades, health, and weapons cost resources
* number is multiplication factor
*/
#define CVAR_BUILDING_COST 1.0
#define CVAR_ELECTRIFY_COST 1.0
#define CVAR_UPGRADE_COST 1.0

//Hard coded costs
#define CVAR_RES_COST enabled
#define CVAR_RESUPPLY_COST 1.0
#define CVAR_WEAPONS_COST 1.0

/*
* Automatic Turret Factory Upgrade system (amx_commai_upgrade)
* disabled, enabled
*/
#define CVAR_UPGRADE enabled

/*
* Automatic Electrical Defense systen (amx_commai_electrify_buildings)
* disabled, enabled, RTs only, TFs only, both RTs and TFs, or all buildings.
* Mode (amx_commai_electrify_mode):
* One: Electrify one building at a time.
* All: Electrify all eligble buildings at once.
*/
#define CVAR_ELECTRIFY_BUILDINGS both
#define CVAR_ELECTRIFY_MODE 1

//Weapons, health & ammo

/*
* Players can spawn with random weapons (amx_commai_weapons)
* disabled, enabled, or bots only
*/
#define CVAR_WEAPONS enabled
#define CVAR_WEAPONS_RES_BASE 0.5 //doubled when resupply is enabled

/*
* Psudo-resupply for NS (amx_commai_resupply)
* disabled, enabled
*/
#define CVAR_RESUPPLY enabled
#define CVAR_RESUPPLY_TIME 5.0
#define CVAR_RESUPPLY_USE_WEAPON_RES 1

/*
* Armor regeneration for NS (amx_commai_armor)
* Armor regenerates half of resupply time
* disabled, enabled
*/
#define CVAR_ARMOR enabled

//ALIENS

/*
* To make up for resupply; aliens now get free resource buff (amx_commai_alien_buff_mode)
* resources are gained gradully up to 50 (gorges 100) over time based on how many hives there are. 
* disabled, enabled
* old: resources are added upon death based on hard-coded numbers.
*/
#define CVAR_ALIEN_BUFF both

#define CVAR_OLD_1HIVE 30.0
#define CVAR_OLD_2HIVE 20.0
#define CVAR_OLD_3HIVE 10.0

//Special Effects

/*
* Particals and sounds (amx_commai_effects)
* Building spawns
* Health/ammo spawns
* electricity
* Advanced Turret Factory Upgrade
* disabled, enabled.
*/
#define CVAR_EFFECTS enabled

/*
* Random Delay in building spawns and supply distribution (amx_commai_delay)
* Number is multiplied by the random factor of time.
* Base is 1 - 5 seconds
*/
#define CVAR_DELAY 1.0

//START PLUGIN
#include <amxmodx> 
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <fun>
#include <ns>

#define VERSION "1.8b Public Test"

//eks dump ent info http://www.amxmodx.org/forums/viewtopic.php?p=46290
new g_MaxEnts
new g_FileName[101]
new mapname[41]

#define STORE_MAX 255
new g_buildings[STORE_MAX]
new Float:g_buildingsf[STORE_MAX][3]

//only put ents that you want to save on this list
#define BUILDING_CONV_MAX 14
new const bm_list[BUILDING_CONV_MAX][25]={
"nullio",//0

"team_command",//1
"team_infportal",//2
"phasegate",//3
"resourcetower",//4
"team_turretfactory",//5

"team_armory",//6
"team_armslab",//7
"team_prototypelab",//8
"team_observatory",//9
"turret",//10

"siegeturret",//11
"team_advarmory",//12
"team_advturretfactory"//13
}
//Cost of buildings.
new bm_list_cost[25]={0, 20, 20, 15 ,10 ,10, 10, 20, 40, 15, 10, 15, 40, 10}

//macro define faster in this case than a stock
#define get_team(%1) entity_get_int(%1, EV_INT_team)


//vote
new g_ModName[64]
new roundtime
new choises[3]
new player_comm, comm_mode
new upgrade, bool:upgrading[999], upgradetime[999], upgrade_cost, Float:armslabOrigin[3]
new electrify, electrify_mode, electrify_cost, elec_TFs, elec_RTs
new resupply, resupply_cost, resupply_use_wres, armor
new effects
new bool:resupplytic, resupply_time, Float:temptime
new weapons, weapons_cost, Float:weapon_res, weapon_res_add
new bool:temp_disable = false
new bool:spawned_building = false, bool:wait_for_res, Float:spawn_interval, delayfactor
new building_cost, res_cost, bool:firstTowerBuilt, Float:firstTowerOrigin[3], nozzles
//Alien buff values
new alien_buff_mode, buff_1hive, buff_2hive, buff_3hive

public cvar_string(cvar_num){new tempstring[3];num_to_str(cvar_num,tempstring, 3);return tempstring;}
public fcvar_string(Float:cvar_num){new tempstring[5];float_to_str(cvar_num,tempstring, 5);return tempstring;}

public plugin_init() 
{ 
	formatex(g_ModName, charsmax(g_ModName), "CommanderAI %s", VERSION)
	register_forward( FM_GetGameDescription, "GameDesc" )
	if ( ns_is_combat() )
	{
		register_plugin("Commander AI [OFF]", VERSION, "CapITanJAC")
		pause("ad")
	} 
	else 
	{
		register_plugin("Commander AI [ON]", VERSION, "CapITanJAC")
		//max
		g_MaxEnts = get_global_int(GL_maxEntities)
		
		//filename
		new datadir[81]
		get_datadir(datadir,80)
		get_mapname(mapname,40)
		format(g_FileName, 100 , "%s/commai/%s.cmai",datadir,mapname)
		
		cvar_init()
		load_buildings()
		mapinit()
		
		//Tasks
		temptime = get_pcvar_float(resupply_time)
		//set_task_ex(120.0, "reset_plugin",_,_,_,SetTask_Repeat)
		set_task_ex(1.0, "round_tick",_,_,_, SetTask_Repeat)
		set_task_ex(temptime / 2, "player_spread", 6,_,_, SetTask_Repeat) // Noshadow
		set_task_ex(10.0, "cvar_check",_,_,_, SetTask_Repeat)
		set_task(1.0, "do_build")
	}
} 

public mapinit()
{
	new ent
	while((ent = find_ent_by_class(ent,"func_resource")) != 0)
	{
		nozzles ++
	}
}

cvar_init()
{
	player_comm = register_cvar("amx_commai_comm_status", "0") // *NOTE Can change during gameplay this is because comm_mode is 1 (1:building spawn is disabled)."
	comm_mode = register_cvar("amx_commai_comm_mode", cvar_string(CVAR_COMM_MODE))
	building_cost = register_cvar("amx_commai_cost", fcvar_string(CVAR_BUILDING_COST))
	res_cost = register_cvar("amx_commai_res_cost", cvar_string(CVAR_RES_COST))
	electrify_cost = register_cvar("amx_commai_electrify_cost", fcvar_string(CVAR_ELECTRIFY_COST))
	upgrade_cost = register_cvar("amx_commai_upgrade_cost", fcvar_string(CVAR_UPGRADE_COST))
	resupply_cost = register_cvar("amx_commai_resupply_cost", fcvar_string(CVAR_RESUPPLY_COST))
	weapons_cost = register_cvar("amx_commai_weapons_cost", fcvar_string(CVAR_WEAPONS_COST))
	weapon_res_add = register_cvar("amx_commai_weapons_res_base", fcvar_string(CVAR_WEAPONS_RES_BASE))
	upgrade = register_cvar("amx_commai_upgrade", cvar_string(CVAR_UPGRADE))
	electrify = register_cvar("amx_commai_electrify_buildings", cvar_string(CVAR_ELECTRIFY_BUILDINGS))
	electrify_mode = register_cvar("amx_commai_electrify_mode", cvar_string(CVAR_ELECTRIFY_MODE))
	weapons = register_cvar("amx_commai_weapons", cvar_string(CVAR_WEAPONS))
	resupply = register_cvar("amx_commai_resupply", cvar_string(CVAR_RESUPPLY))
	resupply_time = register_cvar("amx_commai_resupply_time", fcvar_string(CVAR_RESUPPLY_TIME))
	resupply_use_wres = register_cvar("amx_commai_resupply_use_weapon_res", cvar_string(CVAR_RESUPPLY_USE_WEAPON_RES))
	armor = register_cvar("amx_commai_armor", cvar_string(CVAR_ARMOR))
	alien_buff_mode = register_cvar("amx_commai_alien_buff_mode", cvar_string(CVAR_ALIEN_BUFF))
	buff_1hive = register_cvar("amx_commai_alien_buff_1hive_ammount", fcvar_string(CVAR_OLD_1HIVE))
	buff_2hive = register_cvar("amx_commai_alien_buff_2hive_ammount", fcvar_string(CVAR_OLD_2HIVE))
	buff_3hive = register_cvar("amx_commai_alien_buff_3hive_ammount", fcvar_string(CVAR_OLD_3HIVE))
	effects = register_cvar("amx_commai_effects", cvar_string(CVAR_EFFECTS))
	delayfactor = register_cvar("amx_commai_delay_factor", fcvar_string(CVAR_DELAY))
	//CMD
	register_concmd("amx_commai_save","admin_save",ADMIN_LEVEL_A,"test")
	register_concmd("amx_commai_load", "admin_load",ADMIN_LEVEL_A,"test") 
	register_concmd("amx_commai_restart", "reset_plugin",ADMIN_LEVEL_A,"test") 
}

public round_start()
{
	//roundinprogress = true
	firstTowerBuilt = true
	ns_set_teamres(1,0.0)
	weapon_res = 10.0
	roundtime = 0
	entity_get_vector(ns_get_build("resourcetower",1,1), EV_VEC_origin, firstTowerOrigin)
	set_task(10.0, "start_vote");
	set_task_ex(4.0, "tick", 3, _, _, SetTask_Repeat)
	set_task_ex(0.1, "message_display", 25, _, _, SetTask_Repeat)
	set_task_ex(0.1, "res_add",_,_,_, SetTask_RepeatTimes, 250)
	set_task_ex(1.0, "do_upgrade", 101,_,_, SetTask_Repeat)
	set_task_ex(30.0, "do_electricity", 102,_,_, SetTask_Repeat)
}

public cvar_check()
{
	if (temptime != get_pcvar_float(resupply_time))
	{
		temptime = get_pcvar_float(resupply_time)
		restart_resupply()
	}
	else
		return
}

public restart_resupply()
{
	remove_task(6)
	remove_task(66)
	temptime = get_pcvar_float(resupply_time)
	set_task(temptime, "player_spread", 6, "", 0, "b")
	set_task(temptime / 2, "do_armor", 66, "", 0, "b")
}

public reset_plugin(id,level,cid)
{
	if (!cmd_access(id,level,cid,1))
		return PLUGIN_HANDLED
	wait_for_res = false
	spawn_interval = 0.0
	restart_resupply()
	set_task_ex(30.0, "do_upgrade")
	set_task_ex(60.0, "do_electricity")
	console_print(id,"[AMXX] CommAI - Restarted")
	return PLUGIN_HANDLED
}

public round_end()
{
	//roundinprogress = false
	roundtime = 0
	remove_task(3)
	remove_task(25)
	remove_task(101)
	remove_task(102)
}

public round_tick()
{roundtime++;}

public tick()
{
	res_tick()
	alien_buff2()
}

public res_tick()
{
	if(!is_blocked2(firstTowerOrigin))
		firstTowerBuilt = false
	
	new Float:tfs 
	tfs += ns_get_build("resourcetower",1)
	if(firstTowerBuilt)
	{
		tfs--
		weapon_res += get_pcvar_float(weapon_res_add)
		if(get_pcvar_bool(resupply_cost))//doubled for resupply
			weapon_res += get_pcvar_float(weapon_res_add)
	}
	else
	{
		weapon_res += get_pcvar_float(weapon_res_add)
		if(get_pcvar_bool(resupply_cost))//doubled for resupply
			weapon_res += get_pcvar_float(weapon_res_add)
	}
	if(get_pcvar_float(building_cost) > 0.0)
		for(new i;i<tfs;i++)
			set_task(4.0/tfs*i,"res_add")
	new Float:marines; marines += (get_playersnum()/2)
	//0.01 bonus weapon res every 4 seconds per marine (if under 100)
	if(weapon_res <= 100.0 && !get_pcvar_bool(resupply_cost))
		weapon_res += (0.1 * floatround(marines))
	if(get_pcvar_num(player_comm))
		return
	if(roundtime >= 1800)
		set_pcvar_num(electrify_mode, all)
	else
		set_pcvar_num(electrify_mode, CVAR_ELECTRIFY_MODE)
	if(roundtime >= 3600)
		set_pcvar_num(electrify, all)
	else
		set_pcvar_num(electrify, CVAR_ELECTRIFY_BUILDINGS)
}
public res_add()
{
	if(get_pcvar_num(weapons) && !get_pcvar_num(player_comm) && roundtime >= 25)
	{
		//The minimum ammount of Weapon res to keep at all times, 10 for every portal (after 50 team res).
		new weaponMultiplier = ns_get_build("team_infportal",1)
		
		new Float:halfNozzles 
		halfNozzles += nozzles
		halfNozzles /= 2
		
		if(get_pcvar_bool(resupply_cost))
			weaponMultiplier ++
		if
		(
			weapon_res < 10.0 * weaponMultiplier && ns_get_teamres(1) > 50.0
			|| !get_pcvar_bool(resupply_cost) && ns_get_teamres(1) > (weapon_res * 2)
			|| ns_get_teamres(1) - (10.0 * floatround(halfNozzles, floatround_floor)) > weapon_res
		)
		{
			weapon_res += get_pcvar_float(weapon_res_add)
			if(get_pcvar_bool(resupply_cost))//doubled for resupply
				weapon_res += get_pcvar_float(weapon_res_add)
		}
		else
		{
			weapon_res += (get_pcvar_float(weapon_res_add) / 2)
			ns_add_teamres(1,1.0)
		}
	}
	else
		ns_add_teamres(1,1.0)
}
public res_subtract(Float:amount)
{
	if(free_res())
		return
	new i
	floatround(amount)
	if(amount == ns_get_teamres(1))
		ns_set_teamres(1, 0.0)
	if(amount > 0)
		while(i<=amount && ns_get_teamres(1) > 0.0)
		{
			ns_add_teamres(1, -1.0)
			if(ns_get_teamres(1) < 0.0)
			{
				console_print(0, "[AMXX] CommAI - ERROR: Resource amount error. (Soft lock prevented)")
				return
			}
			i++
	}
}

public bool:free_res()
{
	new rts = ns_get_build("resourcetower",1)
	if(rts >= nozzles && get_pcvar_float(building_cost) > 0.0)
		return true
	else
		return false
}

public random_interval()
{
	spawn_interval = random_float(0.5, 2.5) * get_pcvar_float(delayfactor)
	set_task(spawn_interval, "do_build")
}

public do_build()
{
	spawn_interval = random_float(0.5, 2.5) * get_pcvar_float(delayfactor)
	set_task(spawn_interval, "random_interval")
	
	if ((get_pcvar_num(player_comm) == 1 && get_pcvar_num(comm_mode) == hybrid) || get_pcvar_num(comm_mode) == weapons_only)
		return
	//if (!ns_round_in_progress())
		//return
	//PRIORITIZE RES TOWERS / TURRET FACTORIES / EVERYTHING ELSE.
	new i = -1
	new Float:torigin[3]
	while ((i = find_ent_by_class(i, "func_resource")) != 0) if(is_valid_ent(i))
	{
		if(ns_get_build("team_infportal",1) < 1)
			break
		entity_get_vector(i, EV_VEC_origin, torigin)
		if(is_blocked2(torigin))
			continue
		//if(num_friends_in_radius(1,torigin,450) < 1 || num_enemies_in_radius(1,torigin,450) > 0 )
		if(	num_enemies_in_radius(1,torigin,450) > num_friends_in_radius(1,torigin,450) || !num_friends_in_radius(1,torigin,450))
			continue
		if(get_pcvar_num(res_cost))
		{
			if(ns_get_teamres(1) >= 15 * get_pcvar_float(building_cost))
			{
				wait_for_res = false
				res_subtract(15.0 * get_pcvar_float(building_cost))
				spawn_building("resourcetower",1,torigin)
				return
			}
			else
			{
				wait_for_res = true
				return//wait unil enough res.
			}
		}
		else
			break
	}
	spawned_building = false
	for(new i=0;i<STORE_MAX;i++)
	{
		if(!spawned_building)
		{
			if(g_buildings[i] > 0)
			{
				if(wait_for_res)
					continue
				
				if(is_blocked(g_buildingsf[i]))
					continue
				
				//Enemy check.
				//if(num_friends_in_radius(1,g_buildingsf[i],450) < 1 || num_enemies_in_radius(1,g_buildingsf[i],450) > 0 )
				if(	num_enemies_in_radius(1,g_buildingsf[i],450) > num_friends_in_radius(1,g_buildingsf[i],450) || !num_friends_in_radius(1,g_buildingsf[i],450))
					continue
				
				//Command center IP, and armory radius check
				if(g_buildings[i] == 26 && (num_built_in_radius("team_command",g_buildingsf[i],400) < 1 )
				|| g_buildings[i] == 12 && (num_built_in_radius("team_command",g_buildingsf[i],400) < 1 )
				|| g_buildings[i] == 2 && (num_built_in_radius("team_command",g_buildingsf[i],400) < 1 ))
					continue
				
				//Proto Check
				if(g_buildings[i] == 8 && comms() < 2)
					continue
				
				//Turret and seige turret radius check
				if((g_buildings[i] == 10 && num_built_in_radius("team_turretfactory",g_buildingsf[i],400) < 1 && num_built_in_radius("team_advturretfactory",g_buildingsf[i],400) < 1) || (g_buildings[i] == 11 && num_built_in_radius("team_advturretfactory",g_buildingsf[i],400) < 1))
					continue
				
				//RT already done.
				if(g_buildings[i] == 4)//resource tower taken care of above
					continue
				
				//Tech tree check
				if (!tech_tree(g_buildings[i]))
					continue
					
				//Spawn adv. TFs no matter what
				if(equali("team_advturretfactory",bm_list[g_buildings[i]]) || equali("team_turretfactory",bm_list[g_buildings[i]]))
				{
					if(ns_get_teamres(1) >=  25.0 * get_pcvar_float(building_cost) || !get_pcvar_num(building_cost) || free_res())
					{
						spawn_building("team_turretfactory",1,g_buildingsf[i])
						spawned_building = true
						if(get_pcvar_num(building_cost))
							res_subtract(26.0 * get_pcvar_float(building_cost))
					}
					else
						continue
				}
				else // Standard building spawn
				{
					if(ns_get_teamres(1) >= bm_list_cost[g_buildings[i]] * get_pcvar_float(building_cost) || !get_pcvar_num(building_cost) || free_res())
					{
						if( g_buildings[i] == 7 && armslabOrigin[0] == 0)
							armslabOrigin = g_buildingsf[i]
						spawn_building(bm_list[g_buildings[i]],1,g_buildingsf[i])
						spawned_building = true
						if(get_pcvar_num(building_cost) > 0)
							res_subtract(bm_list_cost[g_buildings[i]] * get_pcvar_float(building_cost))
					}
					else
						continue		
				}
			}
		}
	}
	return
}

public bool:tech_tree(name)
{
	//CC,IP,& Turrets
	if(name == 1 || name == 2 || name == 10)
		return true
		
	if(ns_get_build("team_infportal") != 0)
	{
		if(ns_get_build("resourcetower") != 0)
		{
			//TF
			if(name == 5 || name == 13)
				return true
			if(ns_get_build("team_advturretfactory"))
			{//Seige Turret
				if(name == 11)
					return true
			}
			
			//Armory
			if(name == 12 || name == 6)
				return true
			if(ns_get_build("team_advarmory") + ns_get_build("team_armory") != 0)
			{//Arms Lab
				if(name == 7)
					return true
				if(ns_get_build("team_armslab") !=0 && ns_get_build("team_advarmory") !=0)
				{
					//Prototype Lab
					if(name == 8)
						return true
				}
				//Observatory
				if(name == 9)
					return true
				if(ns_get_build("team_observatory") != 0)
				{//Phase Gate
					if(name == 3)
						return true
				}
			}
		}
	}
	return false
}

public upgrade_tf()
{
	new i, tf, tfs, classname[32]
	tfs = ns_get_build("team_turretfactory")
	for(i = 1; tf <= tfs; i++)
	{
		tf = ns_get_build("team_turretfactory", 1, i)
		entity_get_string(tf, EV_SZ_classname, classname, 31)
		if(equali(classname, "team_turretfactory"))
		{
			if (entity_get_float(tf, EV_FL_fuser1) < 1000)// Hack to check for fully built, adv. TFs seem to always be built.
				continue
			entity_set_string(tf, EV_SZ_classname, "team_advturretfactory")
			entity_set_int(tf,EV_INT_iuser3, 49)// 49 is the iuser3 for adv. tf.
		}
		tf++
	}
}

public upgrade_armory()
{
	new classname[32]
	new id = find_ent_by_class(0, "team_armory")
	entity_get_string(id,EV_SZ_classname, classname, 31)
	if(!equali(classname, "team_advarmory"))
	{
		if (entity_get_float(id, EV_FL_fuser1) < 1000)// Hack to check for fully built, adv. Armories seem to always be built.
			return
		if(get_pcvar_num(upgrade_cost) && !free_res())
			if(!upgrading[id])
			{
				Util_PlayAnimation(id, 5, 1.44)
				upgrading[id] = true
				upgradetime[id] = roundtime + 160
				return
			}	
			else
			{
				if(ns_get_teamres(1) <= 30.0 * get_pcvar_float(upgrade_cost) && roundtime < upgradetime[id])
					return	
				else
					res_subtract(30 * get_pcvar_float(upgrade_cost))
			}
		if(upgrading[id] && roundtime < upgradetime[id])
			return
		else
			if(upgrading[id])
			{
				upgrading[id] = false
				entity_set_string(id, EV_SZ_classname, "team_advarmory")
				entity_set_int(id,EV_INT_iuser3, 26)// 49 is the iuser3 for adv. ar
			
				//Plays upgrade animation
				Util_PlayAnimation(id, 4, 1.75)
				if(get_pcvar_num(effects))
					emit_sound(id,CHAN_AUTO,"misc/b_marine_deploy.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
			}
	}
}

public do_upgrade()
{
	if (get_pcvar_num(upgrade) == disabled && ns_round_in_progress() || !ns_round_in_progress())
		return
		
	if(roundtime >= 500)
		upgrade_armory()
	
	upgrade_tf()
}

public electricity(bool:one)
{
	if(one)
		if(ns_get_teamres(1) < 30.0 * get_pcvar_float(electrify_cost) && get_pcvar_float(electrify_cost) > 0.0 && !free_res())
			return
	new id, dec = get_pcvar_num(electrify)
	if(get_pcvar_num(electrify) == both)
		dec = random_num(RTs, TFs)
	if(elec_RTs >= ns_get_build("resourcetower"))
		dec = TFs
	if(dec == RTs)
	{
		//For RTs
		if(get_pcvar_num(electrify) == RTs || get_pcvar_num(electrify) == both)
		{
			new rt, rts = ns_get_build("resourcetower")
			for(rt = random_num(0,rts+1); rt<=rts;rt++)
			{
				if(elec_RTs >= rts && one)
					break
				if(rt == rts && one)//Keep checking until found
					rt = random_num(0,rts+1)
				id = ns_get_build("resourcetower",1,rt)
				entity_get_float(id, EV_FL_fuser1)
				if(ns_get_mask(id, MASK_ELECTRICITY) || entity_get_float(id, EV_FL_fuser1) != 1000)
					continue
				if (get_pcvar_float(electrify_cost))
					if(ns_get_teamres(1) >= 30.0 * get_pcvar_float(electrify_cost) || free_res())
					{
						ns_set_mask(id, MASK_ELECTRICITY, 1)
						if(!free_res())
							res_subtract(30 * get_pcvar_float(electrify_cost))
						if(get_pcvar_num(effects))
							emit_sound(id,CHAN_AUTO,"misc/connect.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
						elec_RTs++
						if(one)
							break
					}
					else
						continue
				else
				{
					ns_set_mask(id, MASK_ELECTRICITY, 1)
					if(get_pcvar_num(effects))
						emit_sound(id,CHAN_AUTO,"misc/connect.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
					if(one)
						break
				}
			}
		}
	}
	if(dec == TFs)
	{
		//For TFs
		if(get_pcvar_num(electrify) == TFs || get_pcvar_num(electrify) == both)
		{
			new tf, tfs = ns_get_build("team_advturretfactory",1)
			for(tf = random_num(0,tfs+1); tf<=tfs;tf++)
			{
				if(elec_TFs >= tfs && one)
					break
				if(tf == tfs && one)//Keep checking until found
					tf = random_num(0,tfs+1)
				id = ns_get_build("team_advturretfactory",1,tf)
				
				if(ns_get_mask(id, MASK_ELECTRICITY) || entity_get_float(id, EV_FL_fuser1) != 1000 )
					continue
				if (get_pcvar_num(electrify_cost))
					if(ns_get_teamres(1) >= 30.0 * get_pcvar_float(electrify_cost) || free_res())
					{
						ns_set_mask(id, MASK_ELECTRICITY, 1)
						if(!free_res())
							res_subtract(30 * get_pcvar_float(electrify_cost))
						if(get_pcvar_num(effects))
							emit_sound(id,CHAN_AUTO,"misc/connect.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
						elec_TFs++
						if(one)
							break
					}
					else
						continue
				else
				{
					ns_set_mask(id, MASK_ELECTRICITY, 1)
					if(get_pcvar_num(effects))
						emit_sound(id,CHAN_AUTO,"misc/connect.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
					if(one)
						break
				}
			}
		}
	}
	if(dec == all)// For shits and giggles
	{
		if(ns_get_teamres(1) < 30.0 && get_pcvar_float(electrify_cost) > 0.0 && !free_res())
			return
		
		new id =-1, blds[13] 
		if(!one)
		{
			new ii
			
			if(get_pcvar_num(electrify_cost))
				ii = random_num(0,sizeof(bm_list))
		
			for(new i = ii;i<sizeof(bm_list)-1; i++)// Ran once for every building category
			{
				blds[i] = ns_get_build(bm_list[i])//Finds the total number of buildings per catagory.
				new xx
				if(get_pcvar_float(electrify_cost) > 0.0)
					xx = random_num(0,blds[i])
				for(new x = xx;x<=blds[i];x++)// Ran once for every building in category
				{
					// Ran once for every building	
					id = ns_get_build(bm_list[i], 1, x)
					if(ns_get_mask(id, MASK_ELECTRICITY) || ns_get_teamres(1) < 30.0 * get_pcvar_float(electrify_cost) && get_pcvar_num(electrify_cost)) 
						continue
					
					ns_set_mask(id, MASK_ELECTRICITY, 1)
					if( get_pcvar_float(electrify_cost) > 0.0 && !free_res())
						res_subtract(30 * get_pcvar_float(electrify_cost))
					if(get_pcvar_num(effects))
						emit_sound(id,CHAN_AUTO,"misc/connect.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
				}
			}
		}
		else
		{
			new i, x
			i = random_num(0,sizeof(bm_list))
			blds[i] = ns_get_build(bm_list[i])//Finds the total number of buildings per catagory.
			x = random_num(0,blds[i])
			id = ns_get_build(bm_list[i], 1, x)
			if(ns_get_mask(id, MASK_ELECTRICITY) || ns_get_teamres(1) < 30.0 && get_pcvar_float(electrify_cost) > 0.0 && !free_res())
				return
			ns_set_mask(id, MASK_ELECTRICITY, 1)
			if(get_pcvar_float(electrify_cost) > 0.0 && !free_res())
				res_subtract(30 * get_pcvar_float(electrify_cost))
			if(get_pcvar_num(effects))
				emit_sound(id,CHAN_AUTO,"misc/connect.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
		}
	}
}

public do_electricity()
{
	//Res reserve check if "all selected"
	if(ns_get_teamres(1) <= 50.0 && get_pcvar_float(electrify_cost) > 0.0 && get_pcvar_num(electrify_mode) == all && !free_res() || get_pcvar_num(electrify) == 0)
		return
	if(get_pcvar_num(electrify_mode) != all)
		electricity(true)
	else
		electricity(false)
}

public player_spread()
{
	if(!get_pcvar_num(resupply) || get_pcvar_num(comm_mode) == hybrid && get_pcvar_num(player_comm))
		return
	new bool:resupply
	if(resupplytic)
		resupply = true
	new index
	while(index < get_maxplayers())
	{
		if(resupply)
		{
			set_task(random_float(0.0,2.0), "do_resupply", index)
			set_task(random_float(0.0,1.0), "do_armor", index)
			resupplytic = false
		}
		else
		{
			set_task(random_float(0.0,1.0), "do_armor", index)
			resupplytic = true
		}
		index ++
	}
}

public do_resupply(index)
{
	new Float:temphp
	new Float:origin[3]
	if( (!is_user_alive(index)) || (get_team(index) != 1)  || !ns_get_build("team_infportal") || !(ns_get_build("team_advarmory") + ns_get_build("team_armory")))
		return
	
	if(ns_get_mask(index,MASK_DIGESTING) || ns_get_mask(index, MASK_TOPDOWN))
		return // Player is being digested, or commander dont give a anything..
	entity_get_vector(index, EV_VEC_origin,origin)
	temphp = entity_get_float(index, EV_FL_health)
	if(temphp <= 99.0) 
	{
		supply(0, origin)
		return
	}
	else
	{
		//Give ammo code by Noshadow
		//Give ammo as needed, similiar to combat resupply
		new userweap, ammo, playerAmmo, playerClip
		userweap = get_user_weapon(index, playerClip, playerAmmo)
		if(!userweap || userweap == WEAPON_NONE)
			return
		switch(userweap)
		{
			case WEAPON_PISTOL:ammo = 10
			case WEAPON_LMG:ammo = 50
			case WEAPON_SHOTGUN:ammo = 8
			case WEAPON_HMG:ammo = 125
			case WEAPON_GRENADE_GUN: ammo = 8
		}
		if(!ammo)
			return
		if ( playerAmmo <= ammo)
			supply(1, origin)
		if ( playerAmmo < ammo * 2 && userweap != WEAPON_HMG)
			if(random_num(0,1) == 1)
				supply(1, origin)		
		
		//New catalyst drop (base 5%, +5% for every command station[66 * for non-res])
		new roll 
		if(comms() < 2)
			return
		
		roll = random(30) + 1
		if(get_pcvar_num(resupply_cost) == 0)
			roll = random(50) + 1
		if(comms() >= roll)
			supply(2, origin)
	}
	return
}
/*public hook_ammo(index)
{
	if(!is_user_bot(index))
		return
	new Float:origin[3]
}*/
public do_armor(index)
{	
	if( !get_pcvar_num(armor) || !ns_get_build("team_infportal") || !(ns_get_build("team_advarmory") + ns_get_build("team_armory")) || !ns_get_build("team_armslab") || !comms())
		return
	if(get_team(index) !=1 || !is_user_alive(index) || ns_get_mask(index,MASK_DIGESTING) || ns_get_mask(index, MASK_TOPDOWN))				
		return
	
	new Carmor, Narmor, armorMult, Marmor
	//Gets current armor
	Carmor = get_user_armor(index)
	//Finds max armor
	
	if(ns_get_mask(index, MASK_ARMOR3))
		armorMult = 3
	else
		if(ns_get_mask(index, MASK_ARMOR2))
			armorMult = 2
		else
			if(ns_get_mask(index, MASK_ARMOR1))
				armorMult = 1
	if(ns_get_mask(index, MASK_HEAVYARMOR))
		Marmor = 200 + (armorMult * 50)//Marmor = 200 + (comms() * 50)
	else
		Marmor = 30 + (armorMult * 20)//Marmor = 30 + (comms() * 20)
	if(ns_get_mask(index,MASK_JETPACK))
		Marmor += 10
	
	Narmor = Carmor + (comms() * 5)
	
	if(Carmor >= Marmor)
		return
	//Sets armor
	if(Narmor < Marmor)
	{
		set_user_armor(index, Narmor)
		if(get_pcvar_num(effects) == 1)
		{
			emit_sound(index,CHAN_AUTO,"weapons/welderstop.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
		}
		return
	}
	else if(Narmor >= Marmor)
	{
		set_user_armor(index, Marmor)
		if(get_pcvar_num(effects) == 1)
		{
			emit_sound(index,CHAN_AUTO,"weapons/welderstop.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
		}
		return
	}
}

public supply(supply_type, Float:origin[3])
{
	if(supply_type < 2)
		if(num_built_in_radius("team_armory", origin, 400) > 0 || num_built_in_radius("team_advarmory", origin, 400) > 0) //Do not spawn if armory near by.
			return
	
	new ent, Float:cost
	switch(supply_type)
	{
		case 0: {ent = create_entity("item_health"); cost = 2.0;}
		case 1: {ent = create_entity("item_genericammo"); cost = 1.0;}
		case 2: {ent = create_entity("item_catalyst"); cost = 3.0;}
	}
	entity_set_origin(ent,origin)
	if(free_res())
		cost = 0.0	
	
	if(get_pcvar_bool(resupply_use_wres))
	{
		if(weapon_res >= cost * get_pcvar_float(resupply_cost) || supply_type == 2 && weapon_res >= 50.0 || !get_pcvar_float(resupply_cost) || free_res())
		{
			DispatchSpawn(ent)
			
			if(weapon_res >= cost && !free_res())
				weapon_res -= cost * get_pcvar_float(resupply_cost)
			if(get_pcvar_num(effects))
			{
				ns_fire_ps(ns_get_ps_id("PhaseInEffect"), origin)
				emit_sound(ent,CHAN_AUTO,"misc/phasein.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
			}
		}
	}
	else 
	{
		if(ns_get_teamres(1) >= cost * get_pcvar_float(resupply_cost) || !get_pcvar_float(resupply_cost) || free_res())
		{
			DispatchSpawn(ent)
			
			if(ns_get_teamres(1) >= cost * get_pcvar_float(resupply_cost) && !free_res())
				ns_add_teamres(1, (cost * get_pcvar_float(resupply_cost)) * -1 )
			if(get_pcvar_num(effects))
			{
				ns_fire_ps(ns_get_ps_id("PhaseInEffect"), origin)
				emit_sound(ent,CHAN_AUTO,"misc/phasein.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
			}
				
		}
	}
}

public client_spawn(id) 
{
	if (get_team(id) == 1) 
	{
		do_weapons(id)
		do_pl_armor(id)
	}
	else
		alien_buff(id)
}
public pfn_think(id)//For buildings
{
	player_upgrades(id)
}
public client_PostThink(id)//For players
{
	player_upgrades(id)
}
public player_upgrades(id)
{
	if (get_pcvar_num(weapons) == disabled || get_pcvar_num(comm_mode) == weapons_only || get_pcvar_num(player_comm) && get_pcvar_num(comm_mode) == hybrid)
		return
	if(get_team(id) !=1 || !is_valid_ent(id))
		return
	if(!ns_round_in_progress())
		return
	if(!ns_get_build("team_armslab"))
		return
	switch(comms())
	{
		case 1:
		{
			ns_set_mask(id, MASK_WEAPONS1, 1)
			ns_set_mask(id, MASK_ARMOR1, 1)
		}
		case 2: 
		{
			ns_set_mask(id, MASK_WEAPONS1, 1)
			ns_set_mask(id, MASK_ARMOR1, 1)
			
			ns_set_mask(id, MASK_WEAPONS2, 1)
			ns_set_mask(id, MASK_ARMOR2, 1)
		}
		default: 
		{
			ns_set_mask(id, MASK_WEAPONS1, 1)
			ns_set_mask(id, MASK_ARMOR1, 1)
			
			ns_set_mask(id, MASK_WEAPONS2, 1)
			ns_set_mask(id, MASK_ARMOR2, 1)
			
			ns_set_mask(id, MASK_WEAPONS3, 1)
			ns_set_mask(id, MASK_ARMOR3, 1)
		}
	}
}

public do_weapons(id)
{
	if(!get_pcvar_num(weapons) || get_pcvar_num(weapons) == bots_only  && !is_user_bot(id) || !ns_get_build("team_armory") && !ns_get_build("team_advarmory") || !comms())
		return
		
	//	New player spawn code by Noshadow and then modified by Random1 and CapITanJAC
	//	33% Chance of Heavy Armor with a Proto
	//	33% Chance of Jet Pack with a Proto
	//	Random weapon given (No hard-coded cycle)
	if(roundtime >= 60)
		ns_give_item(id, "weapon_grenade")
	//Welder
	if(weapon_res >= 5 * get_pcvar_float(weapons_cost) || !get_pcvar_num(weapons_cost) || free_res())
	{
		ns_give_item(id, "weapon_welder")
		if(get_pcvar_num(weapons_cost) && !free_res())
			weapon_res -= 5 * get_pcvar_float(weapons_cost)
	}
	new wid
	if(is_user_bot(id))
	{
		wid = ns_get_weapon(id, WEAPON_WELDER)
		ns_set_weap_dmg(wid, 40.0)// RCBots LOVE the welder
	}
	
	//Adv. weapons ONLY with adv armory. --> Do same as w/ Proto tech
	if(!(ns_get_build("team_advarmory") + ns_get_build("team_armory")))
		return
		
	new rnumWeap
	
	if(ns_get_build("team_advarmory"))
		if(weapon_res >= 100 * get_pcvar_float(weapons_cost))
			rnumWeap = random_num(2,3)
		else 
			rnumWeap = random(4)
	else
		if(weapon_res >= 100 * get_pcvar_float(weapons_cost))
			rnumWeap = 1
		else
			rnumWeap = random(2)
	switch(rnumWeap)
	{
		case 0: {}//YOU GET NOTHING, YOU LOSE; GOOD DAY SIR!
		case 1: if( weapon_res >= 10 * get_pcvar_float(weapons_cost) || !get_pcvar_num(weapons_cost) || free_res())
			{
				ns_give_item(id, "weapon_shotgun")
				if(get_pcvar_num(weapons_cost) && !free_res())
					weapon_res -= 10 * get_pcvar_float(weapons_cost)
			}
		case 2: if( weapon_res >= 15 * get_pcvar_float(weapons_cost) || !get_pcvar_num(weapons_cost) || free_res())
			{
				ns_give_item(id, "weapon_heavymachinegun")
				if(get_pcvar_num(weapons_cost) && !free_res())
					weapon_res -= 15 * get_pcvar_float(weapons_cost)
			}
		case 3: if( weapon_res >= 15 * get_pcvar_float(weapons_cost) || !get_pcvar_num(weapons_cost) || free_res())
			{
				ns_give_item(id, "weapon_grenadegun")
				if(get_pcvar_num(weapons_cost) && !free_res())
					weapon_res -= 15 * get_pcvar_float(weapons_cost)
			}
	}
	if(rnumWeap)
	{//If weapon was givin
		ns_give_item(id,"item_genericammo")
		ns_give_item(id,"item_genericammo")
		ns_give_item(id,"item_genericammo")
	}
	if(!ns_get_build("team_prototypelab", 1)) 
		return
	
	new rnumProto = random(4)
	if(get_pcvar_num(comm_mode) == weapons_only || comms() > 2  || !get_pcvar_num(weapons_cost) || free_res())
		rnumProto = random_num(1,2)
	switch(rnumProto)
	{
		case 0:{}//YOU GET NOTHING, YOU LOSE; GOOD DAY SIR!
		case 1: if( weapon_res >= 10 * get_pcvar_float(weapons_cost) || !get_pcvar_num(weapons_cost) || free_res())
			{
				ns_give_item(id, "item_jetpack")
				if(get_pcvar_num(weapons_cost) && !free_res())
					weapon_res -= 10 * get_pcvar_float(weapons_cost)
			}
		case 2: if( weapon_res >= 15 * get_pcvar_float(weapons_cost) || !get_pcvar_num(weapons_cost) || free_res())
			{
				ns_give_item(id, "item_heavyarmor")
				if(get_pcvar_num(weapons_cost) && !free_res())
					weapon_res -= 15 * get_pcvar_float(weapons_cost)
			}
	}
	new rnumMines = random(3)//33% at 1 comm chair, 50% at 2, 66% 3
	rnumMines -= comms()
	if(get_pcvar_num(comm_mode) == weapons_only || ns_get_teamres(1) >= 100 || weapon_res >= 50)
		rnumMines = 0 //100%
	if (rnumMines <= 0)
			if( weapon_res >= 10 * get_pcvar_float(weapons_cost) || !get_pcvar_num(weapons_cost) || free_res())
			{
				ns_give_item(id, "weapon_mine")
				if(get_pcvar_num(weapons_cost) && !free_res())
					weapon_res -= 10 * get_pcvar_float(weapons_cost)
			}
}

public do_pl_armor(id)
{
	if( (!is_user_alive(id)) || (get_team(id) != 1)  || ns_get_build("team_infportal") == 0)
		return
	if(ns_get_mask(id,MASK_DIGESTING) || ns_get_mask(id, MASK_TOPDOWN))
		return // Player is being digested, or commander dont upgrade anything..

	new masks[6] =
	{
		8, //Weapons 1
		16,//Weapons 2
		32,//Weapons 3
		64,//Armor 1
		128,//Armor 2
		256//Armor 3
	}

	new coms = comms()
	if(ns_get_build("team_armslab") == 0)
		coms = 0
	set_user_armor(id, 30 + (coms * 20))
	if(ns_get_mask(id, MASK_JETPACK))
		set_user_armor(id,40 + (coms * 20))
	if(ns_get_mask(id, MASK_HEAVYARMOR))
		set_user_armor(id, 200 + (coms * 50))
	ns_set_mask(id, masks[coms+2],1)
}
// Legacy Alien buff. (res on death)
public alien_buff(id)
{
	if(get_pcvar_num(alien_buff_mode) != both && get_pcvar_num(alien_buff_mode) != old)
		return
	new hive_number = ns_get_build("team_hive", 1)
	new Float: ammount = get_pcvar_float(buff_3hive)
	switch(hive_number)
		{
			//No 0 hives
			case 1: ammount = get_pcvar_float(buff_1hive)
			case 2: ammount = get_pcvar_float(buff_2hive)
		}
	ns_add_res(id, ammount)
}

public alien_buff2()
{//New Alien buff
	if(!get_pcvar_num(alien_buff_mode) || get_pcvar_num(alien_buff_mode) == old)	
			return
	for(new id;id < get_maxplayers(); id++)
	{
		if(get_team(id) == 1)
			continue
			
		if(get_pcvar_num(alien_buff_mode) == bots_only || get_pcvar_num(alien_buff_mode) == bot_gorges_only && !is_user_bot(id) )
			continue
			
		if(get_pcvar_num(alien_buff_mode) == gorges_only || get_pcvar_num(alien_buff_mode) == bot_gorges_only && ns_get_class(id) != CLASS_GORGE)
			continue
		
		if(ns_get_res(id) > 50.0 && ns_get_class(id) != CLASS_GORGE || ns_get_class(id) == CLASS_GORGE && ns_get_res(id) > 90.0)
			continue
			
		ns_add_res(id,(1.0 / ns_get_build("team_hive")))
	}
}
public client_changeclass(id, nclass, oclass)	//lets hope this actually detects commander changes properly, if not have to think of an alternate method
{
	if ( !is_user_connected(id) ) return	//again shouldn't happen, but there to prevent runtime errors
	new plugin_state = get_pcvar_num(player_comm)
	
	if ( nclass == CLASS_COMMANDER && !temp_disable && !plugin_state  && get_pcvar_num(comm_mode) == hybrid || get_pcvar_num(comm_mode) == disabled)	//I know your looking at this going huh?
	{
		temp_disable = true
		set_pcvar_num(player_comm, enabled)
		set_pcvar_num(upgrade, disabled)
		set_pcvar_num(electrify, disabled)
		set_pcvar_num(weapons, disabled)
		set_pcvar_num(resupply, disabled)
		own_buildings(id)
		return
	}
	
	if ( oclass == CLASS_COMMANDER && temp_disable && plugin_state  && get_pcvar_num(comm_mode) == hybrid)
	{
		temp_disable = false
		set_pcvar_num(player_comm, disabled)
		set_pcvar_num(upgrade, CVAR_UPGRADE)
		set_pcvar_num(electrify, CVAR_ELECTRIFY_BUILDINGS)
		set_pcvar_num(weapons, CVAR_WEAPONS)
		set_pcvar_num(resupply, CVAR_RESUPPLY)
		own_buildings()
		return
	}
}

public client_disconnected(id,bool:droped,message[])
{
	if(is_user_bot(id) || get_team(id) != 1)
		return
	client_changeclass(id, CLASS_MARINE, ns_get_class(id))
}
public message_display()
{
	new player
	const MESSAGELENGTH = (32 + 15)
	new message[MESSAGELENGTH + 1]
	format(message, MESSAGELENGTH, "Weapon Resources: %.1f", weapon_res)
	while(player < get_maxplayers())
	{
		if(!is_user_bot(player) && get_pcvar_bool(weapons_cost) && !get_pcvar_bool(player_comm))
			if(get_team(player) == 1 && !ns_get_mask(player, MASK_DIGESTING))//Marines
			{
				set_hudmessage(0, 175, 210, 0.3, 0.03, 0, 0.0, 12.0, 0.0, 0.0, 4) 
				show_hudmessage(player, message)
			}
		player ++
	}
}


own_buildings(owner=0)//0 for random, or player id to own all marine buildings
{
	new id =-1, blds[13]
	for(new i=1;i<=12; i++)// Ran once for every building category
	{
		blds[i] = ns_get_build(bm_list[i])//Finds the total number of buildings per catagory.
		
		for(new x;x<=blds[i];x++)// Ran once for every building in category
		{
			// Ran once for every building	
			id = ns_get_build(bm_list[i], 1, x)
			if(!owner)
			{
				new player_id
				while(get_team(player_id) != 1)
					player_id = random(get_maxplayers())
				ns_set_struct_owner(id, player_id)//Random players own buildings
			}
			else
			ns_set_struct_owner(id, owner)//Commander Owns all buildings
		}
	}
}
save_to_file()
{
	if(file_exists(g_FileName))
		delete_file(g_FileName)
		
	new l_newline[90]
	new Float:origin[3]
	new classname[32]
	new iclassname
	for(new i=1 ;i<=g_MaxEnts ;i++)  if( is_valid_ent(i) )
	{
		entity_get_string(i, EV_SZ_classname, classname, charsmax(classname))
		iclassname = classname_to_num(classname)
		if( iclassname > 0 )
		{
			entity_get_vector(i, EV_VEC_origin, origin)
			format(l_newline, charsmax(l_newline), "%d %f %f %f", iclassname, origin[0], origin[1], origin[2])
			write_file (g_FileName, l_newline)
		}
	}
	load_buildings()
}

load_buildings()
{
	arrayset(g_buildings, 0, charsmax(g_buildings))
	
	if(!file_exists(g_FileName))
	{
		console_print(0, "[AMXX] CommAI - ERROR: No building placement file found for map %s.", mapname)
		return PLUGIN_HANDLED
	}
	console_print(0, "[AMXX] CommAI - Successfully detected building placement file for map %s. Loading...", mapname)
	new store_pos = 0
	new szText[256] , line = 0 , k = 0//file handling code from:{ One Name Plugin By: Suicid3 }
	new szTempClass[30] , szTempX[30], szTempY[30], szTempZ[30]
	while(read_file( g_FileName , line++ , szText , 255 , k))
	{
		if( (szText[0] == ';') || !k) continue

		parse( szText , szTempClass , 29 , szTempX , 29 , szTempY , 29 , szTempZ , 29)
		
		g_buildings[store_pos] = str_to_num(szTempClass)
		g_buildingsf[store_pos][0] = str_to_float(szTempX)
		g_buildingsf[store_pos][1] = str_to_float(szTempY)
		g_buildingsf[store_pos][2] = str_to_float(szTempZ)
		
		store_pos++
	}
	console_print(0, "[AMXX] CommAI - Found %i buildings in file %s.", store_pos, g_FileName)
	return PLUGIN_HANDLED
}

classname_to_num(classname[]) 
{
	for(new i=0;i<BUILDING_CONV_MAX;i++)
		if(equali(bm_list[i],classname))
			return i
	return 0
}

//http://www.amxmodx.org/forums/viewtopic.php?t=14141
//http://www.nsmod.org/forums/index.php?showtopic=1345
spawn_building(classname[],team_id,Float:origin[3]) 
{ 
	new ent = create_entity(classname)
	entity_set_origin(ent,origin)
	entity_set_float(ent, EV_FL_fuser1, 0.0)
	entity_set_float(ent, EV_FL_fuser2, 500.0)
	entity_set_int(ent, EV_INT_team, team_id)
	DispatchSpawn(ent)
	if(equali(classname, "team_armslab"))
		ns_set_mask(ent, MASK_SELECTABLE, 0)
	new player_id
	while(get_team(player_id) != 1)
		player_id = random(get_maxplayers())
	ns_set_struct_owner(ent, player_id)//Random Building owner
	
	if(get_pcvar_num(effects) == 1)
	{
		if(!equali(classname, "team_command"))
		{
			new Float:angle[3]
			new Float:x = 0.0
			new Float:y = random_float(0.0, 360.0)
			new Float:z = 0.0
			angle[0] = x
			angle[1] = y
			angle[2] = z
			entity_set_vector(ent,EV_VEC_angles, angle)
		}
		new Float:PSorigin[3]; PSorigin[0] = origin[0];PSorigin[1] = origin[1];PSorigin[2] = origin[2] + 50.0;
		ns_fire_ps(ns_get_ps_id("PhaseInEffect"), PSorigin)
		emit_sound(ent,CHAN_AUTO,"misc/phasein.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM)
	}
	
	return// PLUGIN_HANDLED 
}

is_blocked(Float:origin[3]) 
{
	new Float:torigin[3]
	for(new i=1;i<=g_MaxEnts;i++)  if(is_valid_ent(i))
	{
		entity_get_vector(i, EV_VEC_origin, torigin)
		if(origin[0] == torigin[0] && origin[1] == torigin[1])
			return true
	}
	return false
}

is_blocked2(Float:origin[3]) 
{
	new Float:torigin[3]
	for(new i=1;i<=g_MaxEnts;i++)  if(is_valid_ent(i))
	{
		entity_get_vector(i, EV_VEC_origin, torigin)
		if(origin[0] == torigin[0] && origin[1] == torigin[1])
		{
			new classname[32]
			entity_get_string(i,EV_SZ_classname,classname,31)
			if(equali("resourcetower",classname) || equali("alienresourcetower",classname))
				return true
		}
	}
	return false
}

stock comms()//Returns the number of command stations
{
	new stations = 0
	stations += ns_get_build("team_command")
	if(stations >= 3)
		return 3
	else
		return stations
}

//closest classname, can be used to find distance from potential turret to the closest existing turret factory
//60,000 = classname not found
stock dist_classname_to_origin(classname[],Float:origin[3]) 
{
	new i = -1
	new dist = 60000
	new tdist
	new Float:torigin[3]
	while ((i = find_ent_by_class(i, classname)) != 0) if(is_valid_ent(i))
	{
		entity_get_vector(i, EV_VEC_origin, torigin)
		tdist = vector_distance(origin,torigin)
		if(tdist < dist)
			dist = tdist
	}
	return dist
}

//could be used to prevent spam
stock num_classnames_in_radius(classname[],Float:origin[3],radius) 
{
	new i = -1
	new num = 0
	new tdist
	new Float:torigin[3]
	while ((i = find_ent_by_class(i, classname)) != 0) if(is_valid_ent(i))
	{
		entity_get_vector(i, EV_VEC_origin, torigin)
		tdist = vector_distance(origin,torigin)
		if(tdist <= radius)
			num++
	}
	return num
}

num_built_in_radius(classname[],Float:origin[3],radius) 
{
	new maxbuild = ns_get_build(classname,1,0)
	new num = 0
	new Float:tdist
	new Float:torigin[3]
	new id
	for(new j = 1;j<=maxbuild;j++)
	{
		id = ns_get_build(classname,1,j)
		entity_get_vector(id, EV_VEC_origin, torigin)
		tdist = vector_distance(origin,torigin)
		if(tdist <= float(radius))
			num++
	}
	return num
}

//could be used to make sure that some one is there to build it
num_friends_in_radius(team,Float:origin[3],radius) 
{
	new num = 0
	new Float:tdist
	new Float:torigin[3]
	for (new i=1;i<=get_maxplayers();i++)
	{
		if (is_user_alive(i) && (ns_get_mask(i,MASK_DIGESTING) == 0 || ns_get_class(i) == CLASS_ONOS) && get_team(i) == team && ns_get_class(i) != CLASS_COMMANDER) // Is an alive, non digesting marine. (armory heal by mahnsawce)
		{
			entity_get_vector(i, EV_VEC_origin, torigin)
			tdist = vector_distance(origin,torigin)
			if(tdist <= float(radius))
				num++
		}
	}
	return num
}

num_enemies_in_radius(team,Float:origin[3],radius) 
{
	new num = 0
	new Float:tdist
	new Float:torigin[3]
	for (new i=1;i<=get_maxplayers();i++)
	{
		if (is_user_alive(i) && (ns_get_mask(i,MASK_DIGESTING) == 0 || ns_get_class(i) == CLASS_ONOS) && get_team(i) != team && ns_get_class(i) != CLASS_COMMANDER) // Is an alive, non digesting marine. (armory heal by mahnsawce)
		{
			entity_get_vector(i, EV_VEC_origin, torigin)
			tdist = vector_distance(origin,torigin)
			if(tdist <= float(radius))
				num++
		}
	}
	return num
}

Util_PlayAnimation(index, sequence, Float: framerate = 1.0) 
{ 
	if(get_pcvar_num(effects) == disabled)
		return
	
	entity_set_float(index, EV_FL_animtime, get_gametime())
	entity_set_float(index, EV_FL_framerate,  framerate)
	entity_set_float(index, EV_FL_frame, 0.0) 
	entity_set_int(index, EV_INT_sequence, sequence)
} 

//http://hpb-bot.bots-united.com/botmans_forum/2%20Bot%20developer's%20discussions/3807.txt
public admin_save(id,level,cid) 
{
	if (!cmd_access(id,level,cid,1))
		return PLUGIN_HANDLED
	save_to_file()
	console_print(id,"[AMXX] CommAI - Saved")
	return PLUGIN_HANDLED
}
public admin_load(id,level,cid) 
{
	if (!cmd_access(id,level,cid,1))
		return PLUGIN_HANDLED
	load_buildings()
	console_print(id,"[AMXX] CommAI - Loaded")
	return PLUGIN_HANDLED
}

public start_vote()
{	
	new menu = menu_create("\rDo You Want a Bot Commander?", "menu_handler")
	menu_additem(menu, "\wYes", "1", 0)
	menu_additem(menu, "\wNo", "2", 0)
	menu_addblank(menu, 0)
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	
	new inum = get_playersnum()
	for(new i = 1; i < inum; i++)
	{
		if(ns_get_class(i) != CLASS_MARINE || !is_user_connected(i) || !is_user_alive(i))
			continue
		menu_display(i, menu, 0, 15)
	}
	
	set_task(15.0, "finish_vote")
	
	choises[1] = choises[2] = 0
	
	return
}

public menu_handler(id, menu, item)
{
	if(ns_get_class(id) != CLASS_MARINE || !is_user_connected(id) || !is_user_alive(id))
		return PLUGIN_HANDLED
	if (item == MENU_EXIT)
	{
		menu_cancel(id)
		return PLUGIN_HANDLED
	}
	
	new data[6], name[32]
	new access, callback
	
	menu_item_getinfo(menu, item, access, data, 5, _, _, callback)
	
	new key = str_to_num(data)
	get_user_name(id, name, 31)
	
	switch (key) 
	{
		case 1: 
		{
			client_print (0, print_chat, "[AMXX] %s voted Yes", name);
		}
		case 2:
		{
			client_print (0, print_chat, "[AMXX] %s voted No", name);
		}
	}
	
	++choises[key]
	
	menu_cancel(id)
	return PLUGIN_HANDLED
}

public finish_vote()
{
	if(choises[1] > choises[2])
	{
		client_print(0, print_chat, "Bot Commander ^"ON^" won with %d votes", choises[1])
		server_cmd("evobot commandermode always")
	}
	else
	{
		server_cmd("evobot commandermode never")
	}
}  

public GameDesc( ) 
{ 
	forward_return(FMV_STRING, g_ModName) 
	return FMRES_SUPERCEDE
}

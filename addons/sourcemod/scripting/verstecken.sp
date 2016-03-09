//includes
#include <cstrike>
#include <sourcemod>
#include <sdktools>
#include <smartjaildoors>

//Compiler Options
#pragma semicolon 1

#define PLUGIN_VERSION   "0.1"

new freezetime;
new roundtime;
new roundtimenormal;
new votecount;
new HideRound;
new RoundLimits;

new FogIndex = -1;
new Float:mapFogStart = 0.0;
new Float:mapFogEnd = 150.0;
new Float:mapFogDensity = 0.99;

new Handle:LimitTimer;
new Handle:HideTimer;
new Handle:WeaponTimer;
new Handle:HideMenu;
new Handle:roundtimec;
new Handle:roundtimenormalc;
new Handle:freezetimec;
new Handle:RoundLimitsc;
new Handle:g_wenabled=INVALID_HANDLE;
new Handle:g_hideprefix=INVALID_HANDLE;
new Handle:g_hidecmd=INVALID_HANDLE;
new Handle:cvar;

new bool:IsHide;
new bool:StartHide;

new String:voted[1500];
new String:g_whideprefix[64];
char g_whidecmd[64];


public Plugin myinfo = {
	name = "MyJailbreak - HideintheDark",
	author = "shanapu & Floody.de, fransico",
	description = "Jailbreak Hide script",
	version = PLUGIN_VERSION,
	url = ""
};



public OnPluginStart()
{
	// Translation
	LoadTranslations("verstecken.phrases");
	
	RegAdminCmd("sm_sethide", SetHide, ADMFLAG_GENERIC);
	
	CreateConVar("sm_hide_version", "PLUGIN_VERSION", "The version of the SourceMod plugin MyJailBreak - War", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_wenabled = CreateConVar("sm_hide_enable", "1", "0 - disabled, 1 - enable war");
	g_hideprefix = CreateConVar("sm_hide_prefix", "war", "Insert your Jailprefix. shown in braces [war]");
	g_hidecmd = CreateConVar("sm_hide_cmd", "!verstecken", "Insert your 2nd chat trigger. !war still enabled");
	roundtimec = CreateConVar("sm_hide_roundtime", "5", "Round time for a single war round");
	roundtimenormalc = CreateConVar("sm_nohide_roundtime", "12", "set round time after a war round zour normal mp_roudntime");
	freezetimec = CreateConVar("sm_hide_freezetime", "30", "Time freeze T");
	RoundLimitsc = CreateConVar("sm_hide_roundsnext", "3", "Runden nach Krieg oder Mapstart bis Krieg gestartet werden kann");
	

	GetConVarString(g_hideprefix, g_whideprefix, sizeof(g_whideprefix));
	GetConVarString(g_hidecmd, g_whidecmd, sizeof(g_whidecmd));
	
	AutoExecConfig(true, "MyJailbreak_Hide");
	
	IsHide = false;
	StartHide = false;
	votecount = 0;
	HideRound = 0;
	
	HookEvent("round_start", RoundStart);
	HookEvent("player_say", PlayerSay);
	HookEvent("round_end", RoundEnd);
}


public OnMapStart()
{
	//new String:voted[1500];

	votecount = 0;
	HideRound = 0;
	IsHide = false;
	StartHide = false;
	RoundLimits = 0;
	
	
	freezetime = GetConVarInt(freezetimec);
	roundtime = GetConVarInt(roundtimec);
	roundtimenormal = GetConVarInt(roundtimenormalc);
	
	new ent; 
	ent = FindEntityByClassname(-1, "env_fog_controller");
	if (ent != -1) 
	{
		FogIndex = ent;
	}
	else
	{
		FogIndex = CreateEntityByName("env_fog_controller");
		DispatchSpawn(FogIndex);
	}
	DoFog();
	AcceptEntityInput(FogIndex, "TurnOff");
}

public OnConfigsExecuted()
{
	roundtime = GetConVarInt(roundtimec);
	roundtimenormal = GetConVarInt(roundtimenormalc);
	freezetime = GetConVarInt(freezetimec);
	RoundLimits = 0;
}

public RoundEnd(Handle:event, String:name[], bool:dontBroadcast)
{
	new winner = GetEventInt(event, "winner");
	
	if (IsHide)
	{
		for(new client=1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client)) SetEntData(client, FindSendPropOffs("CBaseEntity", "m_CollisionGroup"), 0, 4, true);
		}
		
		if (LimitTimer != INVALID_HANDLE) KillTimer(LimitTimer);
		if (HideTimer != INVALID_HANDLE) KillTimer(HideTimer);
		if (WeaponTimer != INVALID_HANDLE) KillTimer(WeaponTimer);
		
		roundtime = GetConVarInt(roundtimec);
		roundtimenormal = GetConVarInt(roundtimenormalc);
		
		if (winner == 2) PrintCenterTextAll("%t", "hide_twin");
		if (winner == 3) PrintCenterTextAll("%t", "hide_ctwin");
		IsHide = false;
		StartHide = false;
		HideRound = 0;
		Format(voted, sizeof(voted), "");
		SetCvar("sm_hosties_lr", 1);
		SetCvar("sm_war_enable", 1);
		SetCvar("sm_zombie_enable", 1);
		SetCvar("sm_warffa_enable", 1);
		SetCvar("sm_warden_enable", 1);
		SetCvar("dice_enable", 1);
		SetCvar("mp_roundtime", roundtimenormal);
		SetCvar("mp_roundtime_hostage", roundtimenormal);
		SetCvar("mp_roundtime_defuse", roundtimenormal);
		PrintToChatAll("[%s] %t", g_whideprefix, "hide_end");
		DoFog();
		AcceptEntityInput(FogIndex, "TurnOff");
	}
	if (StartHide)
	{
	SetCvar("mp_roundtime", roundtime);
	SetCvar("mp_roundtime_hostage", roundtime);
	SetCvar("mp_roundtime_defuse", roundtime);
	}
}

public Action SetHide(int client,int args)
{
	if(GetConVarInt(g_wenabled) == 1)	
	{
	StartHide = true;
	RoundLimits = GetConVarInt(RoundLimitsc);
	votecount = 0;
	PrintToChatAll("[%s] %t", g_whideprefix, "hide_next");
	}
}

public RoundStart(Handle:event, String:name[], bool:dontBroadcast)
{
	if (StartHide)
	{
		
		SetCvar("sm_hosties_lr", 0);
		SetCvar("sm_war_enable", 0);
		SetCvar("sm_warffa_enable", 0);
		SetCvar("sm_warden_enable", 0);
		SetCvar("sm_zombie_enable", 0);
		SetCvar("dice_enable", 0);
		IsHide = true;
		HideRound++;
		StartHide = false;
		SJD_OpenDoors();

		HideMenu = CreatePanel();
		DrawPanelText(HideMenu, "Wir spielen Verstecken im Dunkeln!");

		DrawPanelText(HideMenu, "Die Terrors verstecken sich ");
		DrawPanelText(HideMenu, "-----------------------------------");
		DrawPanelText(HideMenu, "Die Counter suchen die Terrors");
		DrawPanelText(HideMenu, "								   ");
		DrawPanelText(HideMenu, "- In der Waffenstillstandsphase darf man schon aus der Waffenkammer!");
		DrawPanelText(HideMenu, "- Alle normalen Jailregeln sind dabei aufgehoben!");
		DrawPanelText(HideMenu, "- Buchstaben-, Yard- und Waffenkammercampen ist verboten!");
		DrawPanelText(HideMenu, "- Der letzte Terrorist hat keinen Wunsch!");
		DrawPanelText(HideMenu, "- Jeder darf überall hin wo er will!");
		DrawPanelText(HideMenu, "-----------------------------------");
		
		if (HideRound > 0)
			{
				for(new client=1; client <= MaxClients; client++)
				{
					
					if (IsClientInGame(client))
					{
						if (GetClientTeam(client) == 3)
						{
						SetEntityMoveType(client, MOVETYPE_NONE);
						}
					}
					PrintToChatAll("[%s] Terrors versteckt euch", g_whideprefix);
					if (IsClientInGame(client))
					{
					SetEntData(client, FindSendPropOffs("CBaseEntity", "m_CollisionGroup"), 2, 4, true);
					SendPanelToClient(HideMenu, client, Pass, 15);
					SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
					}
				}
				freezetime--;
				HideTimer = CreateTimer(1.0, Hide, _, TIMER_REPEAT);
			}
		{AcceptEntityInput(FogIndex, "TurnOn");}
	}
}

public Pass(Handle:menu, MenuAction:action, param1, param2)
{
}


public Action:Hide(Handle:timer)
{
	if (freezetime > 1)
	{
		freezetime--;
		for (new client=1; client <= MaxClients; client++)
		if (IsClientInGame(client) && IsPlayerAlive(client))
			{
		if (GetClientTeam(client) == 3)
						{
						PrintCenterText(client,"%i %t", freezetime, "hide_timetounfreeze");
						}
		if (GetClientTeam(client) == 2)
						{
						PrintCenterText(client,"%i %t", freezetime, "hide_timetohide");
						}
		}
		return Plugin_Continue;
	}
	
	freezetime = GetConVarInt(freezetimec);
	
	if (HideRound > 0)
	{
		for (new client=1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsPlayerAlive(client))
			{
				if (GetClientTeam(client) == 3)
				{
				SetEntityMoveType(client, MOVETYPE_WALK);
				}
				if (GetClientTeam(client) == 2)
				{
				SetEntityMoveType(client, MOVETYPE_NONE);
				SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
				}
			}
		}
	}
	PrintCenterTextAll("%t", "hide_start");
	PrintToChatAll("[%s] %t", g_whideprefix, "hide_start");


	
	HideTimer = INVALID_HANDLE;
	
	return Plugin_Stop;
}

DoFog()
{
	if(FogIndex != -1)
	{
		DispatchKeyValue(FogIndex, "fogblend", "0");
		DispatchKeyValue(FogIndex, "fogcolor", "0 0 0");
		DispatchKeyValue(FogIndex, "fogcolor2", "0 0 0");
		DispatchKeyValueFloat(FogIndex, "fogstart", mapFogStart);
		DispatchKeyValueFloat(FogIndex, "fogend", mapFogEnd);
		DispatchKeyValueFloat(FogIndex, "fogmaxdensity", mapFogDensity);
	}
}

public PlayerSay(Handle:event, String:name[], bool:dontBroadcast)
{
	decl String:text[256];
	decl String:steamid[64];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	GetClientAuthString(client, steamid, sizeof(steamid));
	GetEventString(event, "text", text, sizeof(text));
	
	if (StrEqual(text, g_whidecmd) || StrEqual(text, "!hide"))
	{
	if(GetConVarInt(g_wenabled) == 1)
	{	
		if (GetTeamClientCount(3) > 0)
		{
			if (RoundLimits == 0)
			{
				if (!IsHide && !StartHide)
				{
					if (StrContains(voted, steamid, true) == -1)
					{
						new playercount = (GetClientCount(true) / 2);
						
						votecount++;
						
						new Missing = playercount - votecount + 1;
						
						Format(voted, sizeof(voted), "%s,%s", voted, steamid);
						
						if (votecount > playercount)
						{
							StartHide = true;
							
							RoundLimits = GetConVarInt(RoundLimitsc);
							votecount = 0;
							
							PrintToChatAll("[%s] %t", g_whideprefix, "hide_next");
						}
						else PrintToChatAll("[%s] %i Votes bis Krieg beginnt", g_whideprefix, Missing);
						
					}
					else PrintToChat(client, "[%s] %t", g_whideprefix, "hide_voted");
				}
				else PrintToChat(client, "[%s] %t", g_whideprefix, "hide_progress");
			}
			else PrintToChat(client, "[%s] Du musst noch %i Runden warten", g_whideprefix, RoundLimits);
		}
		else PrintToChat(client, "[%s] %t", g_whideprefix, "hide_minct");
	}
	else PrintToChat(client, "[%s] %t", g_whideprefix, "hide_disabled");
	}
}



public SetCvar(String:cvarName[64], value)
{
	cvar = FindConVar(cvarName);
	if(cvar == INVALID_HANDLE) return;
	
	new flags = GetConVarFlags(cvar);
	flags &= ~FCVAR_NOTIFY;
	SetConVarFlags(cvar, flags);

	SetConVarInt(cvar, value);

	flags |= FCVAR_NOTIFY;
	SetConVarFlags(cvar, flags);
}

public SetCvarF(String:cvarName[64], Float:value)
{
	cvar = FindConVar(cvarName);
	if(cvar == INVALID_HANDLE) return;

	new flags = GetConVarFlags(cvar);
	flags &= ~FCVAR_NOTIFY;
	SetConVarFlags(cvar, flags);

	SetConVarFloat(cvar, value);

	flags |= FCVAR_NOTIFY;
	SetConVarFlags(cvar, flags);
}

public OnMapEnd()
{
	IsHide = false;
	StartHide = false;
	votecount = 0;
	HideRound = 0;
	
	voted[0] = '\0';
}
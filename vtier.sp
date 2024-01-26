#include <sourcemod>
#include "SteamWorks"
#include "smjansson"
#include "colors"
#include "gokz/core"
#include "gokz/localdb"

char gC_Prefix[32]				 = "{green}KZ {grey}| ";
char gC_CurrentMapName[64] = "";

public Plugin myinfo =
{
	name				= "VNL Tier",
	author			= "Reeed",
	description = "Get vnl tiers of gokz maps",
	version			= "0.1",
	url					= "https://vnl.kz"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_vnltier", Command_GetTier, "get vnl tier of current map");
	RegConsoleCmd("sm_vtier", Command_GetTier, "abbr for sm_vnltier");
}

public Action Command_GetTier(int client, int args)
{
	GetCurrentMapDisplayName(gC_CurrentMapName, sizeof(gC_CurrentMapName));

	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	char link[512];
	Format(link, sizeof(link), "https://vnl-stats-backend.onrender.com/api/v1/maps/%s", gC_CurrentMapName);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, link);
	if (request != null)
	{
		DataPack data = CreateDataPack();
		data.WriteCell(GetClientUserId(client));
		SteamWorks_SetHTTPRequestContextValue(request, data);

		if (!SteamWorks_SetHTTPCallbacks(request, GetMapCallback) || !SteamWorks_SendHTTPRequest(request))
		{
			PrintToServer("error sending request");
			delete request;
		}
	}
	else
	{
		PrintToServer("error creating request");
	}
}

void GetMapCallback(Handle request, bool failure, bool requestSuccess, EHTTPStatusCode status, DataPack data)
{
	data.Reset();
	int userid = data.ReadCell();
	int client = GetClientOfUserId(userid);

	if (failure || !requestSuccess || status != k_EHTTPStatusCode200OK)
	{
		CPrintToChat(client, "%s{yellow}未查询到该地图", gC_Prefix);
		PrintToServer("request failure");
		delete request;
		delete data;
		return;
	}

	int tpTier, proTier;

	if (!GetTiers(request, tpTier, proTier))
	{
		CPrintToChat(client, "%s{red}未查询到该地图", gC_Prefix);
	}
	else
	{
		CPrintToChat(client, "%s{default}%s - {lightgreen}读点 {grey}| {default}第{yellow}%d{default}阶 - {darkblue}裸跳 {grey}| {default}第{yellow}%d{default}阶", gC_Prefix, gC_CurrentMapName, tpTier, proTier);
	}
}

bool GetTiers(Handle request, int &tpTier, int &proTier)
{
	tpTier	= -1;
	proTier = -1;

	char buffer[2048];
	if (!SteamWorks_GetHTTPResponseBody_Easy(request, buffer, sizeof(buffer)))
	{
		PrintToServer("get res body failure");
		return false;
	}

	Handle obj = json_load(buffer);
	if (obj == null)
	{
		PrintToServer("no object read from json buffer");
		return false;
	}

	Handle objTpTier	= json_object_get(obj, "tpTier");
	Handle objProTier = json_object_get(obj, "proTier");

	if (objTpTier != null && objProTier != null)
	{
		tpTier	= json_integer_value(objTpTier);
		proTier = json_integer_value(objProTier);
	}
	else
	{
		PrintToServer("cant get tp/pro tier");
		return false;
	}

	delete objTpTier;
	delete objProTier;
	delete obj;
	return true;
}

bool SteamWorks_GetHTTPResponseBody_Easy(Handle request, char[] buffer, int maxlength)
{
	int size;
	if (SteamWorks_GetHTTPResponseBodySize(request, size) && (maxlength > size))
	{
		if (SteamWorks_GetHTTPResponseBodyData(request, buffer, size))
		{
			return true;
		}
	}
	return false;
}
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2>
#pragma newdecls optional
#include <tf2itemsinfo>
#pragma newdecls required

public void OnPluginStart() {
	if (!TF2II_IsItemSchemaPrecached()) return;
	KeyValues kv = view_as<KeyValues>(TF2II_GetAttribKeyValues( 694 ));
	char strFilePath[PLATFORM_MAX_PATH] = "data/tf2itemsinfo22.txt";
	BuildPath( Path_SM, strFilePath, sizeof(strFilePath), strFilePath );
	LogError("Written to %s", strFilePath);
	KeyValuesToFile(kv, strFilePath);
	CloseHandle(kv);
}
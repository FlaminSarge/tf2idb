#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2itemsinfo>

public OnPluginStart() {
	if (!TF2II_IsItemSchemaPrecached()) return;
	new Handle:kv = TF2II_GetAttribKeyValues( 694 );
	decl String:strFilePath[PLATFORM_MAX_PATH] = "data/tf2itemsinfo22.txt";
	BuildPath( Path_SM, strFilePath, sizeof(strFilePath), strFilePath );
	LogError("Written to %s", strFilePath);
	KeyValuesToFile(kv, strFilePath);
	CloseHandle(kv);
}
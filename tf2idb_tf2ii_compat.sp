/////////////////////////
/* Including Libraries */
/////////////////////////

#include <sourcemod>
#include <tf2_stocks>
#include <tf2idb>

#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN

#pragma semicolon 1

#define PLUGIN_VERSION		"1.0.0"
//#define PLUGIN_UPDATE_URL	"http://cdn.hop.tf/tf2itemsinfo/updatelist.txt"
#define PLUGIN_UPDATE_URL ""

////////////////////////
/* Plugin Information */
////////////////////////

public Plugin:myinfo = {
	name = "[DEV] TF2IDB Adapter for TF2ItemsInfo",
	author = "FlaminSarge",
	description = "Pretends that it's TF2ItemsInfo and calls TF2IDB for its results",
	version = PLUGIN_VERSION,
	url = "http://github.com/flaminsarge/tf2idb"
};

///////////////////////
/* Defined Constants */
///////////////////////

#define SEARCH_MINLENGTH	2
#define SEARCH_ITEMSPERPAGE	20

#define OLD_MAX_ITEM_ID 30789	//highest as of Sep 10, 2016, "Scoped Spartan", used if tf2idb fails
#define OLD_MAX_ATTR_ID 3018	//highest as of Sep 10, 2016, "item_drop_wave", used if tf2idb fails

#define ERROR_NONE		0		// PrintToServer only
#define ERROR_LOG		(1<<0)	// use LogToFile
#define ERROR_BREAKF	(1<<1)	// use ThrowError
#define ERROR_BREAKN	(1<<2)	// use ThrowNativeError
#define ERROR_BREAKP	(1<<3)	// use SetFailState
#define ERROR_NOPRINT	(1<<4)	// don't use PrintToServer

#define TF2II_ITEMNAME_LENGTH			64
#define TF2II_ITEMTOOL_LENGTH			16
#define TF2II_ITEMQUALITY_LENGTH		16

#define TF2II_PROP_INVALID				0 // invalid property, not item
// Items only
#define TF2II_PROP_VALIDITEM			(1<<0)
#define TF2II_PROP_BASEITEM				(1<<1)
#define TF2II_PROP_PAINTABLE			(1<<2)
#define TF2II_PROP_UNUSUAL				(1<<3)
#define TF2II_PROP_VINTAGE				(1<<4)
#define TF2II_PROP_STRANGE				(1<<5)
#define TF2II_PROP_HAUNTED				(1<<6)
#define TF2II_PROP_HALLOWEEN			(1<<7) // unused?
#define TF2II_PROP_PROMOITEM			(1<<8)
#define TF2II_PROP_GENUINE				(1<<9)
#define TF2II_PROP_MEDIEVAL				(1<<10)
#define TF2II_PROP_BDAY_STRICT			(1<<11)
#define TF2II_PROP_HOFM_STRICT			(1<<12)	// Halloween Or Full Moon
#define TF2II_PROP_XMAS_STRICT			(1<<13)
#define TF2II_PROP_PROPER_NAME			(1<<14)
// Attributes only
#define TF2II_PROP_VALIDATTRIB			(1<<20)
#define TF2II_PROP_EFFECT_POSITIVE		(1<<21)
#define TF2II_PROP_EFFECT_NEUTRAL		(1<<22)
#define TF2II_PROP_EFFECT_NEGATIVE		(1<<23)
#define TF2II_PROP_HIDDEN				(1<<24)
#define TF2II_PROP_STORED_AS_INTEGER	(1<<25)

#define TF2II_CLASS_NONE				0
#define TF2II_CLASS_SCOUT				(1<<0)
#define TF2II_CLASS_SNIPER				(1<<1)
#define TF2II_CLASS_SOLDIER				(1<<2)
#define TF2II_CLASS_DEMOMAN				(1<<3)
#define TF2II_CLASS_MEDIC				(1<<4)
#define TF2II_CLASS_HEAVY				(1<<5)
#define TF2II_CLASS_PYRO				(1<<6)
#define TF2II_CLASS_SPY					(1<<7)
#define TF2II_CLASS_ENGINEER			(1<<8)
#define TF2II_CLASS_ALL					(0b111111111)
#define TF2II_CLASS_ANY					TF2II_CLASS_ALL

///////////////
/* Enumerics */
///////////////

enum ItemDataType
{
	ItemData_DefinitionID,
	ItemData_Property,
	ItemData_Name,
	ItemData_MLName,
	ItemData_MLSlotName,
	ItemData_MLDescription,
	ItemData_ClassName,
	ItemData_Slot,
	ItemData_ListedSlot,
	ItemData_Tool,
	ItemData_MinLevel,
	ItemData_MaxLevel,
	ItemData_Quality,
	ItemData_UsedBy,
	ItemData_Attributes,
	ItemData_EquipRegions,
	ItemData_LogName,
	ItemData_LogIcon,
	ItemData_KeyValues
};

//////////////////////
/* Global Variables */
//////////////////////

new Handle:sm_tf2ii_version = INVALID_HANDLE;
new Handle:sm_tf2ii_logs = INVALID_HANDLE;
new Handle:sm_tf2ii_fix01 = INVALID_HANDLE;
#if defined _updater_included
new Handle:sm_tf2ii_updater = INVALID_HANDLE;
#endif

new bool:bUseLogs = true;
new bool:bSchemaLoaded = false;
new nFix01State = 0;
#if defined _updater_included
new bool:bAutoUpdate = true;
#endif

new Handle:hForward_ItemSchemaUpdated = INVALID_HANDLE;
new Handle:hForward_OnSearchCommand = INVALID_HANDLE;
new Handle:hForward_OnFindItems = INVALID_HANDLE;

new Handle:g_hItemProperties = INVALID_HANDLE;


//////////////////////
/* SourceMod Events */
//////////////////////

public APLRes:AskPluginLoad2(Handle:hPlugin, bool:bLateLoad, String:sError[], iErrorSize)
{
	CreateNative( "TF2II_IsItemSchemaPrecached", Native_IsItemSchemaPrecached );

	CreateNative( "TF2II_IsValidItemID", Native_IsValidItemID );//
	CreateNative( "TF2II_GetItemClass", Native_GetItemClass );
	CreateNative( "TF2II_GetItemSlot", Native_GetItemSlot );
	CreateNative( "TF2II_GetItemSlotName", Native_GetItemSlotName );
	CreateNative( "TF2II_GetListedItemSlot", Native_GetListedItemSlot );
	CreateNative( "TF2II_GetListedItemSlotName", Native_GetListedItemSlotName );
	CreateNative( "TF2II_GetItemQuality", Native_GetItemQuality );
	CreateNative( "TF2II_GetItemQualityName", Native_GetItemQualityName );
	CreateNative( "TF2II_IsItemUsedByClass", Native_IsItemUsedByClass );
	CreateNative( "TF2II_GetItemMinLevel", Native_GetItemMinLevel );
	CreateNative( "TF2II_GetItemMaxLevel", Native_GetItemMaxLevel );
	CreateNative( "TF2II_GetItemNumAttributes", Native_GetItemNumAttributes );
	CreateNative( "TF2II_GetItemAttributeName", Native_GetItemAttributeName );
	CreateNative( "TF2II_GetItemAttributeID", Native_GetItemAttributeID );
	CreateNative( "TF2II_GetItemAttributeValue", Native_GetAttributeValue );
	CreateNative( "TF2II_GetItemAttributes", Native_GetItemAttributes );
	CreateNative( "TF2II_GetToolType", Native_GetToolType );
	CreateNative( "TF2II_ItemHolidayRestriction", Native_ItemHolidayRestriction );
	CreateNative( "TF2II_GetItemEquipRegions", Native_GetItemEquipRegions );
	CreateNative( "TF2II_IsConflictRegions", Native_IsConflictRegions );
	CreateNative( "TF2II_GetItemName", Native_GetItemName );
	CreateNative( "TF2II_ItemHasProperty", Native_ItemHasProperty );

	CreateNative( "TF2II_IsValidAttribID", Native_IsValidAttribID );
	CreateNative( "TF2II_GetAttribName", Native_GetAttribName );
	CreateNative( "TF2II_GetAttribClass", Native_GetAttribClass );
	CreateNative( "TF2II_GetAttribDispName", Native_GetAttribDispName );
	CreateNative( "TF2II_GetAttribMinValue", Native_GetAttribMinValue );
	CreateNative( "TF2II_GetAttribMaxValue", Native_GetAttribMaxValue );
	CreateNative( "TF2II_GetAttribGroup", Native_GetAttribGroup );
	CreateNative( "TF2II_GetAttribDescrString", Native_GetAttribDescrString );
	CreateNative( "TF2II_GetAttribDescrFormat", Native_GetAttribDescrFormat );
	CreateNative( "TF2II_HiddenAttrib", Native_HiddenAttrib );
	CreateNative( "TF2II_GetAttribEffectType", Native_GetAttribEffectType );
	CreateNative( "TF2II_AttribStoredAsInteger", Native_AttribStoredAsInteger );
	CreateNative( "TF2II_AttribHasProperty", Native_AttribHasProperty );

	CreateNative( "TF2II_GetItemKeyValues", Native_UnsupportedFunction );
	CreateNative( "TF2II_GetItemKey", Native_UnsupportedFunction );
	CreateNative( "TF2II_GetItemKeyFloat", Native_UnsupportedFunction );
	CreateNative( "TF2II_GetItemKeyString", Native_UnsupportedFunction );
	CreateNative( "TF2II_GetAttribKeyValues", Native_GetAttribKeyValues );
	CreateNative( "TF2II_GetAttribKey", Native_GetAttribKey );
	CreateNative( "TF2II_GetAttribKeyFloat", Native_GetAttribKeyFloat );
	CreateNative( "TF2II_GetAttribKeyString", Native_GetAttribKeyString );

	CreateNative( "TF2II_GetQualityByName", Native_GetQualityByName );
	CreateNative( "TF2II_GetQualityName", Native_GetQualityName );
	CreateNative( "TF2II_GetAttributeIDByName", Native_GetAttributeIDByName );
	CreateNative( "TF2II_GetAttributeNameByID", Native_GetAttributeNameByID );

	CreateNative( "TF2II_FindItems", Native_FindItems );
	CreateNative( "TF2II_ListAttachableEffects", Native_ListEffects );
	CreateNative( "TF2II_ListEffects", Native_ListEffects );

	// Obsolete
	CreateNative( "TF2II_IsPromotionalItem", Native_DeprecatedFunction );
	CreateNative( "TF2II_IsUpgradeableStockWeapon", Native_DeprecatedFunction );
	CreateNative( "TF2II_IsFestiveStockWeapon", Native_DeprecatedFunction );
	CreateNative( "TF2II_FindItemsIDsByCond", Native_FindItemsIDsByCond );

	hForward_ItemSchemaUpdated = CreateGlobalForward( "TF2II_OnItemSchemaUpdated", ET_Ignore );
	hForward_OnSearchCommand = CreateGlobalForward( "TF2II_OnSearchCommand", ET_Ignore, Param_Cell, Param_String, Param_CellByRef, Param_Cell );
	hForward_OnFindItems = CreateGlobalForward( "TF2II_OnFindItems", ET_Ignore, Param_String, Param_String, Param_Cell, Param_String, Param_CellByRef );

	return APLRes_Success;
}

public OnPluginStart()
{
	sm_tf2ii_version = CreateConVar( "sm_tf2ii_version", PLUGIN_VERSION, "TF2 Items Info Plugin Version", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY );
	SetConVarString( sm_tf2ii_version, PLUGIN_VERSION, true, true );
	HookConVarChange( sm_tf2ii_version, OnConVarChanged_PluginVersion );

	HookConVarChange( sm_tf2ii_logs = CreateConVar( "sm_tf2ii_logs", bUseLogs ? "1" : "0", "Enable/disable logs", 0, true, 0.0, true, 1.0 ), OnConVarChanged );
	HookConVarChange( sm_tf2ii_fix01 = CreateConVar( "sm_tf2ii_fix01", "0", "Fix items with 'string' attributes:\n0 - disabled, 1 - skip 'string' attributes, 2 - skip items with 'string' attributes.", 0, true, 0.0, true, 2.0 ), OnConVarChanged );
#if defined _updater_included
	HookConVarChange( sm_tf2ii_updater = CreateConVar("sm_tf2ii_updater", bAutoUpdate ? "1" : "0", "Enable/disable autoupdate", 0, true, 0.0, true, 1.0), OnConVarChanged);
#endif

	decl String:strGameDir[8];
	GetGameFolderName( strGameDir, sizeof(strGameDir) );
	if( !StrEqual( strGameDir, "tf", false ) && !StrEqual( strGameDir, "tf_beta", false ) )
		Error( ERROR_BREAKP|ERROR_LOG, _, "THIS PLUGIN IS FOR TEAM FORTRESS 2 ONLY!" );

	RegAdminCmd( "sm_tf2ii_killdata", Command_Test_KillData, ADMFLAG_ROOT );

	RegConsoleCmd( "sm_si", Command_FindItems, "[TF2II] Find items by name." );
	RegConsoleCmd( "sm_fi", Command_FindItems, "[TF2II] Find items by name." );
	RegConsoleCmd( "sm_sic", Command_FindItemsByClass, "[TF2II] Find items by item class name." );
	RegConsoleCmd( "sm_fic", Command_FindItemsByClass, "[TF2II] Find items by item class name." );
	RegConsoleCmd( "sm_ii", Command_PrintInfo, "[TF2II] Print info about item (by id)." );
	RegConsoleCmd( "sm_pi", Command_PrintInfo, "[TF2II] Print info about item (by id)." );
	RegConsoleCmd( "sm_sa", Command_FindAttributes, "[TF2II] Find attributes by id or name." );
	RegConsoleCmd( "sm_fa", Command_FindAttributes, "[TF2II] Find attributes by id or name." );
	RegConsoleCmd( "sm_sac", Command_FindAttributesByClass, "[TF2II] Find attributes by attribute class name." );
	RegConsoleCmd( "sm_fac", Command_FindAttributesByClass, "[TF2II] Find attributes by attribute class name." );

	//PrecacheItemSchema();
}

public OnAllPluginsLoaded() {
	if (LibraryExists("tf2idb") && !bSchemaLoaded) {
		Call_StartForward( hForward_ItemSchemaUpdated );
		Call_Finish();
		bSchemaLoaded = true;
		RegPluginLibrary( "tf2itemsinfo" );
	}
	ReloadConfigs();
}
// a fwd call to ItemSchemaUpdated should only happen once
public OnLibraryAdded(const String:strName[]) {
	if (StrEqual(strName, "tf2idb", false) && !bSchemaLoaded) {
		Call_StartForward( hForward_ItemSchemaUpdated );
		Call_Finish();
		bSchemaLoaded = true;
		RegPluginLibrary( "tf2itemsinfo" );
	}
#if defined _updater_included
	if (PLUGIN_UPDATE_URL[0] != '\0' && StrEqual(strName, "updater", false)) {
        Updater_AddPlugin(PLUGIN_UPDATE_URL);
	}
#endif
}
public OnLibraryRemoved(const String:strName[]) {
	if (StrEqual(strName, "tf2idb", false)) {
		bSchemaLoaded = false;
	}
}

GetConVars()
{
	bUseLogs = GetConVarBool( sm_tf2ii_logs );

	nFix01State = GetConVarInt( sm_tf2ii_fix01 );

#if defined _updater_included
	bAutoUpdate = GetConVarBool(sm_tf2ii_updater);
	if( PLUGIN_UPDATE_URL[0] != '\0' && LibraryExists("updater") )
	{
		if( bAutoUpdate )
			Updater_AddPlugin( PLUGIN_UPDATE_URL );
		else
			Updater_RemovePlugin();
	}
#endif
}

//////////////////////
/* Command handlers */
//////////////////////
public Action:Command_Test_KillData( iClient, iArgs )
{
#if 0
	ReplyToCommand( iClient, "Killing data:" );
	for( new i = 0; i <= GetMaxItemID(); i++ )
		if( ItemData_Destroy( i ) )
			ReplyToCommand( iClient, "Item %d deleted;", i );
	ReplyToCommand( iClient, "Done." );
#else
	ReplyToCommand( iClient, "Disabled feature." );
#endif
	return Plugin_Handled;
}

public Action:Command_FindItems( iClient, nArgs )
{
	if( iClient < 0 || iClient > MaxClients )
		return Plugin_Continue;

	decl String:strCmdName[16];
	GetCmdArg( 0, strCmdName, sizeof(strCmdName) );
	if( nArgs < 1 )
	{
		ReplyToCommand( iClient, "Usage: %s <name> [pagenum]", strCmdName );
		return Plugin_Handled;
	}

	new iPage = 0;
	if( nArgs >= 2 )
	{
		decl String:strPage[8];
		GetCmdArg( 2, strPage, sizeof(strPage) );
		if( IsCharNumeric(strPage[0]) )
		{
			iPage = StringToInt( strPage );
			if( iPage < 1 )
				iPage = 1;
		}
	}

	decl String:strSearch[64];
	if( iPage )
		GetCmdArg( 1, strSearch, sizeof(strSearch) );
	else
	{
		iPage = 1;
		GetCmdArgString( strSearch, sizeof(strSearch) );
		StripQuotes( strSearch );
	}
	TrimString( strSearch );
	if( strlen( strSearch ) < SEARCH_MINLENGTH && !IsCharNumeric(strSearch[0]) )
	{
		ReplyToCommand( iClient, "Too short name! Minimum: %d chars", SEARCH_MINLENGTH );
		return Plugin_Handled;
	}


	new maxlen = TF2II_ITEMNAME_LENGTH;

	new Handle:arguments = CreateArray(sizeof(strSearch)+4);
	Format(strSearch, sizeof(strSearch), "%%%s%%", strSearch);
	PushArrayString(arguments, strSearch);
	new DBStatement:resultStatement = TF2IDB_CustomQuery("SELECT id, name FROM tf2idb_item WHERE (name LIKE ?)", arguments, maxlen);
	CloseHandle(arguments);

	new iResults;
	new Handle:hResults = CreateArray(maxlen+1);

	decl String:strItemName[maxlen];

	if (resultStatement != INVALID_HANDLE) {
		while (SQL_FetchRow(resultStatement)) {
			new id = SQL_FetchInt(resultStatement, 0);
			SQL_FetchString(resultStatement, 1, strItemName, maxlen);
			PushArrayCell(hResults, id);
			PushArrayString(hResults, strItemName);
		}
		CloseHandle(resultStatement);
	}

	Call_StartForward( hForward_OnSearchCommand );
	Call_PushCell( iClient );
	Call_PushString( strSearch );
	Call_PushCellRef( hResults );
	Call_PushCell( 0 );
	Call_Finish();

	iResults = GetArraySize( hResults ) / 2;

	ReplyToCommand( iClient, "Found %d items (p. %d/%d):", iResults, ( iResults ? iPage : 0 ), RoundToCeil( float( iResults ) / float(SEARCH_ITEMSPERPAGE) ) );

	iPage--;
	new iMin = SEARCH_ITEMSPERPAGE * iPage;
	iMin = ( iMin < 0 ? 0 : iMin );
	new iMax = SEARCH_ITEMSPERPAGE * (iPage+1);
	iMax = ( iMax >= iResults ? iResults : iMax );

	if( iResults ) {
		for( new i = iMin; i < iMax; i++ )
		{
			GetArrayString( hResults, 2 * i + 1, strItemName, maxlen );
			ReplyToCommand( iClient, "- %d: %s", GetArrayCell( hResults, 2 * i ), strItemName );
		}
	}
	CloseHandle( hResults );

	return Plugin_Handled;
}
public Action:Command_FindItemsByClass( iClient, nArgs )
{
	if( iClient < 0 || iClient > MaxClients )
		return Plugin_Continue;

	decl String:strCmdName[16];
	GetCmdArg( 0, strCmdName, sizeof(strCmdName) );
	if( nArgs < 1 )
	{
		ReplyToCommand( iClient, "Usage: %s <classname> [pagenum]", strCmdName );
		return Plugin_Handled;
	}

	new iPage = 0;
	if( nArgs >= 2 )
	{
		decl String:strPage[8];
		GetCmdArg( 2, strPage, sizeof(strPage) );
		if( IsCharNumeric(strPage[0]) )
		{
			iPage = StringToInt( strPage );
			if( iPage < 1 )
				iPage = 1;
		}
	}

	decl String:strSearch[64];
	if( iPage )
		GetCmdArg( 1, strSearch, sizeof(strSearch) );
	else
	{
		iPage = 1;
		GetCmdArgString( strSearch, sizeof(strSearch) );
		StripQuotes( strSearch );
	}
	TrimString( strSearch );
	if( strlen( strSearch ) < SEARCH_MINLENGTH && !IsCharNumeric(strSearch[0]) )
	{
		ReplyToCommand( iClient, "Too short name! Minimum: %d chars", SEARCH_MINLENGTH );
		return Plugin_Handled;
	}

	new maxlen = TF2II_ITEMNAME_LENGTH;

	new Handle:arguments = CreateArray(sizeof(strSearch)+4);
	Format(strSearch, sizeof(strSearch), "%%%s%%", strSearch);
	PushArrayString(arguments, strSearch);
	new DBStatement:resultStatement = TF2IDB_CustomQuery("SELECT id, name FROM tf2idb_item WHERE (class LIKE ?)", arguments, maxlen);
	CloseHandle(arguments);
	new iResults;

	new Handle:hResults = CreateArray(maxlen+1);

	decl String:strItemName[maxlen];
//	decl String:strItemClass[maxlen];

	if (resultStatement != INVALID_HANDLE) {
		while (SQL_FetchRow(resultStatement)) {
			new id = SQL_FetchInt(resultStatement, 0);
			SQL_FetchString(resultStatement, 1, strItemName, maxlen);
			PushArrayCell(hResults, id);
			PushArrayString(hResults, strItemName);
		}
		CloseHandle(resultStatement);
	}

	Call_StartForward( hForward_OnSearchCommand );
	Call_PushCell( iClient );
	Call_PushString( strSearch );
	Call_PushCellRef( hResults );
	Call_PushCell( 1 );
	Call_Finish();

	iResults = GetArraySize( hResults ) / 2;

	ReplyToCommand( iClient, "Found %d items (p. %d/%d):", iResults, ( iResults ? iPage : 0 ), RoundToCeil( float( iResults ) / float(SEARCH_ITEMSPERPAGE) ) );

	iPage--;
	new iMin = SEARCH_ITEMSPERPAGE * iPage;
	iMin = ( iMin < 0 ? 0 : iMin );
	new iMax = SEARCH_ITEMSPERPAGE * (iPage+1);
	iMax = ( iMax >= iResults ? iResults : iMax );

	if( iResults ) {
		for( new i = iMin; i < iMax; i++ )
		{
			GetArrayString( hResults, 2 * i + 1, strItemName, maxlen );
			ReplyToCommand( iClient, "- %d: %s", GetArrayCell( hResults, 2 * i ), strItemName );
		}
	}
	CloseHandle( hResults );

	return Plugin_Handled;
}
public Action:Command_PrintInfo( iClient, nArgs )
{
	if( iClient < 0 || iClient > MaxClients )
		return Plugin_Continue;

	decl String:strCmdName[16];
	GetCmdArg( 0, strCmdName, sizeof(strCmdName) );
	if( nArgs < 1 )
	{
		if( StrEqual( "sm_pi", strCmdName, false ) )
			ReplyToCommand( iClient, "The Pi number: 3.1415926535897932384626433832795028841971..." );
		else
			ReplyToCommand( iClient, "Usage: %s <id>  [pagenum]", strCmdName );
		return Plugin_Handled;
	}

	decl String:strItemID[32];
	GetCmdArg( 1, strItemID, sizeof(strItemID) );
	new iItemDefID = StringToInt(strItemID);
	if( !ItemHasProp( iItemDefID, TF2II_PROP_VALIDITEM ) )
	{
		ReplyToCommand( iClient, "Item #%d is invalid!", iItemDefID );
		return Plugin_Handled;
	}

	decl String:strMessage[250], String:strBuffer[128];

	ReplyToCommand( iClient, "==================================================" );

	Format( strMessage, sizeof(strMessage), "Item Definition Index: %d", iItemDefID );
	ReplyToCommand( iClient, strMessage );

	ItemData_GetString( iItemDefID, ItemData_Name, strBuffer, sizeof(strBuffer) );
	Format( strMessage, sizeof(strMessage), "Item Name: %s", strBuffer );
	ReplyToCommand( iClient, strMessage );

	ItemData_GetString( iItemDefID, ItemData_ClassName, strBuffer, sizeof(strBuffer) );
	if( strlen( strBuffer ) )
	{
		Format( strMessage, sizeof(strMessage), "Item Class: %s", strBuffer );
		ReplyToCommand( iClient, strMessage );
	}

	ItemData_GetString( iItemDefID, ItemData_Slot, strBuffer, sizeof(strBuffer) );
	if( strlen( strBuffer ) )
	{
		Format( strMessage, sizeof(strMessage), "Item Slot: %s", strBuffer );
		ReplyToCommand( iClient, strMessage );
	}

	ItemData_GetString( iItemDefID, ItemData_ListedSlot, strBuffer, sizeof(strBuffer) );
	if( strlen( strBuffer ) )
	{
		Format( strMessage, sizeof(strMessage), "Listed Item Slot: %s", strBuffer );
		ReplyToCommand( iClient, strMessage );
	}

	Format( strMessage, sizeof(strMessage), "Level bounds: [%d...%d]", ItemData_GetCell( iItemDefID, ItemData_MinLevel ), ItemData_GetCell( iItemDefID, ItemData_MaxLevel ) );
	ReplyToCommand( iClient, strMessage );

	ItemData_GetString( iItemDefID, ItemData_Quality, strBuffer, sizeof(strBuffer) );
	if( strlen(strBuffer) )
	{
		Format( strMessage, sizeof(strMessage), "Quality: %s (%d)", strBuffer, _:GetQualityByName(strBuffer) );
		ReplyToCommand( iClient, strMessage );
	}

	ItemData_GetString( iItemDefID, ItemData_Tool, strBuffer, sizeof(strBuffer) );
	if( strlen(strBuffer) )
	{
		Format( strMessage, sizeof(strMessage), "Tool type: %s", strBuffer );
		ReplyToCommand( iClient, strMessage );
	}

	new bool:bBDAYRestriction = ItemHasProp( iItemDefID, TF2II_PROP_BDAY_STRICT );
	new bool:bHOFMRestriction = ItemHasProp( iItemDefID, TF2II_PROP_HOFM_STRICT );
	new bool:bXMASRestriction = ItemHasProp( iItemDefID, TF2II_PROP_XMAS_STRICT );
	if( bBDAYRestriction || bHOFMRestriction || bXMASRestriction )
		ReplyToCommand( iClient, "Holiday restriction:" );
	if( bBDAYRestriction )
		ReplyToCommand( iClient, "- birthday" );
	if( bHOFMRestriction )
		ReplyToCommand( iClient, "- halloween_or_fullmoon" );
	if( bXMASRestriction )
		ReplyToCommand( iClient, "- christmas" );

	new iUsedByClass = ItemData_GetCell( iItemDefID, ItemData_UsedBy );
	ReplyToCommand( iClient, "Used by classes:" );
	if( iUsedByClass <= TF2II_CLASS_NONE )
		ReplyToCommand( iClient, "- None (%d)", iUsedByClass );
	else if( iUsedByClass == TF2II_CLASS_ALL )
		ReplyToCommand( iClient, "- Any (%d)", iUsedByClass );
	else
	{
		if( iUsedByClass & TF2II_CLASS_SCOUT )
			ReplyToCommand( iClient, "- Scout (%d)", iUsedByClass & TF2II_CLASS_SCOUT );
		if( iUsedByClass & TF2II_CLASS_SNIPER )
			ReplyToCommand( iClient, "- Sniper (%d)", iUsedByClass & TF2II_CLASS_SNIPER );
		if( iUsedByClass & TF2II_CLASS_SOLDIER )
			ReplyToCommand( iClient, "- Soldier (%d)", iUsedByClass & TF2II_CLASS_SOLDIER );
		if( iUsedByClass & TF2II_CLASS_DEMOMAN )
			ReplyToCommand( iClient, "- Demoman (%d)", iUsedByClass & TF2II_CLASS_DEMOMAN );
		if( iUsedByClass & TF2II_CLASS_MEDIC )
			ReplyToCommand( iClient, "- Medic (%d)", iUsedByClass & TF2II_CLASS_MEDIC );
		if( iUsedByClass & TF2II_CLASS_HEAVY )
			ReplyToCommand( iClient, "- Heavy (%d)", iUsedByClass & TF2II_CLASS_HEAVY );
		if( iUsedByClass & TF2II_CLASS_PYRO )
			ReplyToCommand( iClient, "- Pyro (%d)", iUsedByClass & TF2II_CLASS_PYRO );
		if( iUsedByClass & TF2II_CLASS_SPY )
			ReplyToCommand( iClient, "- Spy (%d)", iUsedByClass & TF2II_CLASS_SPY );
		if( iUsedByClass & TF2II_CLASS_ENGINEER )
			ReplyToCommand( iClient, "- Engineer (%d)", iUsedByClass & TF2II_CLASS_ENGINEER );
	}

	new iAttribID, aid[TF2IDB_MAX_ATTRIBUTES], Float:values[TF2IDB_MAX_ATTRIBUTES];
	new count;
	if( (count = TF2IDB_GetItemAttributes(iItemDefID, aid, values)) > 0 )
	{
		ReplyToCommand( iClient, "Attributes:" );
		for( new a = 0; a < count ; a++ )
		{
			iAttribID = aid[a];
			TF2IDB_GetAttributeName( iAttribID, strBuffer, sizeof(strBuffer) );
			Format( strMessage, sizeof(strMessage), "- %s (%d) - %f", strBuffer, iAttribID, values[a] );
			ReplyToCommand( iClient, strMessage );
		}
	}

	if( nArgs >= 2 )
	{
		GetCmdArg( 2, strBuffer, sizeof(strBuffer) );
		if( StringToInt( strBuffer ) > 0 )
		{
			ReplyToCommand( iClient, "=================== EXTRA INFO ===================" );

			ItemData_GetString( iItemDefID, ItemData_MLName, strBuffer, sizeof(strBuffer) );
			if( strlen( strBuffer ) )
			{
				Format( strMessage, sizeof(strMessage), "Item ML Name: %s", strBuffer );
				ReplyToCommand( iClient, strMessage );
			}

			ReplyToCommand( iClient, "Proper name: %s", ItemHasProp( iItemDefID, TF2II_PROP_PROPER_NAME ) ? "true" : "false" );

			ItemData_GetString( iItemDefID, ItemData_LogName, strBuffer, sizeof(strBuffer) );
			if( strlen( strBuffer ) )
			{
				Format( strMessage, sizeof(strMessage), "Kill Log Name: %s", strBuffer );
				ReplyToCommand( iClient, strMessage );
			}

			ItemData_GetString( iItemDefID, ItemData_LogIcon, strBuffer, sizeof(strBuffer) );
			if( strlen( strBuffer ) )
			{
				Format( strMessage, sizeof(strMessage), "Kill Log Icon: %s", strBuffer );
				ReplyToCommand( iClient, strMessage );
			}

			new Handle:hEquipRegions = Handle:ItemData_GetCell( iItemDefID, ItemData_EquipRegions );
			if( hEquipRegions != INVALID_HANDLE )
			{
				ReplyToCommand( iClient, "Equipment regions:" );
				for( new r = 0; r < GetArraySize(hEquipRegions); r++ )
				{
					GetArrayString( hEquipRegions, r, strBuffer, sizeof(strBuffer) );
					Format( strMessage, sizeof(strMessage), "- %s", strBuffer );
					ReplyToCommand( iClient, strMessage );
				}
			}

			new Handle:hKV = Handle:ItemData_GetCell( iItemDefID, ItemData_KeyValues );
			if( hKV != INVALID_HANDLE )
			{
				if( KvJumpToKey( hKV, "model_player_per_class", false ) )
				{
					ReplyToCommand( iClient, "Models per class:" );

					KvGetString( hKV, "scout", strBuffer, sizeof(strBuffer) );
					if( strlen(strBuffer) )
					{
						Format( strMessage, sizeof(strMessage), "- Scout: %s", strBuffer );
						ReplyToCommand( iClient, strMessage );
					}

					KvGetString( hKV, "soldier", strBuffer, sizeof(strBuffer) );
					if( strlen(strBuffer) )
					{
						Format( strMessage, sizeof(strMessage), "- Soldier: %s", strBuffer );
						ReplyToCommand( iClient, strMessage );
					}

					KvGetString( hKV, "sniper", strBuffer, sizeof(strBuffer) );
					if( strlen(strBuffer) )
					{
						Format( strMessage, sizeof(strMessage), "- Sniper: %s", strBuffer );
						ReplyToCommand( iClient, strMessage );
					}

					KvGetString( hKV, "demoman", strBuffer, sizeof(strBuffer) );
					if( strlen(strBuffer) )
					{
						Format( strMessage, sizeof(strMessage), "- Demoman: %s", strBuffer );
						ReplyToCommand( iClient, strMessage );
					}

					KvGetString( hKV, "Medic", strBuffer, sizeof(strBuffer) );
					if( strlen(strBuffer) )
					{
						Format( strMessage, sizeof(strMessage), "- Medic: %s", strBuffer );
						ReplyToCommand( iClient, strMessage );
					}

					KvGetString( hKV, "heavy", strBuffer, sizeof(strBuffer) );
					if( strlen(strBuffer) )
					{
						Format( strMessage, sizeof(strMessage), "- Heavy: %s", strBuffer );
						ReplyToCommand( iClient, strMessage );
					}

					KvGetString( hKV, "pyro", strBuffer, sizeof(strBuffer) );
					if( strlen(strBuffer) )
					{
						Format( strMessage, sizeof(strMessage), "- Pyro: %s", strBuffer );
						ReplyToCommand( iClient, strMessage );
					}

					KvGetString( hKV, "spy", strBuffer, sizeof(strBuffer) );
					if( strlen(strBuffer) )
					{
						Format( strMessage, sizeof(strMessage), "- Spy: %s", strBuffer );
						ReplyToCommand( iClient, strMessage );
					}

					KvGetString( hKV, "engineer", strBuffer, sizeof(strBuffer) );
					if( strlen(strBuffer) )
					{
						Format( strMessage, sizeof(strMessage), "- Engineer: %s", strBuffer );
						ReplyToCommand( iClient, strMessage );
					}

					KvGoBack( hKV );
				}
				else
				{
					KvGetString( hKV, "model_world", strBuffer, sizeof(strBuffer) );
					Format( strMessage, sizeof(strMessage), "World model: %s", strBuffer );
					ReplyToCommand( iClient, strMessage );
				}

				KvGetString( hKV, "model_player", strBuffer, sizeof(strBuffer) );
				Format( strMessage, sizeof(strMessage), "View model: %s", strBuffer );
				ReplyToCommand( iClient, strMessage );

				new nStyles = 1;
				if( KvJumpToKey( hKV, "visuals", false ) && KvJumpToKey( hKV, "styles", false ) && KvGotoFirstSubKey( hKV ) )
				{
					while( KvGotoNextKey( hKV ) )
						nStyles++;
					KvGoBack( hKV );
					KvGoBack( hKV );
					KvGoBack( hKV );
				}
				Format( strMessage, sizeof(strMessage), "Number of styles: %d", nStyles );
				ReplyToCommand( iClient, strMessage );
			}
		}
	}

	ReplyToCommand( iClient, "==================================================" );

	return Plugin_Handled;
}
public Action:Command_FindAttributes( iClient, nArgs )
{
	if( iClient < 0 || iClient > MaxClients )
		return Plugin_Continue;

	decl String:strCmdName[16];
	GetCmdArg( 0, strCmdName, sizeof(strCmdName) );
	if( nArgs < 1 )
	{
		ReplyToCommand( iClient, "Usage: %s <id|name> [pagenum]", strCmdName );
		return Plugin_Handled;
	}

	new iPage = 0;
	if( nArgs >= 2 )
	{
		decl String:strPage[8];
		GetCmdArg( 2, strPage, sizeof(strPage) );
		if( IsCharNumeric(strPage[0]) )
		{
			iPage = StringToInt( strPage );
			if( iPage < 1 )
				iPage = 1;
		}
	}

	decl String:strSearch[64];
	if( iPage )
		GetCmdArg( 1, strSearch, sizeof(strSearch) );
	else
	{
		iPage = 1;
		GetCmdArgString( strSearch, sizeof(strSearch) );
		StripQuotes( strSearch );
	}
	TrimString( strSearch );
	if( strlen( strSearch ) < SEARCH_MINLENGTH && !IsCharNumeric(strSearch[0]) )
	{
		ReplyToCommand( iClient, "Too short name! Minimum: %d chars", SEARCH_MINLENGTH );
		return Plugin_Handled;
	}

	if( IsCharNumeric(strSearch[0]) )
	{
		new iAttribute = StringToInt(strSearch);
		if( !( 0 < iAttribute <= GetMaxAttributeID() ) )
			ReplyToCommand( iClient, "Attribute #%d is out of bounds [1...%d]", iAttribute, GetMaxAttributeID() );

		decl String:strBuffer[128];
		if( !IsValidAttribID( iAttribute ) )
		{
			ReplyToCommand( iClient, "Attribute #%d doesn't exists", iAttribute );
			return Plugin_Handled;
		}

		ReplyToCommand( iClient, "==================================================" );

		ReplyToCommand( iClient, "Attribute Index: %d", iAttribute );

		TF2IDB_GetAttributeName( iAttribute, strBuffer, sizeof(strBuffer) );
		ReplyToCommand( iClient, "Working Name: %s", strBuffer );

		if( TF2IDB_GetAttributeName( iAttribute, strBuffer, sizeof(strBuffer) ) )
			ReplyToCommand( iClient, "Display Name: %s", strBuffer );

		if( TF2IDB_GetAttributeDescString( iAttribute, strBuffer, sizeof(strBuffer) ) )
			ReplyToCommand( iClient, "Description String: %s", strBuffer );

		if( TF2IDB_GetAttributeDescFormat( iAttribute, strBuffer, sizeof(strBuffer) ) )
			ReplyToCommand( iClient, "Description Format: %s", strBuffer );

		if( TF2IDB_GetAttributeClass( iAttribute, strBuffer, sizeof(strBuffer) ) )
			ReplyToCommand( iClient, "Class: %s", strBuffer );

		if( TF2IDB_GetAttributeType( iAttribute, strBuffer, sizeof(strBuffer) ) )
			ReplyToCommand( iClient, "Type: %s", strBuffer );

/*		AttribData_GetString( iAttribute, AttribData_Group, strBuffer, sizeof(strBuffer) );
		if( strlen( strBuffer ) )
			ReplyToCommand( iClient, "Group: %s", strBuffer );
*/

//		ReplyToCommand( iClient, "Bounds of value: [%0.2f...%0.2f]", Float:AttribData_GetCell( iAttribute, AttribData_MinValue ), Float:AttribData_GetCell( iAttribute, AttribData_MaxValue ) );

		if( TF2IDB_GetAttributeEffectType( iAttribute, strBuffer, sizeof(strBuffer) ) )
			ReplyToCommand( iClient, "Effect Type: %s", strBuffer );

		ReplyToCommand( iClient, "Hidden: %s", ( AttribHasProp( iAttribute, TF2II_PROP_HIDDEN ) ? "true" : "false" ) );

		ReplyToCommand( iClient, "As Integer: %s", ( AttribHasProp( iAttribute, TF2II_PROP_STORED_AS_INTEGER ) ? "true" : "false" ) );

		ReplyToCommand( iClient, "==================================================" );

		return Plugin_Handled;
	}

	new maxlen = TF2IDB_ATTRIBNAME_LENGTH;

	new Handle:arguments = CreateArray(sizeof(strSearch)+4);
	Format(strSearch, sizeof(strSearch), "%%%s%%", strSearch);
	PushArrayString(arguments, strSearch);
	new DBStatement:resultStatement = TF2IDB_CustomQuery("SELECT id, name FROM tf2idb_attributes WHERE (name LIKE ?)", arguments, maxlen);
	CloseHandle(arguments);
	new iResults;
	new Handle:hResults = CreateArray(maxlen+1);

	decl String:strAttribName[maxlen];

	if (resultStatement != INVALID_HANDLE) {
		while (SQL_FetchRow(resultStatement)) {
			new id = SQL_FetchInt(resultStatement, 0);
			SQL_FetchString(resultStatement, 1, strAttribName, maxlen);
			PushArrayCell(hResults, id);
			PushArrayString(hResults, strAttribName);
		}
		CloseHandle(resultStatement);
	}

	iResults = GetArraySize(hResults) / 2;

	ReplyToCommand( iClient, "Found %d attributes (p. %d/%d):", iResults, ( iResults ? iPage : 0 ), RoundToCeil( float( iResults ) / float(SEARCH_ITEMSPERPAGE) ) );

	iPage--;
	new iMin = SEARCH_ITEMSPERPAGE * iPage;
	iMin = ( iMin < 0 ? 0 : iMin );
	new iMax = SEARCH_ITEMSPERPAGE * (iPage+1);
	iMax = ( iMax >= iResults ? iResults : iMax );

	if (iResults) {
		for (new i = iMin; i < iMax; i++) {
			GetArrayString(hResults, 2*i+1, strAttribName, maxlen);
			ReplyToCommand( iClient, "- %d: %s", GetArrayCell(hResults, 2*i), strAttribName );
		}
	}
	CloseHandle(hResults);

	return Plugin_Handled;
}
public Action:Command_FindAttributesByClass( iClient, nArgs )
{
	if( iClient < 0 || iClient > MaxClients )
		return Plugin_Continue;

	decl String:strCmdName[16];
	GetCmdArg( 0, strCmdName, sizeof(strCmdName) );
	if( nArgs < 1 )
	{
		ReplyToCommand( iClient, "Usage: %s <name> [pagenum]", strCmdName );
		return Plugin_Handled;
	}

	new iPage = 0;
	if( nArgs >= 2 )
	{
		decl String:strPage[8];
		GetCmdArg( 2, strPage, sizeof(strPage) );
		if( IsCharNumeric(strPage[0]) )
		{
			iPage = StringToInt( strPage );
			if( iPage < 1 )
				iPage = 1;
		}
	}

	decl String:strSearch[64];
	if( iPage )
		GetCmdArg( 1, strSearch, sizeof(strSearch) );
	else
	{
		iPage = 1;
		GetCmdArgString( strSearch, sizeof(strSearch) );
		StripQuotes( strSearch );
	}
	TrimString( strSearch );
	if( strlen( strSearch ) < SEARCH_MINLENGTH && !IsCharNumeric(strSearch[0]) )
	{
		ReplyToCommand( iClient, "Too short name! Minimum: %d chars", SEARCH_MINLENGTH );
		return Plugin_Handled;
	}
	new maxlen = TF2IDB_ATTRIBCLASS_LENGTH;

	new Handle:arguments = CreateArray(sizeof(strSearch)+4);
	Format(strSearch, sizeof(strSearch), "%%%s%%", strSearch);
	PushArrayString(arguments, strSearch);
	new DBStatement:resultStatement = TF2IDB_CustomQuery("SELECT id, name, attribute_class FROM tf2idb_attributes WHERE (attribute_class LIKE ?)", arguments, maxlen);
	CloseHandle(arguments);
	new iResults;
	new Handle:hResults = CreateArray(maxlen+1);

	decl String:strAttribName[maxlen];
	decl String:strAttribClass[maxlen];

	if (resultStatement != INVALID_HANDLE) {
		while (SQL_FetchRow(resultStatement)) {
			new id = SQL_FetchInt(resultStatement, 0);
			SQL_FetchString(resultStatement, 1, strAttribName, maxlen);
			SQL_FetchString(resultStatement, 2, strAttribClass, maxlen);
			PushArrayCell(hResults, id);
			PushArrayString(hResults, strAttribName);
			PushArrayString(hResults, strAttribClass);
		}
		CloseHandle(resultStatement);
	}

	ReplyToCommand( iClient, "Found %d attributes (p. %d/%d):", iResults, ( iResults ? iPage : 0 ), RoundToCeil( float( iResults ) / float(SEARCH_ITEMSPERPAGE) ) );

	iPage--;
	new iMin = SEARCH_ITEMSPERPAGE * iPage;
	iMin = ( iMin < 0 ? 0 : iMin );
	new iMax = SEARCH_ITEMSPERPAGE * (iPage+1);
	iMax = ( iMax >= iResults ? iResults : iMax );

	if (iResults) {
		for (new i = iMin; i < iMax; i++) {
			GetArrayString(hResults, 3*i+1, strAttribName, maxlen);
			GetArrayString(hResults, 3*i+2, strAttribClass, maxlen);
			ReplyToCommand( iClient, "- %d: %s (%s)", GetArrayCell(hResults, 3*i), strAttribName, strAttribClass );
		}
	}
	CloseHandle( hResults );

	return Plugin_Handled;
}

///////////////////
/* CVar handlers */
///////////////////

public OnConVarChanged_PluginVersion( Handle:hConVar, const String:strOldValue[], const String:strNewValue[] ) {
	if( strcmp( strNewValue, PLUGIN_VERSION, false ) != 0 ) {
		SetConVarString( hConVar, PLUGIN_VERSION, true, true );
	}
}
public OnConVarChanged( Handle:hConVar, const String:strOldValue[], const String:strNewValue[] ) {
	GetConVars();
}

///////////////////////
/* Private functions */
///////////////////////

stock ReloadConfigs()
{
	decl String:strBuffer[128];

	new Handle:hItemConfig = CreateKeyValues("items_config");

	decl String:strFilePath[PLATFORM_MAX_PATH] = "data/tf2itemsinfo.txt";
	BuildPath( Path_SM, strFilePath, sizeof(strFilePath), strFilePath );
	if( !FileExists( strFilePath ) ) {
		Error( ERROR_LOG, _, "Missing config file, making empty at %s", strFilePath );
		KeyValuesToFile( hItemConfig, strFilePath );
		CloseHandle( hItemConfig );
		return;
	}
	if (g_hItemProperties == INVALID_HANDLE) {
		g_hItemProperties = CreateTrie();
	}

	FileToKeyValues( hItemConfig, strFilePath );
	KvRewind( hItemConfig );

	if( KvGotoFirstSubKey( hItemConfig ) ) {
		new iItemDefID, iProperty;
		do {
			KvGetSectionName( hItemConfig, strBuffer, sizeof(strBuffer) );
			if (!IsCharNumeric(strBuffer[0])) {
				continue;
			}
			iItemDefID = StringToInt( strBuffer );
			if (!( 0 <= iItemDefID <= GetMaxItemID())) {
				continue;
			}

			iProperty = ItemProperties_Get( iItemDefID );
			if( KvGetNum( hItemConfig, "unusual", 0 ) )
				iProperty |= TF2II_PROP_UNUSUAL;
			if( KvGetNum( hItemConfig, "vintage", 0 ) )
				iProperty |= TF2II_PROP_VINTAGE;
			if( KvGetNum( hItemConfig, "strange", 0 ) )
				iProperty |= TF2II_PROP_STRANGE;
			if( KvGetNum( hItemConfig, "haunted", 0 ) )
				iProperty |= TF2II_PROP_HAUNTED;
			if( KvGetNum( hItemConfig, "halloween", 0 ) )
				iProperty |= TF2II_PROP_HALLOWEEN;
			if( KvGetNum( hItemConfig, "promotional", 0 ) )
				iProperty |= TF2II_PROP_PROMOITEM;
			if( KvGetNum( hItemConfig, "genuine", 0 ) )
				iProperty |= TF2II_PROP_GENUINE;
			if( KvGetNum( hItemConfig, "medieval", 0 ) )
				iProperty |= TF2II_PROP_MEDIEVAL;
			ItemProperties_Set( iItemDefID, iProperty );
		}
		while( KvGotoNextKey( hItemConfig ) );
	}

	CloseHandle( hItemConfig );

	Error( ERROR_NONE, _, "Item config loaded." );
}

int GetAttribIDByName( const String:strSearch[] ) {
	new maxlen = 128;
	new Handle:arguments = CreateArray(maxlen);
	PushArrayString(arguments, strSearch);
	new DBStatement:resultStatement = TF2IDB_CustomQuery("SELECT id FROM tf2idb_attributes WHERE name=?", arguments, maxlen);
	CloseHandle(arguments);
	if (resultStatement == INVALID_HANDLE) {
		return -1;
	}
	if (SQL_FetchRow(resultStatement)) {
		new result = SQL_FetchInt(resultStatement, 0);
		CloseHandle(resultStatement);
		return result;
	}
	CloseHandle(resultStatement);
	return -1;
}
TF2ItemQuality:GetQualityByName( const String:strSearch[] ) {
	return TF2IDB_GetQualityByName(strSearch);
}

//////////////////////
/* Native functions */
//////////////////////

public Native_IsItemSchemaPrecached( Handle:hPlugin, nParams ) {
	return bSchemaLoaded;
}

public Native_IsValidItemID( Handle:hPlugin, nParams )
{
	return TF2IDB_IsValidItemID( GetNativeCell(1) );
}
public Native_GetItemName( Handle:hPlugin, nParams )
{
	new iBufferLength = GetNativeCell(3);
	decl String:strBuffer[iBufferLength+1];
	new bool:bResult = TF2IDB_GetItemName(GetNativeCell(1), strBuffer, iBufferLength);
	SetNativeString( 2, strBuffer, iBufferLength );
	return bResult;
}
public Native_GetItemClass( Handle:hPlugin, nParams )
{
	new iBufferLength = GetNativeCell(3);
	decl String:strBuffer[iBufferLength+1];
	new bool:bResult = TF2IDB_GetItemClass( GetNativeCell(1), strBuffer, iBufferLength );
	new TFClassType:iPlayerClass = nParams >= 4 ? ( TFClassType:GetNativeCell(4) ) : TFClass_Unknown;
	if( StrEqual( strBuffer, "tf_weapon_shotgun", false ) ) {
		switch( iPlayerClass )
		{
			case TFClass_Soldier:	Format(	strBuffer,	iBufferLength,	"%s_soldier",	strBuffer	);
			case TFClass_Heavy:		Format(	strBuffer,	iBufferLength,	"%s_hwg",		strBuffer	);
			case TFClass_Pyro:		Format(	strBuffer,	iBufferLength,	"%s_pyro",		strBuffer	);
			case TFClass_Engineer:	Format(	strBuffer,	iBufferLength,	"%s_primary",	strBuffer	);
		}
	}
	SetNativeString( 2, strBuffer, iBufferLength );
	return bResult;
}
public Native_GetItemSlot( Handle:hPlugin, nParams ) {
	// TODO: Make this call TF2IDB_GetItemSlot instead, if possible, while still applying TF2II logic
	decl String:strSlot[TF2IDB_ITEMSLOT_LENGTH];
	new TFClassType:iPClass = nParams >= 2 ? (TFClassType:GetNativeCell(2)) : TFClass_Unknown;
	if (TF2IDB_GetItemSlotName(GetNativeCell(1), strSlot, sizeof(strSlot), iPClass)) {
		return _:TF2II_GetSlotByName(strSlot, iPClass);
	}
	return -1;
}
public Native_GetItemSlotName( Handle:hPlugin, nParams )
{
	new iBufferLength = GetNativeCell(3);
	decl String:strBuffer[iBufferLength+1];
	new bool:bResult = TF2IDB_GetItemSlotName( GetNativeCell(1), strBuffer, iBufferLength );
	SetNativeString( 2, strBuffer, iBufferLength );
	return bResult;
}
public Native_GetListedItemSlot( Handle:hPlugin, nParams )
{
	return Native_GetItemSlot(hPlugin, nParams);
}
public Native_GetListedItemSlotName( Handle:hPlugin, nParams )
{
	return Native_GetItemSlotName(hPlugin, nParams);
}
public Native_GetItemQuality( Handle:hPlugin, nParams )
{
	return _:TF2IDB_GetItemQuality(GetNativeCell(1));
}
public Native_GetItemQualityName( Handle:hPlugin, nParams )
{
	new iBufferLength = GetNativeCell(3);
	decl String:strBuffer[iBufferLength+1];
	new bool:bResult = TF2IDB_GetItemQualityName( GetNativeCell(1), strBuffer, iBufferLength );
	SetNativeString( 2, strBuffer, iBufferLength );
	return bResult;
}
public Native_GetToolType( Handle:hPlugin, nParams ) {
	new iBufferLength = GetNativeCell(3);
	new String:strBuffer[iBufferLength+1];
	new bool:val = GetToolType(GetNativeCell(1), strBuffer, iBufferLength);
	if (val) {
		SetNativeString(2, strBuffer, iBufferLength);
	}
	return val;
}
stock bool:GetToolType(iItemDefID, String:strBuffer[], iBufferLength) {
	decl String:strId[16];
	new Handle:arguments = CreateArray(16);
	IntToString(iItemDefID, strId, sizeof(strId));
	PushArrayString(arguments, strId);
	new DBStatement:resultStatement = TF2IDB_CustomQuery("SELECT tool_type FROM tf2idb_item WHERE id=?", arguments, iBufferLength);
	CloseHandle(arguments);
	if (resultStatement == INVALID_HANDLE) {
		return false;
	}
	if (SQL_FetchRow(resultStatement)) {
		SQL_FetchString(resultStatement, 0, strBuffer, iBufferLength);
		CloseHandle(resultStatement);
		return true;
	}
	CloseHandle(resultStatement);
	return false;
}
public Native_IsItemUsedByClass( Handle:hPlugin, nParams )
{
	new iItemDefID = GetNativeCell(1);
	if( !IsValidItemID(iItemDefID) )
		return false;

	new iClass = GetNativeCell(2);
	new String:query[128];
	static String:strClassMappings[][] = {
		"unknown", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer"
	};
	if (iClass >= _:TFClassType || iClass < 0) {
		return false;
	}
	FormatEx(query, sizeof(query), "SELECT id FROM tf2idb_class WHERE id=%d AND class='%s'", iItemDefID, strClassMappings[iClass]);
	new Handle:result = TF2IDB_FindItemCustom(query);
	new bool:retVal = (GetArraySize(result) > 0 && GetArrayCell(result, 0) == iItemDefID);
	CloseHandle(result);
	return retVal;
}
public Native_GetItemMinLevel( Handle:hPlugin, nParams )
{
	int min, max;
	TF2IDB_GetItemLevels(GetNativeCell(1), min, max);
	return min;
}
public Native_GetItemMaxLevel( Handle:hPlugin, nParams )
{
	int min, max;
	TF2IDB_GetItemLevels(GetNativeCell(1), min, max);
	return max;
}
public Native_GetItemNumAttributes( Handle:hPlugin, nParams )
{
	int aid[TF2IDB_MAX_ATTRIBUTES];
	float values[TF2IDB_MAX_ATTRIBUTES];
	return TF2IDB_GetItemAttributes(GetNativeCell(1), aid, values);
}
public Native_GetItemAttributeName( Handle:hPlugin, nParams )
{
	int aid[TF2IDB_MAX_ATTRIBUTES];
	float values[TF2IDB_MAX_ATTRIBUTES];
	int count = TF2IDB_GetItemAttributes(GetNativeCell(1), aid, values);
	new index = GetNativeCell(2);
	if (index >= count)
		return false;

	new iAttributeNameLength = GetNativeCell(4);
	decl String:strAttributeName[iAttributeNameLength+1];
	new bool:bResult = TF2IDB_GetAttributeName(aid[index], strAttributeName, iAttributeNameLength);
	SetNativeString( 2, strAttributeName, iAttributeNameLength );
	return bResult;
}
public Native_GetItemAttributeID( Handle:hPlugin, nParams )
{
	int aid[TF2IDB_MAX_ATTRIBUTES];
	float values[TF2IDB_MAX_ATTRIBUTES];
	int count = TF2IDB_GetItemAttributes(GetNativeCell(1), aid, values);
	int index = GetNativeCell(2);
	if (index >= count)
		return false;
	return aid[index];
}
public Native_GetAttributeValue( Handle:hPlugin, nParams )
{
	int aid[TF2IDB_MAX_ATTRIBUTES];
	float values[TF2IDB_MAX_ATTRIBUTES];
	int count = TF2IDB_GetItemAttributes(GetNativeCell(1), aid, values);
	int index = GetNativeCell(2);
	if (index >= count)
		return false;
	return _:values[index];
}
public Native_GetItemAttributes( Handle:hPlugin, nParams )
{
	int aid[TF2IDB_MAX_ATTRIBUTES];
	float values[TF2IDB_MAX_ATTRIBUTES];
	int count = TF2IDB_GetItemAttributes(GetNativeCell(1), aid, values);
	new Handle:hAttributes = CreateArray();
	for (int i = 0; i < count; i++)
	{
		PushArrayCell(hAttributes, aid[i]);
		PushArrayCell(hAttributes, values[i]);
	}
	new Handle:hOutput = CloneHandle( hAttributes, hPlugin );
	CloseHandle( hAttributes );
	return _:hOutput;
}
public Native_ItemHolidayRestriction( Handle:hPlugin, nParams )
{
	new iItemDefID = GetNativeCell(1);
	new TFHoliday:holiday = TFHoliday:GetNativeCell(2);
	if (holiday == TFHoliday_Birthday)
		return ItemHasProp( iItemDefID, TF2II_PROP_BDAY_STRICT );
	if (holiday == TFHoliday_Halloween || holiday == TFHoliday_FullMoon || holiday == TFHoliday_HalloweenOrFullMoon)
		return ItemHasProp( iItemDefID, TF2II_PROP_HOFM_STRICT );
	if (holiday == TFHoliday_Christmas)
		return ItemHasProp( iItemDefID, TF2II_PROP_XMAS_STRICT );
	return false;
}
public Native_GetItemEquipRegions( Handle:hPlugin, nParams )
{
	new Handle:result = TF2IDB_GetItemEquipRegions(GetNativeCell(1));
	new Handle:ret = CloneHandle(result, hPlugin);
	CloseHandle(result);
	return _:ret;
}
public Native_ItemHasProperty( Handle:hPlugin, nParams )
{
	return ItemHasProp( GetNativeCell(1), GetNativeCell(2) );
}

public Native_IsValidAttribID( Handle:hPlugin, nParams )
{
	return IsValidAttribID( GetNativeCell(1) );
}
public Native_GetAttribName( Handle:hPlugin, nParams )
{
	new iBufferLength = GetNativeCell(3);
	decl String:strBuffer[iBufferLength+1];
	new bool:bResult = TF2IDB_GetAttributeName(GetNativeCell(1), strBuffer, iBufferLength);
	SetNativeString( 2, strBuffer, iBufferLength );
	return bResult;
}
public Native_GetAttribClass( Handle:hPlugin, nParams )
{
	new iBufferLength = GetNativeCell(3);
	decl String:strBuffer[iBufferLength+1];
	new bool:bResult = TF2IDB_GetAttributeClass(GetNativeCell(1), strBuffer, iBufferLength);
	SetNativeString( 2, strBuffer, iBufferLength );
	return bResult;
}
public Native_GetAttribDispName( Handle:hPlugin, nParams )
{
	return Native_GetAttribName(hPlugin, nParams);
}
public Native_GetAttribMinValue( Handle:hPlugin, nParams )
{
	return 0;
}
public Native_GetAttribMaxValue( Handle:hPlugin, nParams )
{
	return 0;
}
public Native_GetAttribGroup( Handle:hPlugin, nParams )
{
	return false;
}
public Native_GetAttribDescrString( Handle:hPlugin, nParams )
{
	new iBufferLength = GetNativeCell(3);
	decl String:strBuffer[iBufferLength+1];
	new bool:bResult = TF2IDB_GetAttributeDescString(GetNativeCell(1), strBuffer, iBufferLength);
	SetNativeString( 2, strBuffer, iBufferLength );
	return bResult;
}
public Native_GetAttribDescrFormat( Handle:hPlugin, nParams )
{
	new iBufferLength = GetNativeCell(3);
	decl String:strBuffer[iBufferLength+1];
	new bool:bResult = TF2IDB_GetAttributeDescFormat(GetNativeCell(1), strBuffer, iBufferLength);
	SetNativeString( 2, strBuffer, iBufferLength );
	return bResult;
}
public Native_HiddenAttrib( Handle:hPlugin, nParams )
{
	int result;
	TF2IDB_GetAttributeProperties(GetNativeCell(1), result, _, _, _, _);
	return result == 1;
}
public Native_GetAttribEffectType( Handle:hPlugin, nParams )
{
	new iAttribID = GetNativeCell(1);
	if( AttribHasProp( iAttribID, TF2II_PROP_EFFECT_POSITIVE ) )
		return 1;
	else if( AttribHasProp( iAttribID, TF2II_PROP_EFFECT_NEGATIVE ) )
		return -1;
	return 0;
}
public Native_AttribStoredAsInteger( Handle:hPlugin, nParams )
{
	int result;
	TF2IDB_GetAttributeProperties(GetNativeCell(1), _, result, _, _, _);
	return result == 1;
}
public Native_AttribHasProperty( Handle:hPlugin, nParams )
{
	if (nParams < 2) {
		return IsValidAttribID(GetNativeCell(1));
	}
	return AttribHasProp( GetNativeCell(1), GetNativeCell(2) );
}

public Native_GetAttribKeyValues( Handle:hPlugin, nParams )
{
	new maxlen = TF2IDB_ATTRIBNAME_LENGTH;
	decl String:strId[16];
	new Handle:arguments = CreateArray(sizeof(strId));
	IntToString(GetNativeCell(1), strId, sizeof(strId));
	PushArrayString(arguments, strId);
	new DBStatement:resultStatement = TF2IDB_CustomQuery("SELECT * FROM tf2idb_attributes WHERE id=?", arguments, maxlen);
	CloseHandle(arguments);
	if (resultStatement == INVALID_HANDLE) {
		return _:INVALID_HANDLE;
	}
	new Handle:hCopy = CreateKeyValues( "attribute_data" );
	new fieldCount = SQL_GetFieldCount(resultStatement);
	decl String:strField[maxlen+1];
	decl String:strVal[maxlen+1];
	while (SQL_FetchRow(resultStatement)) {
		for (new i = 0; i < fieldCount; i++) {
			SQL_FieldNumToName(resultStatement, i, strField, maxlen);
			if (StrEqual(strField, "id", false)) continue;	//skip ID
			SQL_FetchString(resultStatement, i, strVal, maxlen);
			if (strVal[0] == '\0') continue;
			KvSetString(hCopy, strField, strVal);
		}
	}
	CloseHandle(resultStatement);
	new Handle:hOutput = CloneHandle( hCopy, hPlugin );
	CloseHandle( hCopy );
	return _:hOutput;
}
public Native_GetAttribKey( Handle:hPlugin, nParams )
{
	new maxlen = TF2IDB_ATTRIBNAME_LENGTH;
	decl String:strKey[128];
	GetNativeString( 2, strKey, sizeof(strKey) );
	decl String:strId[16];
	new Handle:arguments = CreateArray(sizeof(strId));
	IntToString(GetNativeCell(1), strId, sizeof(strId));
	PushArrayString(arguments, strId);
	Format(strKey, sizeof(strKey), "SELECT %s FROM tf2idb_attributes WHERE id=?", strKey);
	new DBStatement:resultStatement = TF2IDB_CustomQuery(strKey, arguments, maxlen);
	CloseHandle(arguments);
	if (resultStatement == INVALID_HANDLE) {
		return 0;
	}
	if (SQL_FetchRow(resultStatement)) {
		int val = SQL_FetchInt(resultStatement, 0);
		CloseHandle(resultStatement);
		return val;
	}
	CloseHandle(resultStatement);
	return 0;
}
public Native_GetAttribKeyFloat( Handle:hPlugin, nParams )
{
	new maxlen = TF2IDB_ATTRIBNAME_LENGTH;
	decl String:strKey[128];
	GetNativeString( 2, strKey, sizeof(strKey) );
	decl String:strId[16];
	new Handle:arguments = CreateArray(sizeof(strId));
	IntToString(GetNativeCell(1), strId, sizeof(strId));
	PushArrayString(arguments, strId);
	Format(strKey, sizeof(strKey), "SELECT %s FROM tf2idb_attributes WHERE id=?", strKey);
	new DBStatement:resultStatement = TF2IDB_CustomQuery(strKey, arguments, maxlen);
	CloseHandle(arguments);
	if (resultStatement == INVALID_HANDLE) {
		return _:0.0;
	}
	if (SQL_FetchRow(resultStatement)) {
		float val = SQL_FetchFloat(resultStatement, 0);
		CloseHandle(resultStatement);
		return _:val;
	}
	CloseHandle(resultStatement);
	return _:0.0;
}
public Native_GetAttribKeyString( Handle:hPlugin, nParams )
{
	new maxlen = GetNativeCell(4);
	decl String:strKey[128];
	GetNativeString( 2, strKey, sizeof(strKey) );
	decl String:strId[16];
	new Handle:arguments = CreateArray(sizeof(strId));
	IntToString(GetNativeCell(1), strId, sizeof(strId));
	PushArrayString(arguments, strId);
	Format(strKey, sizeof(strKey), "SELECT %s FROM tf2idb_attributes WHERE id=?", strKey);
	new DBStatement:resultStatement = TF2IDB_CustomQuery(strKey, arguments, maxlen);
	CloseHandle(arguments);
	if (resultStatement == INVALID_HANDLE) {
		return 0;
	}
	decl String:strVal[maxlen+1];
	if (SQL_FetchRow(resultStatement)) {
		int val = SQL_FetchString(resultStatement, 0, strVal, maxlen);
		SetNativeString(3, strVal, maxlen);
		CloseHandle(resultStatement);
		return val;
	}
	CloseHandle(resultStatement);
	return 0;
}

public Native_IsConflictRegions( Handle:hPlugin, nParams )
{
	decl String:strERA[16], String:strERB[16];
	GetNativeString( 1, strERA, sizeof(strERA) );
	GetNativeString( 2, strERB, sizeof(strERB) );
	return TF2IDB_DoRegionsConflict(strERA, strERB);
}
public Native_GetQualityByName( Handle:hPlugin, nParams )
{
	decl String:strQualityName[TF2II_ITEMQUALITY_LENGTH];
	GetNativeString( 1, strQualityName, TF2II_ITEMQUALITY_LENGTH-1 );
	return _:GetQualityByName( strQualityName );
}
public Native_GetQualityName( Handle:hPlugin, nParams )
{
	new iQualityNum = GetNativeCell(1);
	new iQualityNameLength = GetNativeCell(3);
	decl String:strQualityName[iQualityNameLength+1];
	if (!TF2IDB_GetQualityName(TF2ItemQuality:iQualityNum, strQualityName, iQualityNameLength))
		return false;
	SetNativeString( 2, strQualityName, iQualityNameLength );
	return true;
}

public Native_GetAttributeIDByName( Handle:hPlugin, nParams )
{
	decl String:strAttribName[TF2IDB_ATTRIBNAME_LENGTH];
	GetNativeString( 1, strAttribName, TF2IDB_ATTRIBNAME_LENGTH-1 );
	return GetAttribIDByName( strAttribName );
}
public Native_GetAttributeNameByID( Handle:hPlugin, nParams )
{
	return Native_GetAttribName(hPlugin, nParams);
}

public Native_FindItemsIDsByCond( Handle:hPlugin, nParams )
{
	Error( ERROR_LOG|ERROR_NOPRINT, SP_ERROR_NATIVE, "Deprecated function. Use TF2II_FindItems instead." );

	decl String:strClass[64], String:strSlot[64], String:strTool[64];
	GetNativeString( 1, strClass, sizeof(strClass) );
	new iSlot = GetNativeCell(2);
	GetNativeString( 3, strSlot, sizeof(strSlot) );
	GetNativeString( 6, strTool, sizeof(strTool) );
	new bool:bClassFilter = GetNativeCell(4);
	new nClasses = _:TFClassType;
	new bool:bUsedByClass[nClasses];
	new iUsedByClass = TF2II_CLASS_NONE;

	if( bClassFilter )
	{
		GetNativeArray( 5, bUsedByClass, nClasses-1 );
		for( new c = 0; c < nClasses; c++ )
			if( bUsedByClass[c] )
				iUsedByClass |= ( 1 << ( c - 1 ) );
	}

	if( strlen(strSlot) <= 0 && iSlot > -1 )
	{
		switch( TF2ItemSlot:iSlot )
		{
			case TF2ItemSlot_Primary:	strcopy( strSlot, sizeof(strSlot), "primary" );
			case TF2ItemSlot_Secondary:	strcopy( strSlot, sizeof(strSlot), "secondary" );
			case TF2ItemSlot_Melee:		strcopy( strSlot, sizeof(strSlot), "melee" );
			case TF2ItemSlot_Building:	strcopy( strSlot, sizeof(strSlot), "building" );
			case TF2ItemSlot_PDA1:		strcopy( strSlot, sizeof(strSlot), "pda" );
			case TF2ItemSlot_PDA2:		strcopy( strSlot, sizeof(strSlot), "pda2" );
			//case TF2ItemSlot_Head:		strcopy( strSlot, sizeof(strSlot), "head" );
			case TF2ItemSlot_Misc:		strcopy( strSlot, sizeof(strSlot), "misc" );
			case TF2ItemSlot_Action:	strcopy( strSlot, sizeof(strSlot), "action" );
		}
	}
	return _:Internal_FindItems(hPlugin, strClass, strSlot, iUsedByClass, strTool);
}

public Native_FindItems( Handle:hPlugin, nParams )
{
	decl String:strClass[64], String:strSlot[64], String:strTool[64];
	GetNativeString( 1, strClass, sizeof(strClass) );
	GetNativeString( 2, strSlot, sizeof(strSlot) );
	new iUsedByClass = GetNativeCell(3);
	GetNativeString( 4, strTool, sizeof(strTool) );
	return _:Internal_FindItems(hPlugin, strClass, strSlot, iUsedByClass, strTool);
}
stock Handle:Internal_FindItems(Handle:hPlugin, String:strClass[], String:strSlot[], iUsedByClass, String:strTool[])
{
	char classes[9][32] = {"scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer"};
	int paramCount = 0;
	if (strClass[0])
	{
		paramCount++;
	}
	if (strSlot[0])
	{
		paramCount++;
	}
	if (strTool[0])
	{
		paramCount++;
	}

	char query[512];
	strcopy(query, sizeof(query), "SELECT a.id FROM tf2idb_item a");
	if (iUsedByClass)
	{
		StrCat(query, sizeof(query), " JOIN tf2idb_class b ON a.id=b.id WHERE (0");
		for (int i = 0; i < 9; i++)
		{
			if (!(iUsedByClass & (1 << i))) continue;
			Format(query, sizeof(query), "%s OR b.class='%s'", query, classes[i]);
		}
		StrCat(query, sizeof(query), ")");
		if (paramCount)
		{
			StrCat(query, sizeof(query), " AND");
		}
	}
	else
	{
		if (paramCount)
		{
			StrCat(query, sizeof(query), " WHERE");
		}
	}
	if (strClass[0])
	{
		Format(query, sizeof(query), "%s a.class='%s'", query, strClass);
		paramCount--;
		if (paramCount > 0)
			StrCat(query, sizeof(query), " AND");
	}
	if (strSlot[0])
	{
		Format(query, sizeof(query), "%s a.slot='%s'", query, strSlot);
		paramCount--;
		if (paramCount > 0)
			StrCat(query, sizeof(query), " AND");
	}
	if (strTool[0])
	{
		Format(query, sizeof(query), "%s a.tool_type='%s'", query, strTool);
		paramCount--;
//		if (paramCount > 0)
//			StrCat(query, sizeof(query), " AND");
	}

	new Handle:hResults = TF2IDB_FindItemCustom(query);

	Call_StartForward( hForward_OnFindItems );
	Call_PushString( strClass );
	Call_PushString( strSlot );
	Call_PushCell( iUsedByClass );
	Call_PushString( strTool );
	Call_PushCellRef( hResults );
	Call_Finish();

	new Handle:ret = CloneHandle(hResults, hPlugin);
	CloseHandle(hResults);
	return ret;
}
public Native_ListEffects( Handle:hPlugin, nParams )
{
	Handle result = TF2IDB_ListParticles();
	Handle ret = CloneHandle(result, hPlugin);
	CloseHandle(result);
	return _:ret;
}

public Native_DeprecatedFunction( Handle:hPlugin, nParams )
{
	Error( ERROR_BREAKN|ERROR_LOG|ERROR_NOPRINT, SP_ERROR_ABORTED, "Deprecated function." );
	return 0;
}
public Native_UnsupportedFunction( Handle:hPlugin, nParams )
{
	Error( ERROR_BREAKN|ERROR_LOG|ERROR_NOPRINT, SP_ERROR_ABORTED, "Unsupported function." );
	return 0;
}

//////////////////
/* SQL handlers */
//////////////////

public SQL_ErrorCheck( Handle:hOwner, Handle:hQuery, const String:strError[], any:iUnused ) {
	if( strlen( strError ) ) {
		LogError( "MySQL DB error: %s", strError );
	}
}
/////////////////////
/* Stock functions */
/////////////////////

stock Error( iFlags = ERROR_NONE, iNativeErrCode = SP_ERROR_NONE, const String:strMessage[], any:... )
{
	decl String:strBuffer[1024];
	VFormat( strBuffer, sizeof(strBuffer), strMessage, 4 );

	if( iFlags )
	{
		if( (iFlags & ERROR_LOG) && bUseLogs )
		{
			decl String:strFile[PLATFORM_MAX_PATH];
			FormatTime( strFile, sizeof(strFile), "%Y%m%d" );
			Format( strFile, sizeof(strFile), "TF2II%s", strFile );
			BuildPath( Path_SM, strFile, sizeof(strFile), "logs/%s.log", strFile );
			LogToFileEx( strFile, strBuffer );
		}

		if( iFlags & ERROR_BREAKF )
			ThrowError( strBuffer );
		if( iFlags & ERROR_BREAKN )
			ThrowNativeError( iNativeErrCode, strBuffer );
		if( iFlags & ERROR_BREAKP )
			SetFailState( strBuffer );

		if( iFlags & ERROR_NOPRINT )
			return;
	}

	PrintToServer( "[TF2ItemsInfo] %s", strBuffer );
}

//////////////////////////
/* ItemData_* functions */
//////////////////////////

stock Handle:ItemData_Create( iItemDefID, bReplace = true )
{
	new Handle:hArray = INVALID_HANDLE;

	new iIndex = ItemData_GetIndex( iItemDefID );
	if( iIndex >= 0 && iIndex < GetArraySize(g_hItemData) )
	{
		hArray = Handle:GetArrayCell( g_hItemData, iIndex );
		if( hArray != INVALID_HANDLE )
		{
			if( bReplace )
			{
				ItemData_Destroy( iItemDefID );
				hArray = ItemData_CreateArray( iItemDefID );
				SetArrayCell( g_hItemData, iIndex, _:hArray );
			}
			return hArray;
		}
	}

	hArray = ItemData_CreateArray( iItemDefID );
	ItemData_SetIndex( iItemDefID, PushArrayCell( g_hItemData, _:hArray ) );
	return hArray;
}
stock Handle:ItemData_CreateArray( iItemDefID = -1 )
{
	new Handle:hArray = CreateArray( 16 );
	PushArrayCell( hArray, iItemDefID );
	PushArrayCell( hArray, TF2II_PROP_INVALID );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "tf_wearable" );
	PushArrayString( hArray, "none" );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayCell( hArray, 1 );
	PushArrayCell( hArray, 1 );
	PushArrayString( hArray, "normal" );
	PushArrayCell( hArray, TF2II_CLASS_NONE );
	PushArrayCell( hArray, _:INVALID_HANDLE );
	PushArrayCell( hArray, _:INVALID_HANDLE );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayCell( hArray, _:INVALID_HANDLE );
	if( GetArraySize(hArray) != _:ItemDataType )
	{
		CloseHandle( hArray );
		Error( ERROR_BREAKP, _, "Contact author and say about ItemData array size." );
	}
	return hArray;
}
stock bool:ItemData_Destroy( iItemDefID )
{
	new iIndex = ItemData_GetIndex( iItemDefID );
	if( iIndex >= 0 && iIndex < GetArraySize(g_hItemData) )
	{
		new Handle:hArray = Handle:GetArrayCell( g_hItemData, iIndex );
		if( hArray != INVALID_HANDLE )
		{
			if( Handle:GetArrayCell( hArray, _:ItemData_Attributes ) != INVALID_HANDLE )
				CloseHandle( Handle:GetArrayCell( hArray, _:ItemData_Attributes ) );
			if( Handle:GetArrayCell( hArray, _:ItemData_EquipRegions ) != INVALID_HANDLE )
				CloseHandle( Handle:GetArrayCell( hArray, _:ItemData_EquipRegions ) );
			if( Handle:GetArrayCell( hArray, _:ItemData_KeyValues ) != INVALID_HANDLE )
				CloseHandle( Handle:GetArrayCell( hArray, _:ItemData_KeyValues ) );
			CloseHandle( hArray );
			return true;
		}
	}
	return false;
}

stock ItemData_GetIndex( iItemDefID )
{
	decl String:strItemDefID[16];
	IntToString( iItemDefID, strItemDefID, sizeof(strItemDefID) );
	return g_hItemDataKeys != INVALID_HANDLE ? KvGetNum( g_hItemDataKeys, strItemDefID, -1 ) : -1;
}
stock ItemData_SetIndex( iItemDefID, iIndex )
{
	decl String:strItemDefID[16];
	IntToString( iItemDefID, strItemDefID, sizeof(strItemDefID) );
	if( g_hItemDataKeys != INVALID_HANDLE )
	{
		KvSetNum( g_hItemDataKeys, strItemDefID, iIndex );
		return true;
	}
	return false;
}

stock any:ItemData_GetCell( iItemDefID, ItemDataType:iIDType )
{
	int minLevel, maxLevel;
	if (iIDType == ItemData_MinLevel || iIDType == ItemData_MaxLevel) {
		TF2IDB_GetItemLevels(iItemDefID, minLevel, maxLevel);
	}
	switch (iIDType) {
		case ItemData_DefinitionID: return iItemDefID;
		case ItemData_MinLevel: return minLevel;
		case ItemData_MaxLevel: return maxLevel;
		case ItemData_UsedBy: return TF2IDB_UsedByClasses(iItemDefID) >> 1;
		case ItemData_EquipRegions: return TF2IDB_GetItemEquipRegions(iItemDefID);
		case ItemData_KeyValues: return INVALID_HANDLE;
		default: return 0;
	}
	return 0;
}


stock ItemData_GetString( iItemDefID, ItemDataType:iIDType, String:strValue[], iValueLength )
{
	switch (iIDType) {
		case ItemData_Name: TF2IDB_GetItemName(iItemDefID, strValue, iValueLength);
		case ItemData_ClassName: TF2IDB_GetItemClass(iItemDefID, strValue, iValueLength);
		case ItemData_Slot: TF2IDB_GetItemSlotName(iItemDefID, strValue, iValueLength);
		case ItemData_ListedSlot: TF2IDB_GetItemSlotName(iItemDefID, strValue, iValueLength);
		case ItemData_Tool: GetToolType(iItemDefID, strValue, iValueLength);
		case ItemData_Quality: TF2IDB_GetItemQualityName(iItemDefID, strValue, iValueLength);
		case ItemData_MLName: GetItemMLName(iItemDefID, strValue, iValueLength);
		default: strcopy(strValue, iValueLength, "");
	}
	return strlen(strValue);
}
stock bool:GetItemMLName(iItemDefID, String:strBuffer[], iBufferLength) {
	decl String:strId[16];
	new Handle:arguments = CreateArray(16);
	IntToString(iItemDefID, strId, sizeof(strId));
	PushArrayString(arguments, strId);
	new DBStatement:resultStatement = TF2IDB_CustomQuery("SELECT item_name FROM tf2idb_item WHERE id=?", arguments, iBufferLength);
	CloseHandle(arguments);
	if (resultStatement == INVALID_HANDLE) {
		return false;
	}
	if (SQL_FetchRow(resultStatement)) {
		SQL_FetchString(resultStatement, 0, strBuffer, iBufferLength);
		CloseHandle(resultStatement);
		return true;
	}
	CloseHandle(resultStatement);
	return false;
}
stock ItemData_SetString( iItemDefID, ItemDataType:iIDType, const String:strValue[] )
{
	new iIndex = ItemData_GetIndex( iItemDefID );
	if( iIndex < 0 || iIndex >= GetArraySize( g_hItemData ) )
		return 0;

	new iType = _:iIDType;
	if( iType < 0 || iType >= _:ItemDataType )
		return 0;

	new Handle:hArray = Handle:GetArrayCell( g_hItemData, iIndex );
	if( hArray != INVALID_HANDLE )
		return SetArrayString( hArray, iType, strValue );
	return 0;
}

////////////////////////////
/* AttribData_* functions */
////////////////////////////

stock Handle:AttribData_Create( iAttribID, bReplace = true )
{
	new Handle:hArray = INVALID_HANDLE;

	new iIndex = AttribData_GetIndex( iAttribID );
	if( iIndex >= 0 && iIndex < GetArraySize(g_hAttribData) )
	{
		hArray = Handle:GetArrayCell( g_hAttribData, iIndex );
		if( hArray != INVALID_HANDLE )
		{
			if( bReplace )
			{
				AttribData_Destroy( iAttribID );
				hArray = AttribData_CreateArray( iAttribID );
				SetArrayCell( g_hAttribData, iIndex, _:hArray );
			}
			return hArray;
		}
	}

	hArray = AttribData_CreateArray( iAttribID );
	AttribData_SetIndex( iAttribID, PushArrayCell( g_hAttribData, _:hArray ) );
	return hArray;
}
stock Handle:AttribData_CreateArray( iAttribID = -1 )
{
	new Handle:hArray = CreateArray( 24 );
	PushArrayCell( hArray, iAttribID );
	PushArrayCell( hArray, TF2II_PROP_INVALID );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayCell( hArray, _:(1.0) );
	PushArrayCell( hArray, _:(1.0) );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayString( hArray, "" );
	PushArrayCell( hArray, _:INVALID_HANDLE );
	if( GetArraySize(hArray) != _:AttribDataType )
	{
		CloseHandle( hArray );
		Error( ERROR_BREAKP, _, "Contact author and say about AttribData array size." );
	}
	return hArray;
}
stock bool:AttribData_Destroy( iAttribID )
{
	new iIndex = AttribData_GetIndex( iAttribID );
	if( iIndex >= 0 && iIndex < GetArraySize(g_hAttribData) )
	{
		new Handle:hArray = Handle:GetArrayCell( g_hAttribData, iIndex );
		if( hArray != INVALID_HANDLE )
		{
			if( Handle:GetArrayCell( hArray, _:AttribData_KeyValues ) != INVALID_HANDLE )
				CloseHandle( Handle:GetArrayCell( hArray, _:AttribData_KeyValues ) );
			CloseHandle( hArray );
			return true;
		}
	}
	return false;
}

stock AttribData_GetIndex( iAttribID )
{
	decl String:strItemDefID[16];
	IntToString( iAttribID, strItemDefID, sizeof(strItemDefID) );
	return g_hAttribDataKeys != INVALID_HANDLE ? KvGetNum( g_hAttribDataKeys, strItemDefID, -1 ) : -1;
}
stock AttribData_SetIndex( iAttribID, iIndex )
{
	decl String:strItemDefID[16];
	IntToString( iAttribID, strItemDefID, sizeof(strItemDefID) );
	if( g_hAttribDataKeys != INVALID_HANDLE )
	{
		KvSetNum( g_hAttribDataKeys, strItemDefID, iIndex );
		return true;
	}
	return false;
}

stock AttribData_GetCell( iAttribID, AttribDataType:iADType )
{
	new iIndex = AttribData_GetIndex( iAttribID );
	if( iIndex < 0 || iIndex >= GetArraySize( g_hAttribData ) )
		return 0;

	new iType = _:iADType;
	if( iType < 0 || iType >= _:AttribDataType )
		return 0;

	new Handle:hArray = Handle:GetArrayCell( g_hAttribData, iIndex );
	if( hArray != INVALID_HANDLE )
		return GetArrayCell( hArray, iType );
	return 0;
}
stock bool:AttribData_SetCell( iAttribID, AttribDataType:iADType, iValue )
{
	new iIndex = AttribData_GetIndex( iAttribID );
	if( iIndex < 0 || iIndex >= GetArraySize( g_hAttribData ) )
		return false;

	new iType = _:iADType;
	if( iType < 0 || iType >= _:AttribDataType )
		return false;

	new Handle:hArray = Handle:GetArrayCell( g_hAttribData, iIndex );
	if( hArray != INVALID_HANDLE )
	{
		SetArrayCell( hArray, iType, iValue );
		return true;
	}
	return false;
}

stock AttribData_GetString( iAttribID, AttribDataType:iADType, String:strValue[], iValueLength )
{
	new iIndex = AttribData_GetIndex( iAttribID );
	if( iIndex < 0 || iIndex >= GetArraySize( g_hAttribData ) )
		return 0;

	new iType = _:iADType;
	if( iType < 0 || iType >= _:AttribDataType )
		return 0;

	new Handle:hArray = Handle:GetArrayCell( g_hAttribData, iIndex );
	if( hArray != INVALID_HANDLE )
		return GetArrayString( hArray, iType, strValue, iValueLength );
	return 0;
}
stock AttribData_SetString( iAttribID, AttribDataType:iADType, const String:strValue[] )
{
	new iIndex = AttribData_GetIndex( iAttribID );
	if( iIndex < 0 || iIndex >= GetArraySize( g_hAttribData ) )
		return 0;

	new iType = _:iADType;
	if( iType < 0 || iType >= _:AttribDataType )
		return 0;

	new Handle:hArray = Handle:GetArrayCell( g_hAttribData, iIndex );
	if( hArray != INVALID_HANDLE )
		return SetArrayString( hArray, iType, strValue );
	return 0;
}

//////////////////////////
/* Validating functions */
//////////////////////////

stock bool:IsValidItemID( iItemDefID ) {
	return ( 0 <= iItemDefID <= GetMaxItemID() && TF2IDB_IsValidItemID(iItemDefID) );
}
stock bool:IsValidAttribID( iAttribID ) {
	return ( 0 < iAttribID <= GetMaxAttributeID() && TF2IDB_IsValidAttributeID(iAttribID) );
}

stock int GetMaxItemID() {
	static bool found = false;
	static int maxVal = 0;
	if (!bSchemaLoaded) {
		return OLD_MAX_ITEM_ID;
	}
	if (!found) {
		new Handle:list = TF2IDB_FindItemCustom("SELECT MAX(id) FROM tf2idb_item");
		maxVal = GetArrayCell(list, 0);
		CloseHandle(list);
		found = true;
	}
	return maxVal;
}

stock int GetMaxAttributeID() {
	static bool found = false;
	static int maxVal = 0;
	if (!bSchemaLoaded) {
		return OLD_MAX_ATTR_ID;
	}
	if (!found) {
		new Handle:list = TF2IDB_FindItemCustom("SELECT MAX(id) FROM tf2idb_attributes");
		maxVal = GetArrayCell(list, 0);
		CloseHandle(list);
		found = true;
	}
	return maxVal;
}
/*
#define TF2II_PROP_UNUSUAL				(1<<3)
#define TF2II_PROP_VINTAGE				(1<<4)
#define TF2II_PROP_STRANGE				(1<<5)
#define TF2II_PROP_HAUNTED				(1<<6)
#define TF2II_PROP_HALLOWEEN			(1<<7) // unused?
#define TF2II_PROP_PROMOITEM			(1<<8)
#define TF2II_PROP_GENUINE				(1<<9)
*/
stock bool:ItemHasProp( iItemDefID, iFlags )
{
	if( iFlags <= TF2II_PROP_INVALID )
		return false;
	return ( ItemProperties_Get(iItemDefID) & iFlags ) == iFlags;
}

stock ItemProperties_GetBase(iItemDefID) {
	if( !( 0 <= iItemDefID <= GetMaxItemID() ))
		return 0;
	if( !IsValidItemID( iItemDefID ) )
		return 0;
	new resultFlags = TF2II_PROP_VALIDITEM;
	resultFlags |= (TF2II_IsBaseItem(iItemDefID) ? TF2II_PROP_BASEITEM : 0);
	resultFlags |= (TF2II_IsItemPaintable(iItemDefID) ? TF2II_PROP_PAINTABLE : 0);
	resultFlags |= (TF2II_IsHalloweenItem(iItemDefID) ? TF2II_PROP_HALLOWEEN : 0);
	resultFlags |= (TF2II_IsMedievalWeapon(iItemDefID) ? TF2II_PROP_MEDIEVAL : 0);
	resultFlags |= (TF2II_IsBirthdayItem(iItemDefID) ? TF2II_PROP_BDAY_STRICT : 0);
	resultFlags |= (TF2II_IsHalloweenOrFullMoonItem(iItemDefID) ? TF2II_PROP_HOFM_STRICT : 0);
	resultFlags |= (TF2II_IsChristmasItem(iItemDefID) ? TF2II_PROP_XMAS_STRICT : 0);
	resultFlags |= (TF2II_HasProperName(iItemDefID) ? TF2II_PROP_PROPER_NAME : 0);
	return resultFlags;
}
stock ItemProperties_Get(iItemDefID) {
	new val = 0;
	new String:strId[16];
	IntToString(iItemDefID, strId, sizeof(strId));
	if (!GetTrieValue(g_hItemProperties, strId, val)) {
		val = 0;
	}
	return val | ItemProperties_GetBase(iItemDefID);
}
stock ItemProperties_Set(iItemDefID, iProperties) {
	new String:strId[16];
	IntToString(iItemDefID, strId, sizeof(strId));
	SetTrieValue(g_hItemProperties, strId, iProperties);
}

stock bool:AttribHasProp( iAttribID, iFlags )
{
	new hidden, stored_as_integer;
	new resultFlags;
	char effect_type[32];
	bool exists = TF2IDB_GetAttributeProperties(iAttribID, hidden, stored_as_integer, _, _, _);
	if( !( 0 < iAttribID <= GetMaxAttributeID() ) || iFlags <= TF2II_PROP_INVALID )
		return false;
	if (!exists) {
		return false;
	}
	resultFlags |= TF2II_PROP_VALIDATTRIB;
	resultFlags |= (hidden == 1 ? TF2II_PROP_HIDDEN : 0);
	resultFlags |= (stored_as_integer == 1 ? TF2II_PROP_STORED_AS_INTEGER : 0);
	TF2IDB_GetAttributeEffectType(iAttribID, effect_type, sizeof(effect_type));
	resultFlags |= (StrEqual(effect_type, "positive") ? TF2II_PROP_EFFECT_POSITIVE : 0);
	resultFlags |= (StrEqual(effect_type, "neutral") ? TF2II_PROP_EFFECT_NEUTRAL : 0);
	resultFlags |= (StrEqual(effect_type, "negative") ? TF2II_PROP_EFFECT_NEGATIVE : 0);

	return ( resultFlags & iFlags ) == iFlags;
}

stock bool:IsValidClient( _:iClient )
{
	if( iClient <= 0 || iClient > MaxClients ) return false;
	if( !IsClientConnected(iClient) || !IsClientInGame(iClient) ) return false;
#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 4
	if( IsClientSourceTV(iClient) || IsClientReplay(iClient) ) return false;
#endif
	return true;
}

//////////////////////////////////
/* FlaminSarge's KvCopyDataToKv */
//////////////////////////////////

stock KvCopyDataToKv( Handle:hSource, Handle:hDest, bool:bIAmASubKey = false )
{
	decl String:strNodeName[128];
	decl String:strNodeValue[1024];
	if( !bIAmASubKey || KvGotoFirstSubKey( hSource, false ) )
	{
		do
		{
			// You can read the section/key name by using KvGetSectionName here.
			KvGetSectionName( hSource, strNodeName, sizeof(strNodeName) );
			if( KvGotoFirstSubKey( hSource, false ) )
			{
				// Current key is a section. Browse it recursively.
				KvJumpToKey( hDest, strNodeName, true );
				KvCopyDataToKv( hSource, hDest );
				KvGoBack( hSource );
				KvGoBack( hDest );
			}
			else
			{
				// Current key is a regular key, or an empty section.
				if( KvGetDataType( hSource, NULL_STRING ) != KvData_None )
				{
					// Read value of key here. You can also get the key name
					// by using KvGetSectionName here.
					KvGetString( hSource, NULL_STRING, strNodeValue, sizeof(strNodeValue) );
					KvSetString( hDest, strNodeName, strNodeValue );
				}
				else
				{
					// Found an empty sub section. It can be handled here if necessary.
				}
			}
		}
		while( KvGotoNextKey( hSource, false ) );

		if( bIAmASubKey )
			KvGoBack( hSource );
	}
}
stock TF2ItemSlot:TF2II_GetSlotByName( const String:strSlot[], TFClassType:iClass = TFClass_Unknown )
{
	if( StrEqual( strSlot, "primary", false ) )
		return TF2ItemSlot_Primary;
	else if( StrEqual( strSlot, "secondary", false ) )
		return TF2ItemSlot_Secondary;
	else if( StrEqual( strSlot, "melee", false ) )
		return TF2ItemSlot_Melee;
	else if( StrEqual( strSlot, "pda", false ) )
		return TF2ItemSlot_PDA;
	else if( StrEqual( strSlot, "pda2", false ) )
		return TF2ItemSlot_PDA2;
	else if( StrEqual( strSlot, "building", false ) )
	{
		if( iClass == TFClass_Spy )
			return TF2ItemSlot_Sapper;
		else
			return TF2ItemSlot_Building;
	}
	else if( StrEqual( strSlot, "head", false ) )
		return TF2ItemSlot_Hat;
	else if( StrEqual( strSlot, "misc", false ) )
		return TF2ItemSlot_Misc;
	else if( StrEqual( strSlot, "action", false ) )
		return TF2ItemSlot_Action;
	else
		return TF2ItemSlot:-1;
}

stock bool:TF2II_IsBaseItem( iItemDefinitionIndex )
{
	new String:query[128];
	FormatEx(query, sizeof(query), "SELECT baseitem FROM tf2idb_item WHERE id='%d'", iItemDefinitionIndex);
	new Handle:result = TF2IDB_FindItemCustom(query);
	if (result == INVALID_HANDLE)
		return false;
	new size = GetArraySize(result);
	new val = size > 0 ? GetArrayCell(result, 0) : 0;
	CloseHandle(result);
	return !!val;
}
stock bool:TF2II_IsItemPaintable( iItemDefinitionIndex )
{
	new String:query[128];
	FormatEx(query, sizeof(query), "SELECT id FROM tf2idb_capabilities WHERE capability='paintable' AND id='%d'", iItemDefinitionIndex);
	new Handle:result = TF2IDB_FindItemCustom(query);
	if (result == INVALID_HANDLE)
		return false;
	new size = GetArraySize(result);
	CloseHandle(result);
	return size > 0;
}
stock bool:TF2II_ItemCanBeUnusual( iItemDefinitionIndex )
{
	return ItemHasProp( iItemDefinitionIndex, TF2II_PROP_UNUSUAL );
}
stock bool:TF2II_ItemCanBeVintage( iItemDefinitionIndex )
{
	return ItemHasProp( iItemDefinitionIndex, TF2II_PROP_VINTAGE );
}
stock bool:TF2II_IsHauntedItem( iItemDefinitionIndex )
{
	return ItemHasProp( iItemDefinitionIndex, TF2II_PROP_HAUNTED );
}
stock bool:TF2II_IsHalloweenItem( iItemDefinitionIndex )
{
	new String:query[128];
	FormatEx(query, sizeof(query), "SELECT id FROM tf2idb_item WHERE holiday_restriction LIKE 'halloween%' AND id='%d'", iItemDefinitionIndex);
	new Handle:result = TF2IDB_FindItemCustom(query);
	if (result == INVALID_HANDLE)
		return false;
	new size = GetArraySize(result);
	CloseHandle(result);
	return size > 0;
}
stock bool:TF2II_IsHalloweenOrFullMoonItem( iItemDefinitionIndex )
{
	new String:query[128];
	FormatEx(query, sizeof(query), "SELECT id FROM tf2idb_item WHERE holiday_restriction='halloween_or_fullmoon' AND id='%d'", iItemDefinitionIndex);
	new Handle:result = TF2IDB_FindItemCustom(query);
	if (result == INVALID_HANDLE)
		return false;
	new size = GetArraySize(result);
	CloseHandle(result);
	return size > 0;
}
stock bool:TF2II_IsBirthdayItem( iItemDefinitionIndex )
{
	new String:query[128];
	FormatEx(query, sizeof(query), "SELECT id FROM tf2idb_item WHERE holiday_restriction='birthday' AND id='%d'", iItemDefinitionIndex);
	new Handle:result = TF2IDB_FindItemCustom(query);
	if (result == INVALID_HANDLE)
		return false;
	new size = GetArraySize(result);
	CloseHandle(result);
	return size > 0;
}
stock bool:TF2II_IsChristmasItem( iItemDefinitionIndex )
{
	new String:query[128];
	FormatEx(query, sizeof(query), "SELECT id FROM tf2idb_item WHERE holiday_restriction='christmas' AND id='%d'", iItemDefinitionIndex);
	new Handle:result = TF2IDB_FindItemCustom(query);
	if (result == INVALID_HANDLE)
		return false;
	new size = GetArraySize(result);
	CloseHandle(result);
	return size > 0;
}
stock bool:TF2II_HasProperName( iItemDefinitionIndex )
{
	new String:query[128];
	FormatEx(query, sizeof(query), "SELECT id FROM tf2idb_item WHERE propername=1 AND id='%d'", iItemDefinitionIndex);
	new Handle:result = TF2IDB_FindItemCustom(query);
	if (result == INVALID_HANDLE)
		return false;
	new size = GetArraySize(result);
	CloseHandle(result);
	return size > 0;
}
stock bool:TF2II_IsMedievalWeapon( iItemDefinitionIndex )
{
	return TF2IDB_ItemHasAttribute(iItemDefinitionIndex, 2029); //'allowed in medieval mode'
}
stock bool:TF2II_ItemCanBeStrange( iItemDefinitionIndex )
{
	return ItemHasProp( iItemDefinitionIndex, TF2II_PROP_STRANGE );
}

///////////////////
/* Unused Stocks */
///////////////////

stock PrecacheItemSchema()
{
	decl String:strBuffer[128], String:strQueryERegions[512], String:strQueryAttribs[512];
	new iIndex, iProperty, iUsedByClass, iLevel;
	new Handle:hDataContainer = INVALID_HANDLE;

	if( g_hItemData != INVALID_HANDLE )
	{
		for( new i = 0; i < GetArraySize( g_hItemData ); i++ )
		{
			hDataContainer = Handle:GetArrayCell( g_hItemData, i );
			if( hDataContainer != INVALID_HANDLE )
			{
				if( Handle:GetArrayCell( hDataContainer, _:ItemData_Attributes ) != INVALID_HANDLE )
					CloseHandle( Handle:GetArrayCell( hDataContainer, _:ItemData_Attributes ) );
				if( Handle:GetArrayCell( hDataContainer, _:ItemData_EquipRegions ) != INVALID_HANDLE )
					CloseHandle( Handle:GetArrayCell( hDataContainer, _:ItemData_EquipRegions ) );
				if( Handle:GetArrayCell( hDataContainer, _:ItemData_KeyValues ) != INVALID_HANDLE )
					CloseHandle( Handle:GetArrayCell( hDataContainer, _:ItemData_KeyValues ) );
				CloseHandle( hDataContainer );
			}
			hDataContainer = INVALID_HANDLE;
			SetArrayCell( g_hItemData, i, _:hDataContainer );
		}
		CloseHandle( g_hItemData );
	}
	g_hItemData = CreateArray();

	if( g_hItemDataKeys != INVALID_HANDLE )
		CloseHandle( g_hItemDataKeys );
	g_hItemDataKeys = CreateKeyValues( "ItemData_Keys" );

	if( g_hAttribData != INVALID_HANDLE )
	{
		for( new i = 0; i < GetArraySize( g_hAttribData ); i++ )
		{
			hDataContainer = Handle:GetArrayCell( g_hAttribData, i );
			if( hDataContainer != INVALID_HANDLE )
			{
				if( Handle:GetArrayCell( hDataContainer, _:AttribData_KeyValues ) != INVALID_HANDLE )
					CloseHandle( Handle:GetArrayCell( hDataContainer, _:AttribData_KeyValues ) );
				CloseHandle( hDataContainer );
			}
			hDataContainer = INVALID_HANDLE;
			SetArrayCell( g_hAttribData, i, _:hDataContainer );
		}
		CloseHandle( g_hAttribData );
	}
	g_hAttribData = CreateArray();

	if( g_hAttribDataKeys != INVALID_HANDLE )
		CloseHandle( g_hAttribDataKeys );
	g_hAttribDataKeys = CreateKeyValues( "AttribData_Keys" );

	decl String:strFilePath[PLATFORM_MAX_PATH] = "scripts/items/items_game.txt";
	if( !FileExists( strFilePath , true) )
	{
		Error( ERROR_BREAKP|ERROR_LOG, _, "Couldn't found file: %s", strFilePath );
		return;
	}

	new Handle:hItemSchema = CreateKeyValues( "items_game" );
	if( !FileToKeyValues( hItemSchema, strFilePath ) )
		if( !IsDedicatedServer() )
			Error( ERROR_BREAKP|ERROR_LOG, _, "THIS PLUGIN IS FOR DEDICATED SERVERS!" );
		else
			Error( ERROR_BREAKP|ERROR_LOG, _, "Failed to parse file: %s", strFilePath );
	KvRewind( hItemSchema );


	// Parse 'items_game.txt' KeyValues

	if( KvJumpToKey( hItemSchema, "qualities", false ) )
	{
		new Handle:hQualities = CreateKeyValues( "qualities" );
		KvCopySubkeys( hItemSchema, hQualities );
		KvGoBack( hItemSchema );

		KvRewind( hQualities );
		if( KvGotoFirstSubKey( hQualities ) )
		{
			decl String:strIndex[16], String:strQualityName[TF2II_ITEMQUALITY_LENGTH];
			do
			{
				KvGetSectionName( hQualities, strQualityName, sizeof(strQualityName) );
				KvGetString( hQualities, "value", strIndex, sizeof(strIndex) );
				if( IsCharNumeric( strIndex[0] ) )
					SetTrieString( g_hQNames, strIndex, strQualityName );
			}
			while( KvGotoNextKey( hQualities ) );
		}

		CloseHandle( hQualities );
	}

	new Handle:hPrefabs = INVALID_HANDLE;
	if( KvJumpToKey( hItemSchema, "prefabs", false ) )
	{
		hPrefabs = CreateKeyValues( "prefabs" );
		KvCopySubkeys( hItemSchema, hPrefabs );
		KvGoBack( hItemSchema );
	}

	new Handle:hItems = INVALID_HANDLE;
	if( KvJumpToKey( hItemSchema, "items", false ) )
	{
		hItems = CreateKeyValues( "items" );
		KvCopySubkeys( hItemSchema, hItems );
		KvGoBack( hItemSchema );
	}

	if( KvJumpToKey( hItemSchema, "attributes", false ) )
	{
		new Handle:hAttributes, Handle:hSubAttributes;

		hAttributes = CreateKeyValues( "attributes" );
		KvCopySubkeys( hItemSchema, hAttributes );
		KvGoBack( hItemSchema );

		KvRewind( hAttributes );
		if( KvGotoFirstSubKey( hAttributes ) )
			do
			{
				hDataContainer = INVALID_HANDLE;

				iProperty = TF2II_PROP_INVALID;

				KvGetSectionName( hAttributes, strBuffer, sizeof(strBuffer) );
				iIndex = StringToInt( strBuffer );
				if( iIndex <= 0 )
					continue;

				hDataContainer = AttribData_Create( iIndex );
				if( hDataContainer == INVALID_HANDLE )
				{
					Error( ERROR_LOG, _, "Attrib #%d: Failed to create data container!", iIndex );
					continue;
				}

				iProperty |= TF2II_PROP_VALIDATTRIB;

				hSubAttributes = CreateKeyValues( "attributes" );
				KvCopySubkeys( hAttributes, hSubAttributes );
				AttribData_SetCell( iIndex, AttribData_KeyValues, _:hSubAttributes );
				hSubAttributes = INVALID_HANDLE; // free

				KvGetString( hAttributes, "name", strBuffer, sizeof(strBuffer), "" );
				AttribData_SetString( iIndex, AttribData_Name, strBuffer );

				KvGetString( hAttributes, "attribute_class", strBuffer, sizeof(strBuffer), "" );
				AttribData_SetString( iIndex, AttribData_AttribClass, strBuffer );
				KvGetString( hAttributes, "attribute_name", strBuffer, sizeof(strBuffer), "" );
				AttribData_SetString( iIndex, AttribData_AttribName, strBuffer );
				KvGetString( hAttributes, "attribute_type", strBuffer, sizeof(strBuffer), "" );
				AttribData_SetString( iIndex, AttribData_AttribType, strBuffer );

				KvGetString( hAttributes, "description_string", strBuffer, sizeof(strBuffer), "" );
				AttribData_SetString( iIndex, AttribData_DescrString, strBuffer );
				KvGetString( hAttributes, "description_format", strBuffer, sizeof(strBuffer), "" );
				AttribData_SetString( iIndex, AttribData_DescrFormat, strBuffer );

				AttribData_SetCell( iIndex, AttribData_MinValue, _:KvGetFloat( hAttributes, "min_value", 1.0 ) );
				AttribData_SetCell( iIndex, AttribData_MaxValue, _:KvGetFloat( hAttributes, "max_value", 1.0 ) );

				KvGetString( hAttributes, "effect_type", strBuffer, sizeof(strBuffer), "" );
				if( StrEqual( strBuffer, "positive", false ) )
					iProperty |= TF2II_PROP_EFFECT_POSITIVE;
				else if( StrEqual( strBuffer, "negative", false ) )
					iProperty |= TF2II_PROP_EFFECT_NEGATIVE;
				else // assume 'neutral' type
					iProperty |= TF2II_PROP_EFFECT_NEUTRAL;

				if( !!KvGetNum( hAttributes, "hidden", 0 ) )
					iProperty |= TF2II_PROP_HIDDEN;
				if( !!KvGetNum( hAttributes, "stored_as_integer", 0 ) )
					iProperty |= TF2II_PROP_STORED_AS_INTEGER;

				//KvGetString( hAttributes, "armory_desc", strBuffer, sizeof(strBuffer), "" );

				AttribData_SetCell( iIndex, AttribData_Property, iProperty );

				hDataContainer = INVALID_HANDLE;
			}
			while( KvGotoNextKey( hAttributes ) );

		CloseHandle( hAttributes );
	}

	CloseHandle( hItemSchema );


	new bool:bPrefab, p, nPrefabs, nBranches, bool:bStringAttrib, iAttribID;
	new Handle:hIAttributes = INVALID_HANDLE;
	new Handle:hEquipRegions = INVALID_HANDLE;
	new Handle:hTree = INVALID_HANDLE;
	new Handle:hSubItems = INVALID_HANDLE;
	decl String:strPrefabs[4][32];

	KvRewind( hItems );
	if( KvGotoFirstSubKey( hItems ) )
		do
		{
			bStringAttrib = false;

			bPrefab = false;
			hDataContainer = INVALID_HANDLE;

			iProperty = TF2II_PROP_INVALID;
			iUsedByClass = TF2II_CLASS_NONE;


			KvGetSectionName( hItems, strBuffer, sizeof(strBuffer) );
			if( !IsCharNumeric( strBuffer[0] ) )
				continue;
			iIndex = StringToInt( strBuffer );
			if( iIndex < 0 )
				continue;

			hDataContainer = ItemData_Create( iIndex );
			if( hDataContainer == INVALID_HANDLE )
			{
				Error( ERROR_LOG, _, "Item #%d: Failed to create data container!", iIndex );
				continue;
			}

			iProperty |= TF2II_PROP_VALIDITEM;

			// get tree of prefabs
			if( hTree != INVALID_HANDLE )
				CloseHandle( hTree );
			hTree = CreateArray( 8 );

			do
			{
				KvGetString( ( bPrefab ? hPrefabs : hItems ), "prefab", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) > 0 && hPrefabs != INVALID_HANDLE )
				{
					nPrefabs = ExplodeString( strBuffer, " ", strPrefabs, sizeof(strPrefabs), sizeof(strPrefabs[]) );
					for( p = 0; p < nPrefabs; p++ )
					{
						TrimString( strPrefabs[p] );
						KvRewind( hPrefabs );
						bPrefab = KvJumpToKey( hPrefabs, strPrefabs[p], false );
						if( bPrefab )
						{
							if( hSubItems == INVALID_HANDLE )
							{
								hSubItems = CreateKeyValues( "items" );
								KvCopySubkeys( hPrefabs, hSubItems );
							}
							else
								KvCopyDataToKv( hPrefabs, hSubItems, true );
							PushArrayString( hTree, strPrefabs[p] );
						}
					}
				}
				else
					bPrefab = false;
			}
			while( bPrefab );
			nBranches = GetArraySize(hTree);

			if( hSubItems == INVALID_HANDLE )
			{
				hSubItems = CreateKeyValues( "items" );
				KvCopySubkeys( hItems, hSubItems );
			}
			else
				KvCopyDataToKv( hItems, hSubItems, true );
			ItemData_SetCell( iIndex, ItemData_KeyValues, _:hSubItems );
			hSubItems = INVALID_HANDLE;

			KvGetString( hItems, "name", strBuffer, sizeof(strBuffer), "" );
			ItemData_SetString( iIndex, ItemData_Name, strBuffer );

			// if bPrefab is true, so check prefab AND item section (for overrides),
			// otherwise - only item section
			for( p = 0; p <= nBranches; p++ )
			{
				if( p >= nBranches )
					bPrefab = false;
				else
				{
					bPrefab = true;
					GetArrayString( hTree, nBranches - p - 1, strBuffer, sizeof(strBuffer) );
					KvRewind( hPrefabs );
					KvJumpToKey( hPrefabs, strBuffer, false );
				}

				KvGetString( ( bPrefab ? hPrefabs : hItems ), "item_name", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
					ItemData_SetString( iIndex, ItemData_MLName, strBuffer );

				KvGetString( ( bPrefab ? hPrefabs : hItems ), "item_description", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
					ItemData_SetString( iIndex, ItemData_MLDescription, strBuffer );

				KvGetString( ( bPrefab ? hPrefabs : hItems ), "item_type_name", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
					ItemData_SetString( iIndex, ItemData_MLSlotName, strBuffer );

				// is it a base item?
				if( KvGetNum( ( bPrefab ? hPrefabs : hItems ), "baseitem", 0 ) > 0 )
					iProperty |= TF2II_PROP_BASEITEM;

				// item levels
				iLevel = KvGetNum( ( bPrefab ? hPrefabs : hItems ), "min_ilevel", 0 );
				if( iLevel > 0 )
					ItemData_SetCell( iIndex, ItemData_MinLevel, iLevel );
				iLevel = KvGetNum( ( bPrefab ? hPrefabs : hItems ), "max_ilevel", 0 );
				if( iLevel > 0 )
					ItemData_SetCell( iIndex, ItemData_MaxLevel, iLevel );

				// item quality
				KvGetString( ( bPrefab ? hPrefabs : hItems ), "item_quality", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
					ItemData_SetString( iIndex, ItemData_Quality, strBuffer );

				// tool type
				if( KvJumpToKey( ( bPrefab ? hPrefabs : hItems ), "tool", false ) )
				{
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "type", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						ItemData_SetString( iIndex, ItemData_Tool, strBuffer );
					KvGoBack( bPrefab ? hPrefabs : hItems );
				}

				// equip region(s)
				strQueryERegions[0] = '\0';
				hEquipRegions = Handle:ItemData_GetCell( iIndex, ItemData_EquipRegions );
				KvGetString( ( bPrefab ? hPrefabs : hItems ), "equip_region", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
				{
					if( hEquipRegions == INVALID_HANDLE )
						hEquipRegions = CreateArray( 4 );
					PushArrayString( hEquipRegions, strBuffer );
					strcopy( strQueryERegions, sizeof( strQueryERegions ), strBuffer );
				}
				if( KvJumpToKey( ( bPrefab ? hPrefabs : hItems ), "equip_regions", false ) )
				{
					if( KvGotoFirstSubKey( ( bPrefab ? hPrefabs : hItems ), false ) )
					{
						if( hEquipRegions == INVALID_HANDLE )
							hEquipRegions = CreateArray( 4 );
						do
						{
							KvGetSectionName( ( bPrefab ? hPrefabs : hItems ), strBuffer, sizeof(strBuffer) );
							PushArrayString( hEquipRegions, strBuffer );
							Format( strQueryERegions, sizeof( strQueryERegions ), "%s%s%s", strQueryERegions, strlen( strQueryERegions ) ? "," : "", strBuffer );
						}
						while( KvGotoNextKey( ( bPrefab ? hPrefabs : hItems ), false ) );
						KvGoBack( bPrefab ? hPrefabs : hItems );
					}
					KvGoBack( bPrefab ? hPrefabs : hItems );
				}
				ItemData_SetCell( iIndex, ItemData_EquipRegions, _:hEquipRegions );
				hEquipRegions = INVALID_HANDLE;

				// used by classes
				if( KvJumpToKey( ( bPrefab ? hPrefabs : hItems ), "used_by_classes", false ) )
				{
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "scout", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						iUsedByClass |= TF2II_CLASS_SCOUT;
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "sniper", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						iUsedByClass |= TF2II_CLASS_SNIPER;
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "soldier", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						iUsedByClass |= TF2II_CLASS_SOLDIER;
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "demoman", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						iUsedByClass |= TF2II_CLASS_DEMOMAN;
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "medic", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						iUsedByClass |= TF2II_CLASS_MEDIC;
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "heavy", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						iUsedByClass |= TF2II_CLASS_HEAVY;
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "pyro", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						iUsedByClass |= TF2II_CLASS_PYRO;
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "spy", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						iUsedByClass |= TF2II_CLASS_SPY;
					KvGetString( ( bPrefab ? hPrefabs : hItems ), "engineer", strBuffer, sizeof(strBuffer), "" );
					if( strlen( strBuffer ) )
						iUsedByClass |= TF2II_CLASS_ENGINEER;
					ItemData_SetCell( iIndex, ItemData_UsedBy, iUsedByClass );
					KvGoBack( bPrefab ? hPrefabs : hItems );
				}

				// item slot
				KvGetString( ( bPrefab ? hPrefabs : hItems ), "item_slot", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
				{
					ItemData_SetString( iIndex, ItemData_Slot, strBuffer );
					ItemData_SetString( iIndex, ItemData_ListedSlot, strBuffer );
				}

				// classname
				KvGetString( ( bPrefab ? hPrefabs : hItems ), "item_class", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
				{
					if( strcmp( strBuffer, "tf_weapon_revolver", false ) == 0 )
						ItemData_SetString( iIndex, ItemData_Slot, "primary" );
					ItemData_SetString( iIndex, ItemData_ClassName, strBuffer );
				}

				// capabilities
				if( KvJumpToKey( ( bPrefab ? hPrefabs : hItems ), "capabilities", false ) )
				{
					if( KvGetNum( ( bPrefab ? hPrefabs : hItems ), "paintable", 0 ) )
						iProperty |= TF2II_PROP_PAINTABLE;
					KvGoBack( bPrefab ? hPrefabs : hItems );
				}

				// holiday restriction
				KvGetString( ( bPrefab ? hPrefabs : hItems ), "holiday_restriction", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
				{
					if( StrEqual( strBuffer, "birthday", false ) )
						iProperty |= TF2II_PROP_BDAY_STRICT;
					if( StrEqual( strBuffer, "halloween_or_fullmoon", false ) )
						iProperty |= TF2II_PROP_HOFM_STRICT;
					if( StrEqual( strBuffer, "christmas", false ) )
						iProperty |= TF2II_PROP_XMAS_STRICT;
				}

				// propername
				if( KvGetNum( ( bPrefab ? hPrefabs : hItems ), "propername", 0 ) )
					iProperty |= TF2II_PROP_PROPER_NAME;

				// kill log name/icon
				KvGetString( ( bPrefab ? hPrefabs : hItems ), "item_logname", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
					ItemData_SetString( iIndex, ItemData_LogName, strBuffer );
				KvGetString( ( bPrefab ? hPrefabs : hItems ), "item_iconname", strBuffer, sizeof(strBuffer), "" );
				if( strlen( strBuffer ) )
					ItemData_SetString( iIndex, ItemData_LogIcon, strBuffer );

				// attributes
				strQueryAttribs[0] = '\0';
				if( KvJumpToKey( ( bPrefab ? hPrefabs : hItems ), "attributes", false ) )
				{
					if( KvGotoFirstSubKey( bPrefab ? hPrefabs : hItems ) )
					{
						hIAttributes = Handle:ItemData_GetCell( iIndex, ItemData_Attributes );
						if( hIAttributes == INVALID_HANDLE )
							hIAttributes = CreateArray();
						do
						{
							KvGetString( ( bPrefab ? hPrefabs : hItems ), "value", strBuffer, sizeof(strBuffer) );
							if( StringToFloat( strBuffer ) == 0.0 && !( ( strBuffer[0] == '-' || strBuffer[0] == '.' ) && IsCharNumeric( strBuffer[1] ) || IsCharNumeric( strBuffer[0] ) ) )
							{
								bStringAttrib = true;
								if( nFix01State == 1 )
									continue;
								else if( nFix01State == 2 )
									break;
							}
							KvGetSectionName( ( bPrefab ? hPrefabs : hItems ), strBuffer, sizeof(strBuffer) );
							iAttribID = GetAttribIDByName( strBuffer );
							PushArrayCell( hIAttributes, iAttribID );
							PushArrayCell( hIAttributes, _:KvGetFloat( ( bPrefab ? hPrefabs : hItems ), "value", 0.0 ) );
							Format( strQueryAttribs, sizeof( strQueryAttribs ), "%s%s%d,%.3f", strQueryAttribs, strlen( strQueryAttribs ) ? ";" : "", iAttribID, KvGetFloat( ( bPrefab ? hPrefabs : hItems ), "value", 0.0 ) );
						}
						while( KvGotoNextKey( bPrefab ? hPrefabs : hItems ) );
						if( !bStringAttrib )
							ItemData_SetCell( iIndex, ItemData_Attributes, _:hIAttributes );
						else
							CloseHandle( hIAttributes );
						hIAttributes = INVALID_HANDLE;
						KvGoBack( bPrefab ? hPrefabs : hItems );
					}
					KvGoBack( bPrefab ? hPrefabs : hItems );
				}

				if( nFix01State == 2 && bStringAttrib )
					break;
			}

			if( nFix01State == 2 && bStringAttrib )
			{
				ItemData_Destroy( iIndex );
				continue;
			}

			ItemData_SetCell( iIndex, ItemData_Property, iProperty );

			hDataContainer = INVALID_HANDLE;
		}
		while( KvGotoNextKey( hItems ) );


	if( hTree != INVALID_HANDLE )
		CloseHandle( hTree );
	if( hItems != INVALID_HANDLE )
		CloseHandle( hItems );
	if( hPrefabs != INVALID_HANDLE )
		CloseHandle( hPrefabs );

	Error( ERROR_NONE, _, "Item schema is parsed: %d items, %d attributes.", GetArraySize( g_hItemData ), GetArraySize( g_hAttribData ));

	Call_StartForward( hForward_ItemSchemaUpdated );
	Call_Finish();
}

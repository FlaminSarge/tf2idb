#define PLUGIN_VERSION "0.94.0"

#pragma newdecls required

public Plugin myinfo = {
	name		= "TF2IDB",
	author	  	= "Bottiger, FlaminSarge",
	description = "TF2 Item Schema Database",
	version	 	= PLUGIN_VERSION,
	url		 	= "http://github.com/flaminsarge/tf2idb"
};

#include <tf2>
#include <tf2idb>

public APLRes AskPluginLoad2(Handle hPlugin, bool bLateLoad, char[] sError, int iErrorSize) {
	CreateNative("TF2IDB_IsValidItemID", Native_IsValidItemID);
	CreateNative("TF2IDB_GetItemName", Native_GetItemName);
	CreateNative("TF2IDB_GetItemClass", Native_GetItemClass);
	CreateNative("TF2IDB_GetItemSlotName", Native_GetItemSlotName);
	CreateNative("TF2IDB_GetItemSlot", Native_GetItemSlot);
	CreateNative("TF2IDB_GetItemQualityName", Native_GetItemQualityName);
	CreateNative("TF2IDB_GetItemQuality", Native_GetItemQuality);
	CreateNative("TF2IDB_GetItemLevels", Native_GetItemLevels);
	CreateNative("TF2IDB_GetItemAttributes", Native_GetItemAttributes);
	CreateNative("TF2IDB_GetItemEquipRegions", Native_GetItemEquipRegions);
	CreateNative("TF2IDB_DoRegionsConflict", Native_DoRegionsConflict);
	CreateNative("TF2IDB_ListParticles", Native_ListParticles);
	CreateNative("TF2IDB_FindItemCustom", Native_FindItemCustom);
	CreateNative("TF2IDB_ItemHasAttribute", Native_ItemHasAttribute);
	CreateNative("TF2IDB_UsedByClasses", Native_UsedByClasses);

	CreateNative("TF2IDB_CustomQuery", Native_CustomQuery);

	CreateNative("TF2IDB_IsValidAttributeID", Native_IsValidAttributeID);
	CreateNative("TF2IDB_GetAttributeName", Native_GetAttributeName);
	CreateNative("TF2IDB_GetAttributeClass", Native_GetAttributeClass);
	CreateNative("TF2IDB_GetAttributeType", Native_GetAttributeType);
	CreateNative("TF2IDB_GetAttributeDescString", Native_GetAttributeDescString);
	CreateNative("TF2IDB_GetAttributeDescFormat", Native_GetAttributeDescFormat);
	CreateNative("TF2IDB_GetAttributeEffectType", Native_GetAttributeEffectType);
	CreateNative("TF2IDB_GetAttributeArmoryDesc", Native_GetAttributeArmoryDesc);
	CreateNative("TF2IDB_GetAttributeItemTag", Native_GetAttributeItemTag);
	CreateNative("TF2IDB_GetAttributeProperties", Native_GetAttributeProperties);

	CreateNative("TF2IDB_GetQualityName", Native_GetQualityName);
	CreateNative("TF2IDB_GetQualityByName", Native_GetQualityByName);

	RegPluginLibrary("tf2idb");
	return APLRes_Success;
}

Handle g_db;

//Handle g_statement_IsValidItemID;
Handle g_statement_GetItemClass;
Handle g_statement_GetItemName;
Handle g_statement_GetItemSlotName;
Handle g_statement_GetItemQualityName;
Handle g_statement_GetItemLevels;
Handle g_statement_GetItemAttributes;
Handle g_statement_GetItemEquipRegions;
Handle g_statement_ListParticles;
Handle g_statement_DoRegionsConflict;
Handle g_statement_ItemHasAttribute;
Handle g_statement_GetItemSlotNameByClass;
Handle g_statement_UsedByClasses;

//Handle g_statement_IsValidAttributeID;
Handle g_statement_GetAttributeName;
Handle g_statement_GetAttributeClass;
Handle g_statement_GetAttributeType;
Handle g_statement_GetAttributeDescString;
Handle g_statement_GetAttributeDescFormat;
Handle g_statement_GetAttributeEffectType;
Handle g_statement_GetAttributeArmoryDesc;
Handle g_statement_GetAttributeItemTag;

Handle g_slot_mappings;
Handle g_quality_mappings;

Handle g_id_cache;
Handle g_class_cache;
Handle g_slot_cache;
Handle g_minlevel_cache;
Handle g_maxlevel_cache;

#define NUM_ATT_CACHE_FIELDS 5
Handle g_attribute_cache;

char g_class_mappings[][] = {
	"unknown", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer"
};

public void OnPluginStart() {
	CreateConVar("sm_tf2idb_version", PLUGIN_VERSION, "TF2IDB version", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);

	char error[255];
	g_db = SQLite_UseDatabase("tf2idb", error, sizeof(error));
	if(g_db == INVALID_HANDLE)
		SetFailState(error);

	#define PREPARE_STATEMENT(%1,%2) %1 = SQL_PrepareQuery(g_db, %2, error, sizeof(error)); if(%1 == INVALID_HANDLE) SetFailState(error);

//	PREPARE_STATEMENT(g_statement_IsValidItemID, "SELECT id FROM tf2idb_item WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetItemClass, "SELECT class FROM tf2idb_item WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetItemName, "SELECT name FROM tf2idb_item WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetItemSlotName, "SELECT slot FROM tf2idb_item WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetItemQualityName, "SELECT quality FROM tf2idb_item WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetItemLevels, "SELECT min_ilevel,max_ilevel FROM tf2idb_item WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetItemAttributes, "SELECT attribute,value FROM tf2idb_item_attributes WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetItemEquipRegions, "SELECT region FROM tf2idb_equip_regions WHERE id=?")
	PREPARE_STATEMENT(g_statement_ListParticles, "SELECT id FROM tf2idb_particles")
	PREPARE_STATEMENT(g_statement_DoRegionsConflict, "SELECT a.name FROM tf2idb_equip_conflicts a JOIN tf2idb_equip_conflicts b ON a.name=b.name WHERE a.region=? AND b.region=?")
	PREPARE_STATEMENT(g_statement_ItemHasAttribute, "SELECT attribute FROM tf2idb_item a JOIN tf2idb_item_attributes b ON a.id=b.id WHERE a.id=? AND attribute=?")
	PREPARE_STATEMENT(g_statement_GetItemSlotNameByClass, "SELECT slot FROM tf2idb_class WHERE id=? AND class=?")
	PREPARE_STATEMENT(g_statement_UsedByClasses, "SELECT class FROM tf2idb_class WHERE id=?")

//	PREPARE_STATEMENT(g_statement_IsValidAttributeID, "SELECT id FROM tf2idb_attributes WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetAttributeName, "SELECT name FROM tf2idb_attributes WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetAttributeClass, "SELECT attribute_class FROM tf2idb_attributes WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetAttributeType, "SELECT attribute_type FROM tf2idb_attributes WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetAttributeDescString, "SELECT description_string FROM tf2idb_attributes WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetAttributeDescFormat, "SELECT description_format FROM tf2idb_attributes WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetAttributeEffectType, "SELECT effect_type FROM tf2idb_attributes WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetAttributeArmoryDesc, "SELECT armory_desc FROM tf2idb_attributes WHERE id=?")
	PREPARE_STATEMENT(g_statement_GetAttributeItemTag, "SELECT apply_tag_to_item_definition FROM tf2idb_attributes WHERE id=?")

	g_slot_mappings = CreateTrie();
	SetTrieValue(g_slot_mappings, "primary", TF2ItemSlot_Primary);
	SetTrieValue(g_slot_mappings, "secondary", TF2ItemSlot_Secondary);
	SetTrieValue(g_slot_mappings, "melee", TF2ItemSlot_Melee);
	SetTrieValue(g_slot_mappings, "pda", TF2ItemSlot_PDA1);
	SetTrieValue(g_slot_mappings, "pda2", TF2ItemSlot_PDA2);
	SetTrieValue(g_slot_mappings, "building", TF2ItemSlot_Building);
	SetTrieValue(g_slot_mappings, "head", TF2ItemSlot_Head);
	SetTrieValue(g_slot_mappings, "misc", TF2ItemSlot_Misc);
	SetTrieValue(g_slot_mappings, "taunt", TF2ItemSlot_Taunt);
	SetTrieValue(g_slot_mappings, "action", TF2ItemSlot_Action);

	g_id_cache = CreateTrie();
	g_class_cache = CreateTrie();
	g_slot_cache = CreateTrie();
	g_minlevel_cache = CreateTrie();
	g_maxlevel_cache = CreateTrie();

	g_attribute_cache = CreateTrie();

	//g_quality_mappings is initialized inside PrepareCache
	PrepareCache();

	/*
	int aids[TF2IDB_MAX_ATTRIBUTES];
	float values[TF2IDB_MAX_ATTRIBUTES];
	int attributes = TF2IDB_GetItemAttributes(424, aids, values);
	PrintToServer("TF2IDB_ItemHasAttribute: %i", attributes);
	for(int i=0;i<attributes;i++) {
		PrintToServer("aid %i value %f", aids[i], values[i]);
	}

	PrintItem(43);
	Handle paints = TF2IDB_FindItemCustom("SELECT id FROM tf2idb_item WHERE tool_type='paint_can'");

	for(int i=0;i<GetArraySize(paints);i++) {
		PrintToServer("paint %i", GetArrayCell(paints, i));
	}
	*/
}

void PrepareCache() {
	Handle queryHandle = SQL_Query(g_db, "SELECT id,class,slot,min_ilevel,max_ilevel FROM tf2idb_item");
	while(SQL_FetchRow(queryHandle)) {
		char slot[TF2IDB_ITEMSLOT_LENGTH];
		char class[TF2IDB_ITEMCLASS_LENGTH];
		char id[16];
		SQL_FetchString(queryHandle, 0, id, sizeof(id));
		SQL_FetchString(queryHandle, 1, class, sizeof(class));
		SQL_FetchString(queryHandle, 2, slot, sizeof(slot));
		int min_level = SQL_FetchInt(queryHandle, 3);
		int max_level = SQL_FetchInt(queryHandle, 4);

		SetTrieValue(g_id_cache, id, 1);
		SetTrieString(g_class_cache, id, class);
		SetTrieString(g_slot_cache, id, slot);
		SetTrieValue(g_minlevel_cache, id, min_level);
		SetTrieValue(g_maxlevel_cache, id, max_level);
	}
	CloseHandle(queryHandle);

	queryHandle = SQL_Query(g_db, "SELECT id,hidden,stored_as_integer,is_set_bonus,is_user_generated,can_affect_recipe_component_name FROM tf2idb_attributes");
	while(SQL_FetchRow(queryHandle)) {
		char id[16];
		int values[NUM_ATT_CACHE_FIELDS] = { -1, ... };
		SQL_FetchString(queryHandle, 0, id, sizeof(id));
		for(int i = 0; i < NUM_ATT_CACHE_FIELDS; i++) {
			if(!SQL_IsFieldNull(queryHandle, i)) {
				values[i] = SQL_FetchInt(queryHandle, i+1);
			}
		}
		SetTrieArray(g_attribute_cache, id, values, NUM_ATT_CACHE_FIELDS);
	}
	CloseHandle(queryHandle);

	Handle qualitySizeHandle = SQL_Query(g_db, "SELECT MAX(value) FROM tf2idb_qualities");
	if (qualitySizeHandle != INVALID_HANDLE && SQL_FetchRow(qualitySizeHandle)) {
		int size = SQL_FetchInt(qualitySizeHandle, 0);
		CloseHandle(qualitySizeHandle);
		g_quality_mappings = CreateArray(ByteCountToCells(TF2IDB_ITEMQUALITY_LENGTH), size + 1);

		queryHandle = SQL_Query(g_db, "SELECT name,value FROM tf2idb_qualities");
		while(SQL_FetchRow(queryHandle)) {
			char name[TF2IDB_ITEMQUALITY_LENGTH];
			SQL_FetchString(queryHandle, 0, name, sizeof(name));
			int value = SQL_FetchInt(queryHandle, 1);
			SetArrayString(g_quality_mappings, value, name);
		}
		CloseHandle(queryHandle);
	} else {
		if (qualitySizeHandle != INVALID_HANDLE) {
			CloseHandle(qualitySizeHandle);
		}
		//backup strats
		g_quality_mappings = CreateArray(ByteCountToCells(TF2IDB_ITEMQUALITY_LENGTH), view_as<int>(TF2ItemQuality));	//size of the quality enum
		SetArrayString(g_quality_mappings, view_as<int>(TF2ItemQuality_Normal), "normal");
		SetArrayString(g_quality_mappings, view_as<int>(TF2ItemQuality_Rarity4), "rarity4");
		SetArrayString(g_quality_mappings, view_as<int>(TF2ItemQuality_Strange), "strange");
		SetArrayString(g_quality_mappings, view_as<int>(TF2ItemQuality_Unique), "unique");
	}
}

stock void PrintItem(int id) {
	bool valid = TF2IDB_IsValidItemID(id);
	if(!valid) {
		PrintToServer("Invalid Item %i", id);
		return;
	}

	char name[64];
	TF2IDB_GetItemName(43, name, sizeof(name));

	PrintToServer("%i - %s", id, name);
	PrintToServer("slot %i - quality %i", TF2IDB_GetItemSlot(id), TF2IDB_GetItemQuality(id));

	int min,max;
	TF2IDB_GetItemLevels(id, min, max);
	PrintToServer("Level %i - %i", min, max);
}

public int Native_IsValidItemID(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	char strId[16];
	IntToString(id, strId, sizeof(strId));
	int junk;
	return view_as<int>(GetTrieValue(g_id_cache, strId, junk));
	/*
	SQL_BindParamInt(g_statement_IsValidItemID, 0, id);
	SQL_Execute(g_statement_IsValidItemID);
	return SQL_GetRowCount(g_statement_IsValidItemID);
	*/
}

public int Native_GetItemClass(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size = GetNativeCell(3);

	char strId[16];
	IntToString(id, strId, sizeof(strId));
	char[] class = new char[size];

	if(GetTrieString(g_class_cache, strId, class, size)) {
		SetNativeString(2, class, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);

	/*
	SQL_BindParamInt(g_statement_GetItemClass, 0, id);
	SQL_Execute(g_statement_GetItemClass);
	if(SQL_FetchRow(g_statement_GetItemClass)) {
		char[] buffer = new char[size];
		SQL_FetchString(g_statement_GetItemClass, 0, buffer, size);
		SetNativeString(2, buffer, size);
		return view_as<int>(true);
	} else {
		return view_as<int>(false);
	}
	*/
}

public int Native_GetItemName(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size = GetNativeCell(3);
	SQL_BindParamInt(g_statement_GetItemName, 0, id);
	SQL_Execute(g_statement_GetItemName);
	if(SQL_FetchRow(g_statement_GetItemName)) {
		char[] buffer = new char[size];
		SQL_FetchString(g_statement_GetItemName, 0, buffer, size);
		SetNativeString(2, buffer, size);
		return view_as<int>(true);
	} else {
		return view_as<int>(false);
	}
}

public int Native_GetItemSlotName(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	TFClassType classType = (nParams >= 4) ? GetNativeCell(4) : TFClass_Unknown;

	char[] slot = new char[size];

	if(classType != TFClass_Unknown) {
		SQL_BindParamInt(g_statement_GetItemSlotNameByClass, 0, id);
		SQL_BindParamString(g_statement_GetItemSlotNameByClass, 1, g_class_mappings[classType], false);

		SQL_Execute(g_statement_GetItemSlotNameByClass);

		while(SQL_FetchRow(g_statement_GetItemSlotNameByClass)) {
			if(!SQL_IsFieldNull(g_statement_GetItemSlotNameByClass, 0)) {
				SQL_FetchString(g_statement_GetItemSlotNameByClass, 0, slot, size);
				SetNativeString(2, slot, size);
				return view_as<int>(true);
			}
		}
	}

	char strId[16];
	IntToString(id, strId, sizeof(strId));

	if(GetTrieString(g_slot_cache, strId, slot, size)) {
		SetNativeString(2, slot, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);

	/*
	SQL_BindParamInt(g_statement_GetItemSlotName, 0, id);
	SQL_Execute(g_statement_GetItemSlotName);
	if(SQL_FetchRow(g_statement_GetItemSlotName)) {
		char[] buffer = new char[size];
		
		SQL_FetchString(g_statement_GetItemSlotName, 0, buffer, size);
		SetNativeString(2, buffer, size);
		return view_as<int>(true);
	} else {
		return view_as<int>(false);
	}
	*/
}

public int Native_GetItemSlot(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	char slotString[16];
	TFClassType classType = (nParams >= 2) ? GetNativeCell(2) : TFClass_Unknown;

	if(TF2IDB_GetItemSlotName(id, slotString, sizeof(slotString), classType)) {
		TF2ItemSlot slot;
		if(GetTrieValue(g_slot_mappings, slotString, slot)) {
			return view_as<int>(slot);
		}
	}
	return -1;
}

public int Native_GetItemQualityName(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	SQL_BindParamInt(g_statement_GetItemQualityName, 0, id);
	SQL_Execute(g_statement_GetItemQualityName);
	if(SQL_FetchRow(g_statement_GetItemQualityName)) {
		char[] buffer = new char[size];
		SQL_FetchString(g_statement_GetItemQualityName, 0, buffer, size);
		SetNativeString(2, buffer, size);
		return view_as<int>(true);
	} else {
		return view_as<int>(false);
	}
}

public int Native_GetItemQuality(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	char qualityString[16];
	TF2ItemQuality quality = TF2ItemQuality_Normal;
	if(TF2IDB_GetItemSlotName(id, qualityString, sizeof(qualityString))) {
		quality = GetQualityByName(qualityString);
	}
	return view_as<int>((quality > TF2ItemQuality_Normal ? quality : TF2ItemQuality_Normal));
}

public int Native_GetItemLevels(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	char strId[16];
	IntToString(id, strId, sizeof(strId));
	int min,max;
	bool exists = GetTrieValue(g_minlevel_cache, strId, min);
	GetTrieValue(g_maxlevel_cache, strId, max);
	if(exists) {
		SetNativeCellRef(2, min);
		SetNativeCellRef(3, max);
	}
	return view_as<int>(exists);

	/*
	SQL_BindParamInt(g_statement_GetItemLevels, 0, id);
	SQL_Execute(g_statement_GetItemLevels);
	if(SQL_FetchRow(g_statement_GetItemLevels)) {
		int min = SQL_FetchInt(g_statement_GetItemLevels, 0);
		int max = SQL_FetchInt(g_statement_GetItemLevels, 1);
		SetNativeCellRef(2, min);
		SetNativeCellRef(3, max);
		return view_as<int>(true);
	} else {
		return view_as<int>(false);
	}
	*/
}

public int Native_GetItemAttributes(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int aids[TF2IDB_MAX_ATTRIBUTES];
	float values[TF2IDB_MAX_ATTRIBUTES];
	SQL_BindParamInt(g_statement_GetItemAttributes, 0, id);
	SQL_Execute(g_statement_GetItemAttributes);

	int index;
	while(SQL_FetchRow(g_statement_GetItemAttributes)) {
		int aid = SQL_FetchInt(g_statement_GetItemAttributes, 0);
		float value = SQL_FetchFloat(g_statement_GetItemAttributes, 1);
		aids[index] = aid;
		values[index] = value;
		index++;
	}

	if(index) {
		SetNativeArray(2, aids, index);
		SetNativeArray(3, values, index);
	}

	return index;
}

public int Native_GetItemEquipRegions(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	SQL_BindParamInt(g_statement_GetItemEquipRegions, 0, id);
	Handle list = CreateArray(ByteCountToCells(16));
	SQL_Execute(g_statement_GetItemEquipRegions);
	while(SQL_FetchRow(g_statement_GetItemEquipRegions)) {
		char buffer[16];
		SQL_FetchString(g_statement_GetItemEquipRegions, 0, buffer, sizeof(buffer));
		PushArrayString(list, buffer);
	}
	Handle output = CloneHandle(list, hPlugin);
	CloseHandle(list);
	return view_as<int>(output);
}

public int Native_ListParticles(Handle hPlugin, int nParams) {
	Handle list = CreateArray();
	SQL_Execute(g_statement_ListParticles);
	while(SQL_FetchRow(g_statement_ListParticles)) {
		int effect = SQL_FetchInt(g_statement_ListParticles, 0);
		if(effect > 5 && effect < 2000 && effect != 20 && effect != 28)
			PushArrayCell(list, effect);
	}
	Handle output = CloneHandle(list, hPlugin);
	CloseHandle(list);
	return view_as<int>(output);
}

public int Native_DoRegionsConflict(Handle hPlugin, int nParams) {
	char region1[16];
	char region2[16];
	GetNativeString(1, region1, sizeof(region1));
	GetNativeString(2, region2, sizeof(region2));
	SQL_BindParamString(g_statement_DoRegionsConflict, 0, region1, false);
	SQL_BindParamString(g_statement_DoRegionsConflict, 1, region2, false);
	SQL_Execute(g_statement_DoRegionsConflict);
	return view_as<int>(SQL_GetRowCount(g_statement_DoRegionsConflict) > 0);
}

public int Native_FindItemCustom(Handle hPlugin, int nParams) {
	int length;
	GetNativeStringLength(1, length);
	char[] query = new char[length+1];
	GetNativeString(1, query, length+1);

	Handle queryHandle = SQL_Query(g_db, query);
	if(queryHandle == INVALID_HANDLE)
		return view_as<int>(INVALID_HANDLE);
	Handle list = CreateArray();
	while(SQL_FetchRow(queryHandle)) {
		int id = SQL_FetchInt(queryHandle, 0);
		PushArrayCell(list, id);
	}
	CloseHandle(queryHandle);
	Handle output = CloneHandle(list, hPlugin);
	CloseHandle(list);
	return view_as<int>(output);
}

public int Native_CustomQuery(Handle hPlugin, int nParams) {
	int length;
	GetNativeStringLength(1, length);
	char[] query = new char[length+1];
	GetNativeString(1, query, length+1);
	char error[256];	
	Handle queryHandle = SQL_PrepareQuery(g_db, query, error, sizeof(error));
	ArrayList arguments = view_as<ArrayList>(GetNativeCell(2));
	int argSize = GetArraySize(arguments);
	int maxlen = GetNativeCell(3);
	char[] buf = new char[maxlen];
	for(int i = 0; i < argSize; i++) {
		GetArrayString(arguments, i, buf, maxlen);
		SQL_BindParamString(queryHandle, i, buf, true);
	}
	if(SQL_Execute(queryHandle)) {
		return view_as<int>(queryHandle);
	} else {
		if (queryHandle != INVALID_HANDLE) {
			CloseHandle(queryHandle);
		}
	}
	return view_as<int>(INVALID_HANDLE);

/*	int numFields = SQL_GetFieldCount(queryHandle);
	if(numFields <= 0) {
		return view_as<int>(INVALID_HANDLE);
	}
	Handle results[numFields];
	for(int i = 0; i < numFields; i++) {
		Handle temp = CreateArray(maxlen);
		results[i] = CloneHandle(temp, hPlugin);
		CloseHandle(temp);
		SQL_FieldNumToName(queryHandle, i, buf, maxlen);
		PushArrayString(results[i], buf);
	}
	while(SQL_FetchRow(queryHandle)) {
		for(int i = 0; i < numFields; i++) {
			SQL_FetchString(queryHandle, i, buf, maxlen);
			PushArrayString(results[i], buf);
		}
	}
	Handle temp = CreateArray();
	Handle retVal = CloneHandle(temp, hPlugin);
	CloseHandle(temp);
	PushArrayCell(retVal, GetArraySize(results[0]));
	for(int i = 0; i < numFields; i++) {
		PushArrayCell(retVal, results[i]);
	}
	return view_as<int>(retVal);
*/
}

public int Native_ItemHasAttribute(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int aid = GetNativeCell(2);

	SQL_BindParamInt(g_statement_ItemHasAttribute, 0, id);
	SQL_BindParamInt(g_statement_ItemHasAttribute, 1, aid);
	SQL_Execute(g_statement_ItemHasAttribute);

	if(SQL_FetchRow(g_statement_ItemHasAttribute)) {
		return view_as<int>(SQL_GetRowCount(g_statement_ItemHasAttribute) > 0);
	}
	return view_as<int>(false);
}

public int Native_UsedByClasses(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	char class[16];
	int result = 0;
	
	SQL_BindParamInt(g_statement_UsedByClasses, 0, id);
	SQL_Execute(g_statement_UsedByClasses);
	
	while (SQL_FetchRow(g_statement_UsedByClasses)) {
		if (SQL_FetchString(g_statement_UsedByClasses, 0, class, sizeof(class)) > 0) {
			result |= (1 << view_as<int>(TF2_GetClass(class)));
		}
	}
	return result;
}

public int Native_IsValidAttributeID(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	char strId[16];
	IntToString(id, strId, sizeof(strId));
	int junk[NUM_ATT_CACHE_FIELDS];
	return view_as<int>(GetTrieArray(g_attribute_cache, strId, junk, NUM_ATT_CACHE_FIELDS));
}

stock bool GetStatementStringForID(Handle statement, int id, char[] buf, int size) {
	SQL_BindParamInt(statement, 0, id);
	SQL_Execute(statement);
	if(SQL_FetchRow(statement)) {
		SQL_FetchString(statement, 0, buf, size);
		return true;
	}
	return false;
}
public int Native_GetAttributeName(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	char[] buf = new char[size+1];
	if(GetStatementStringForID(g_statement_GetAttributeName, id, buf, size)) {
		SetNativeString(2, buf, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);
}
public int Native_GetAttributeClass(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	char[] buf = new char[size+1];
	if(GetStatementStringForID(g_statement_GetAttributeClass, id, buf, size)) {
		SetNativeString(2, buf, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);
}
public int Native_GetAttributeType(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	char[] buf = new char[size+1];
	if(GetStatementStringForID(g_statement_GetAttributeType, id, buf, size)) {
		SetNativeString(2, buf, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);
}
public int Native_GetAttributeDescString(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	char[] buf = new char[size+1];
	if(GetStatementStringForID(g_statement_GetAttributeDescString, id, buf, size)) {
		SetNativeString(2, buf, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);
}
public int Native_GetAttributeDescFormat(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	char[] buf = new char[size+1];
	if(GetStatementStringForID(g_statement_GetAttributeDescFormat, id, buf, size)) {
		SetNativeString(2, buf, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);
}
public int Native_GetAttributeEffectType(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	char[] buf = new char[size+1];
	if(GetStatementStringForID(g_statement_GetAttributeEffectType, id, buf, size)) {
		SetNativeString(2, buf, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);
}
public int Native_GetAttributeArmoryDesc(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	char[] buf = new char[size+1];
	if(GetStatementStringForID(g_statement_GetAttributeArmoryDesc, id, buf, size)) {
		SetNativeString(2, buf, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);
}
public int Native_GetAttributeItemTag(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	int size =GetNativeCell(3);
	char[] buf = new char[size+1];
	if(GetStatementStringForID(g_statement_GetAttributeItemTag, id, buf, size)) {
		SetNativeString(2, buf, size);
		return view_as<int>(true);
	}
	return view_as<int>(false);
}
public int Native_GetAttributeProperties(Handle hPlugin, int nParams) {
	int id = GetNativeCell(1);
	char strId[16];
	IntToString(id, strId, sizeof(strId));
	int values[NUM_ATT_CACHE_FIELDS];
	if(GetTrieArray(g_attribute_cache, strId, values, NUM_ATT_CACHE_FIELDS)) {
		for(int i = 0; i < NUM_ATT_CACHE_FIELDS; i++) {
			SetNativeCellRef(i+2, values[i]);
		}
		return view_as<int>(true);
	}
	return view_as<int>(false);
}

stock TF2ItemQuality GetQualityByName(const char[] strSearch) {
	if(strlen(strSearch) == 0) {
		return view_as<TF2ItemQuality>(-1);
	}
	return view_as<TF2ItemQuality>(FindStringInArray(g_quality_mappings, strSearch));
}
public int Native_GetQualityByName(Handle hPlugin, int nParams) {
	char strQualityName[TF2IDB_ITEMQUALITY_LENGTH+1];
	GetNativeString(1, strQualityName, TF2IDB_ITEMQUALITY_LENGTH);
	return view_as<int>(GetQualityByName(strQualityName));
}
public int Native_GetQualityName(Handle hPlugin, int nParams) {
	int quality = GetNativeCell(1);
	int length = GetNativeCell(3);
	char[] strQualityName = new char[length+1];
	if(GetArrayString(g_quality_mappings, quality, strQualityName, length) <= 0) {
		return view_as<int>(false);
	}
	SetNativeString(2, strQualityName, length);
	return view_as<int>(true);
}
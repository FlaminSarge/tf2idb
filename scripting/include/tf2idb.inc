#if defined _tf2idb_included
	#endinput
#endif
#define _tf2idb_included

#include <tf2>

#define TF2IDB_MAX_ATTRIBUTES 			15	/**< Maximum number of attributes an item has */
#define TF2IDB_ITEMCLASS_LENGTH			64	/**< Maximum item class name string length */
#define TF2IDB_ITEMSLOT_LENGTH			16	/**< Maximum item slot string length */
#define TF2IDB_ITEMQUALITY_LENGTH		16	/**< Maximum item quality string length */
#define TF2IDB_ATTRIBNAME_LENGTH		96	/**< Maximum attribute name string length */
#define TF2IDB_ATTRIBCLASS_LENGTH		32	/**< Maximum attribute class string length */

enum TF2ItemSlot {
	TF2ItemSlot_Primary = 0,
	TF2ItemSlot_Secondary = 1,
	TF2ItemSlot_Sapper = 1,
	TF2ItemSlot_Melee = 2,
	TF2ItemSlot_PDA = 3,
	TF2ItemSlot_PDA1 = 3,
	TF2ItemSlot_PDA2 = 4,
	TF2ItemSlot_Building = 5,
	TF2ItemSlot_Hat = 5,
	TF2ItemSlot_Head = 5,
	TF2ItemSlot_Misc = 6,
	TF2ItemSlot_Action = 7,
	TF2ItemSlot_Taunt,
};

enum TF2ItemQuality {
	TF2ItemQuality_Normal = 0, // 0
	TF2ItemQuality_Rarity1,
	TF2ItemQuality_Genuine = 1,
	TF2ItemQuality_Rarity2,
	TF2ItemQuality_Vintage,
	TF2ItemQuality_Rarity3,
	TF2ItemQuality_Rarity4,
	TF2ItemQuality_Unusual = 5,
	TF2ItemQuality_Unique,
	TF2ItemQuality_Community,
	TF2ItemQuality_Developer,
	TF2ItemQuality_Selfmade,
	TF2ItemQuality_Customized, // 10
	TF2ItemQuality_Strange,
	TF2ItemQuality_Completed,
	TF2ItemQuality_Haunted,
	TF2ItemQuality_ToborA,
	TF2ItemQuality_Collectors = 14,
	TF2ItemQuality_PaintkitWeapon
};


/**
 * Checks whether an item ID is valid or not.
 *
 * @param id			Item ID.
 * @return				True if valid item ID.
 */
native bool TF2IDB_IsValidItemID(int id);

/**
 * Retrives the name of an item given an item ID.
 *
 * @param id			Item ID.
 * @param buffer		Buffer to the store the item's name.
 * @param maxlength		Maximum length of the name buffer.
 * @return				True if valid item ID.
 */
native bool TF2IDB_GetItemName(int id, char[] buffer, int maxlength);

/**
 * Retrives the class name of an item given an item ID.
 * @note A valid class name could be "tf_weapon_sword".
 *
 * @param id			Item ID.
 * @param buffer		Buffer to the store the item's class name.
 * @param maxlength		Maximum length of the class name buffer.
 * @return				True if valid item ID.
 */
native bool TF2IDB_GetItemClass(int id, char[] buffer, int maxlength);

/**
 * Retrives the slot name of an item given an item ID.
 * @note A valid slot name could be "head", "taunt" or "melee".
 *
 * @param id			Item ID.
 * @param buffer		Buffer to the store the item's slot name.
 * @param maxlength		Maximum length of the slot name buffer.
 * @param classType		A class that uses that item.
 * @return				True if valid item ID and if that class can equip that item.
 */
native bool TF2IDB_GetItemSlotName(int id, char[] buffer, int maxlength, TFClassType classType=TFClass_Unknown);

/**
 * Retrives the slot of an item given a valid item ID and a TFClassType.
 *
 * @param id			Item ID.
 * @param classType		A class that uses that item.
 * @return				A valid slot if a valid item ID maps to classType.
 */
native TF2ItemSlot TF2IDB_GetItemSlot(int id, TFClassType classType=TFClass_Unknown);

/**
 * Retrives the quality name for a given item ID.
 *
 * @param id			Item ID.
 * @param buffer		Buffer to the store the item's quality name.
 * @param maxlength		Maximum length of the quality name buffer.
 * @return				True if valid item ID.
 */
native bool TF2IDB_GetItemQualityName(int id, char[] string, int length);

/**
 * Retrives the quality for a given item ID.
 *
 * @param id			Item ID.
 * @return				Item quality.
 */
native TF2ItemQuality TF2IDB_GetItemQuality(int id);

/**
 * Retrives the maximum and minumum levels for a given item ID.
 *
 * @param id			Item ID.
 * @param min			ByRef variable to store the minimum item level.
 * @param max			ByRef variable to store the maximum item level.
 * @return				True if valid item ID.
 */
native bool TF2IDB_GetItemLevels(int id, int &min, int &max);

/**
 * Retrives all attribute IDs and values for a given item ID.
 *
 * @param id			Item ID.
 * @param attributeIds	Array of atrribute ids found for that item.
 * @param max			Array of values for the attributes found.
 * @return				Number of attributes found.
 */
native int TF2IDB_GetItemAttributes(int id, int attributeIds[TF2IDB_MAX_ATTRIBUTES], float values[TF2IDB_MAX_ATTRIBUTES]);

/**
 * Retrives all the equip region names for a given item ID.
 *
 * @param id			Item ID.
 * @return				ArrayList containing the equip region names for the item ID.
 */
native ArrayList TF2IDB_GetItemEquipRegions(int id);

/**
 * Resolves if two regions conflict with each other.
 *
 * @param region1		First region to compare.
 * @param region1		Second region to compare.
 * @return				True if regions conflict.
 */
native bool TF2IDB_DoRegionsConflict(const char[] region1, const char[] region2);

/**
 * Returns a list that contains all particle IDs.
 *
 * @return				ArrayList containing all particle IDs.
 */
native ArrayList TF2IDB_ListParticles();

/**
 * Queries to the items database and returns a list of integers
 * for the first column of the result set.
 *
 * @return				ArrayList of integers on the fist column.
 */
native ArrayList TF2IDB_FindItemCustom(const char[] query);

/**
 * Resolves whether or not an given item has an attribute.
 *
 * @param id			Item ID.
 * @param attributeId	Attribute ID.
 * @return				True if the item has that attribute.
 */
native bool TF2IDB_ItemHasAttribute(int id, int attributeId);

/**
 * Returns a bitfield of classes that use a certain item.
 * @note You can check for a specific class by doing:
 * ``TF2IDB_UsedByClasses(id) & (1 << view_as<int>(TFClass_Scout))``
 * @note This DOES INCLUDE TFClass_Unknown, as (1 << 0)
 *
 * @param id			Item ID.
 * @return				Bitfield of classes that use the item.
 */
native int TF2IDB_UsedByClasses(int id);

//All return false if ID invalid/not found

/**
 * Checks whether an attribute ID is valid or not.
 *
 * @param attributeId	Attribute ID.
 * @return				True if valid attribute ID.
 */
native bool TF2IDB_IsValidAttributeID(int attributeId);

/**
 * Retrives the name of an item given an attribute ID.
 *
 * @param attributeId	Attribute ID.
 * @param buffer		Buffer to the store the attribute's name.
 * @param maxlength		Maximum length of the name buffer.
 * @return				True if valid attribute ID.
 */
native bool TF2IDB_GetAttributeName(int attributeId, char[] buffer, int length);

/**
 * Retrives the class name of an attribute given an attribute ID.
 *
 * @param attributeId	Attribute ID.
 * @param buffer		Buffer to the store the attribute class name.
 * @param maxlength		Maximum length of the class name buffer.
 * @return				True if valid attribute ID.
 */
native bool TF2IDB_GetAttributeClass(int attributeId, char[] buffer, int maxlength);

/**
 * Retrives the type name of an attribute given an attribute ID.
 *
 * @param attributeId	Attribute ID.
 * @param buffer		Buffer to the store the attribute type name.
 * @param maxlength		Maximum length of the type name buffer.
 * @return				True if valid attribute ID.
 */
native bool TF2IDB_GetAttributeType(int attributeId, char[] buffer, int maxlength);

/**
 * Retrives the description string of an attribute given an attribute ID.
 *
 * @param attributeId	Attribute ID.
 * @param buffer		Buffer to the store the description string.
 * @param maxlength		Maximum length of the description string buffer.
 * @return				True if valid attribute ID.
 */
native bool TF2IDB_GetAttributeDescString(int attributeId, char[] buffer, int maxlength);

/**
 * Retrives the description format of an attribute given an attribute ID.
 *
 * @param attributeId	Attribute ID.
 * @param buffer		Buffer to the store the description format.
 * @param maxlength		Maximum length of the description format buffer.
 * @return				True if valid attribute ID.
 */
native bool TF2IDB_GetAttributeDescFormat(int attributeId, char[] buffer, int maxlength);

/**
 * Retrives the effect type of an attribute given an attribute ID.
 *
 * @param attributeId	Attribute ID.
 * @param buffer		Buffer to the store the effect type.
 * @param maxlength		Maximum length of the effect type buffer.
 * @return				True if valid attribute ID.
 */
native bool TF2IDB_GetAttributeEffectType(int attributeId, char[] buffer, int maxlength);

/**
 * Retrives the armory description of an attribute given an attribute ID.
 *
 * @param attributeId	Attribute ID.
 * @param buffer		Buffer to the store the armory description.
 * @param maxlength		Maximum length of the armory description buffer.
 * @return				True if valid attribute ID.
 */
native bool TF2IDB_GetAttributeArmoryDesc(int attributeId, char[] buffer, int maxlength);

/**
 * Retrives the item tag of an attribute given an attribute ID.
 *
 * @param attributeId	Attribute ID.
 * @param buffer		Buffer to the store the item tag.
 * @param maxlength		Maximum length of the item tag buffer.
 * @return				True if valid attribute ID.
 */
native bool TF2IDB_GetAttributeItemTag(int attributeId, char[] buffer, int maxlength);

/**
 * Retrives the properties of an attribute given an attribute ID.
 * @note -1 indicates that the field is not present on that attribute.
 *
 * @param attributeId						Attribute ID.
 * @param hidden							ByRef value to store the propery "hidden".
 * @param stored_as_integer					ByRef value to store the propery "stored_as_integer".
 * @param is_set_bonus						ByRef value to store the propery "is_set_bonus".
 * @param is_user_generated					ByRef value to store the propery "is_user_generated".
 * @param can_affect_recipe_component_name	ByRef value to store the propery "can_affect_recipe_component_name".
 * @return									True if valid attribute ID.
 */
native bool TF2IDB_GetAttributeProperties(int attributeId, 
										  int &hidden=-1, 
										  int &stored_as_integer=-1, 
										  int &is_set_bonus=-1, 
										  int &is_user_generated=-1, 
										  int &can_affect_recipe_component_name=-1);

/**
 * Retrives the name of a quality given a quality.
 *
 * @param quality		Quality.
 * @param buffer		Buffer to the store the quality name.
 * @param maxlength		Maximum length of the quality name buffer.
 * @return				True if valid quality and maxlength > 0.
 */
native bool TF2IDB_GetQualityName(TF2ItemQuality quality, char[] buffer, int maxlength);

/**
 * Retrives a quality given it's name.
 *
 * @param buffer		A quality name.
 * @return				A TF2ItemQuality value.
 */
native TF2ItemQuality TF2IDB_GetQualityByName(const char[] buffer);

/**
 * @brief	Execute a custom prepared statement on the TF2IDB tables, returning the executed DBStatement
 *			Table schemas are:
 *			tf2idb_class: int id, class
 *			tf2idb_item_attributes: int id, int attribute, int value
 *			tf2idb_item: int id, name, item_name, class, slot, quality, tool_type, int min_ilevel, int max_ilevel, int baseitem, holiday_restriction, int has_string_attribute
 *			tf2idb_particles: int id, name
 *			tf2idb_equip_conflicts: name, region
 *			tf2idb_equip_regions: int id, region
 *			tf2idb_capabilities: int id, capability
 *			tf2idb_attributes: int id, name, attribute_class, attribute_type, description_string, description_format, effect_type, int hidden, int stored_as_integer, armory_desc, int is_set_bonus, int is_user_generated, int can_affect_recipe_component_name, apply_tag_to_item_definition
 *
 * @param	query			Prepared SQL statement query string (e.g. "SELECT id FROM tf2idb_attributes WHERE name=?")
 * @param	arguments		Array handle containing the string arguments to the SQL statement
 * @param	maxStringSize	Max size of any of the arguments
 *
 * @return					A fully executed DBStatement handle, or INVALID_HANDLE if the statement
 *							execution failed. This handle must be closed by the calling plugin, even though it is owned by tf2idb.
 **/
native DBStatement TF2IDB_CustomQuery(const char[] query, ArrayList arguments, int maxStringSize);

public SharedPlugin __pl_tf2idb = {
	name = "tf2idb",
	file = "tf2idb.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_tf2idb_SetNTVOptional() {
	MarkNativeAsOptional("TF2IDB_IsValidItemID");
	MarkNativeAsOptional("TF2IDB_GetItemName");
	MarkNativeAsOptional("TF2IDB_GetItemClass");
	MarkNativeAsOptional("TF2IDB_GetItemSlotName");
	MarkNativeAsOptional("TF2IDB_GetItemSlot");
	MarkNativeAsOptional("TF2IDB_GetItemQualityName");
	MarkNativeAsOptional("TF2IDB_GetItemQuality");
	MarkNativeAsOptional("TF2IDB_GetItemLevels");
	MarkNativeAsOptional("TF2IDB_GetItemAttributes");
	MarkNativeAsOptional("TF2IDB_GetItemEquipRegions");
	MarkNativeAsOptional("TF2IDB_DoRegionsConflict");
	MarkNativeAsOptional("TF2IDB_ListParticles");
	MarkNativeAsOptional("TF2IDB_FindItemCustom");
	MarkNativeAsOptional("TF2IDB_ItemHasAttribute");
	MarkNativeAsOptional("TF2IDB_UsedByClasses");

	MarkNativeAsOptional("TF2IDB_IsValidAttributeID");
	MarkNativeAsOptional("TF2IDB_GetAttributeName");
	MarkNativeAsOptional("TF2IDB_GetAttributeClass");
	MarkNativeAsOptional("TF2IDB_GetAttributeType");
	MarkNativeAsOptional("TF2IDB_GetAttributeDescString");
	MarkNativeAsOptional("TF2IDB_GetAttributeDescFormat");
	MarkNativeAsOptional("TF2IDB_GetAttributeEffectType");
	MarkNativeAsOptional("TF2IDB_GetAttributeArmoryDesc");
	MarkNativeAsOptional("TF2IDB_GetAttributeItemTag");
	MarkNativeAsOptional("TF2IDB_GetAttributeProperties");

	MarkNativeAsOptional("TF2IDB_GetQualityName");
	MarkNativeAsOptional("TF2IDB_GetQualityByName");

	MarkNativeAsOptional("TF2IDB_CustomQuery");
}
#endif

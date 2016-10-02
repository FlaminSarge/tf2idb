TF_FOLDER = 'C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf/'
ITEMS_GAME = TF_FOLDER + 'scripts/items/items_game.txt'
DB_FILE = 'tf2idb.sq3'

# 12/18/2015

import vdf
import sqlite3
import traceback
import time

def resolve_prefabs(item, data):
    prefabs = item.get('prefab')
    if prefabs:
        prefab_aggregate = {}
        for prefab in prefabs.split():
            prefab_data = data['prefabs'][prefab]
            prefab_data = resolve_prefabs(prefab_data.copy(), data)
            prefab_aggregate.update(prefab_data)
        prefab_aggregate.update(item)
        item = prefab_aggregate
    return item

def main():
    data = None
    with open(ITEMS_GAME) as f:
        data = vdf.parse(f)
        data = data['items_game']

    db = sqlite3.connect(DB_FILE)
    dbc = db.cursor()

    dbc.execute('DROP TABLE IF EXISTS new_tf2idb_class')
    dbc.execute('DROP TABLE IF EXISTS new_tf2idb_item_attributes')
    dbc.execute('DROP TABLE IF EXISTS new_tf2idb_item')
    dbc.execute('DROP TABLE IF EXISTS new_tf2idb_particles')
    dbc.execute('DROP TABLE IF EXISTS new_tf2idb_equip_conflicts')
    dbc.execute('DROP TABLE IF EXISTS new_tf2idb_equip_regions')
    dbc.execute('DROP TABLE IF EXISTS new_tf2idb_capabilities')
    dbc.execute('DROP TABLE IF EXISTS new_tf2idb_attributes')

    dbc.execute('CREATE TABLE "new_tf2idb_class" ("id" INTEGER NOT NULL , "class" TEXT NOT NULL , "slot" TEXT , PRIMARY KEY ("id", "class"))')
    dbc.execute('CREATE TABLE "new_tf2idb_item_attributes" ("id" INTEGER NOT NULL , "attribute" INTEGER NOT NULL , "value" TEXT NOT NULL, PRIMARY KEY ("id", "attribute") )')
    dbc.execute('CREATE TABLE "new_tf2idb_item" ('
        '"id" INTEGER PRIMARY KEY  NOT NULL ,'
        '"name" TEXT NOT NULL,'
        '"item_name" TEXT NOT NULL,'
        '"class" TEXT NOT NULL,'
        '"slot" TEXT,'
        '"quality" TEXT NOT NULL,'
        '"tool_type" TEXT,'
        '"min_ilevel" INTEGER,'
        '"max_ilevel" INTEGER,'
        '"baseitem" INTEGER,'
        '"holiday_restriction" TEXT,'
        '"has_string_attribute" INTEGER,'
        '"propername" INTEGER'
        ')'
    )
    dbc.execute('CREATE TABLE "new_tf2idb_particles" ("id" INTEGER PRIMARY KEY  NOT NULL , "name" TEXT NOT NULL )')
    dbc.execute('CREATE TABLE "new_tf2idb_equip_conflicts" ("name" TEXT NOT NULL , "region" TEXT NOT NULL , PRIMARY KEY ("name", "region"))')
    dbc.execute('CREATE TABLE "new_tf2idb_equip_regions" ("id" INTEGER NOT NULL , "region" TEXT NOT NULL , PRIMARY KEY ("id", "region"))')
    dbc.execute('CREATE TABLE "new_tf2idb_capabilities"  ("id" INTEGER NOT NULL , "capability" TEXT NOT NULL )')
    dbc.execute('CREATE TABLE "new_tf2idb_attributes" ('
        '"id" INTEGER PRIMARY KEY  NOT NULL ,'
        '"name" TEXT NOT NULL,'
        '"attribute_class" TEXT,'
        '"attribute_type" TEXT,'
        '"description_string" TEXT,'
        '"description_format" TEXT,'
        '"effect_type" TEXT,'
        '"hidden" INTEGER,'
        '"stored_as_integer" INTEGER,'
        '"armory_desc" TEXT,'
        '"is_set_bonus" INTEGER,'
        '"is_user_generated" INTEGER,'
        '"can_affect_recipe_component_name" INTEGER,'
        '"apply_tag_to_item_definition" TEXT'
        ')'
    )

    nonce = int(time.time())
    dbc.execute('CREATE INDEX "tf2idb_item_attributes_%i" ON "new_tf2idb_item_attributes" ("attribute" ASC)' % nonce)
    dbc.execute('CREATE INDEX "tf2idb_class_%i" ON "new_tf2idb_class" ("class" ASC)' % nonce)
    dbc.execute('CREATE INDEX "tf2idb_item_%i" ON "new_tf2idb_item" ("slot" ASC)' % nonce)


    # particles
    for particle_type,particle_list in data['attribute_controlled_attached_particles'].items():
        for k,v in particle_list.items():
            dbc.execute('INSERT INTO new_tf2idb_particles (id,name) VALUES (?,?)', (k, v['system']) )   #TODO add the other fields too

    # attributes
    attribute_type = {}
    for k,v in data['attributes'].items():
        at = v.get('attribute_type')
        if at:
            atype = at
        else:
            if v.get('stored_as_integer'):
                atype = 'integer'
            else:
                atype = 'float'
        attribute_type[v['name'].lower()] = (k, atype)
        dbc.execute('INSERT INTO new_tf2idb_attributes '
            '(id,name,attribute_class,attribute_type,description_string,description_format,effect_type,hidden,stored_as_integer,armory_desc,is_set_bonus,is_user_generated,can_affect_recipe_component_name,apply_tag_to_item_definition) '
            'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
            (k,v.get('name'),v.get('attribute_class'),v.get('attribute_type'),v.get('description_string'),v.get('description_format'),
                v.get('effect_type'),v.get('hidden'),v.get('stored_as_integer'),v.get('armory_desc'),v.get('is_set_bonus'),
                v.get('is_user_generated'),v.get('can_affect_recipe_component_name'),v.get('apply_tag_to_item_definition')
            )
        )

    # conflicts
    for k,v in data['equip_conflicts'].items():
        for region in v.keys():
            dbc.execute('INSERT INTO new_tf2idb_equip_conflicts (name,region) VALUES (?,?)', (k, region))

    # items
    for id,v in data['items'].items():
        if id == 'default':
            continue
        i = resolve_prefabs(v, data)
        baseitem = 'baseitem' in i

        try:
            tool = None
            if 'tool' in i:
                tool = i['tool'].get('type')

            has_string_attribute = False
            if 'static_attrs' in i:
                for name,value in i['static_attrs'].items():
                    aid,atype = attribute_type[name.lower()]
                    if atype == 'string':
                        has_string_attribute = True
                    dbc.execute('INSERT INTO new_tf2idb_item_attributes (id,attribute,value) VALUES (?,?,?)', (id,aid,value))

            if 'attributes' in i:
                for name,info in i['attributes'].items():
                    aid,atype = attribute_type[name.lower()]
                    if atype == 'string':
                        has_string_attribute = True
                    dbc.execute('INSERT INTO new_tf2idb_item_attributes (id,attribute,value) VALUES (?,?,?)', (id,aid,info['value']))

            dbc.execute('INSERT INTO new_tf2idb_item '
                '(id,name,item_name,class,slot,quality,tool_type,min_ilevel,max_ilevel,baseitem,holiday_restriction,has_string_attribute,propername) '
                'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)', 
                (id,i['name'],i.get('item_name'),i['item_class'],i.get('item_slot'),i.get('item_quality', ''), tool, i.get('min_ilevel'), i.get('max_ilevel'),baseitem,
                    i.get('holiday_restriction'), has_string_attribute, i.get('propername'))
            )

            if 'used_by_classes' in i:
                for prof, val in i['used_by_classes'].items():
                    dbc.execute('INSERT INTO new_tf2idb_class (id,class,slot) VALUES (?,?,?)', (id, prof.lower(), val if val != '1' else None))

            region_field = i.get('equip_region') or i.get('equip_regions')
            if region_field:
                if type(region_field) is str:
                    region_field = {region_field: 1}
                for region in region_field.keys():
                    dbc.execute('INSERT INTO new_tf2idb_equip_regions (id,region) VALUES (?,?)', (id, region))

            # capabilties
            for capability,val in i.get('capabilities', {}).items():
                dbc.execute('INSERT INTO new_tf2idb_capabilities (id,capability) VALUES (?,?)', (id, (capability if val != '0' else '!'+capability)))

        except:
            traceback.print_exc()
            print(id)
            raise

    def replace_table(name):
        dbc.execute('DROP TABLE IF EXISTS %s' % name)
        dbc.execute('ALTER TABLE new_%s RENAME TO %s' % (name,name))

    replace_table('tf2idb_class')
    replace_table('tf2idb_item_attributes')
    replace_table('tf2idb_item')
    replace_table('tf2idb_particles')
    replace_table('tf2idb_equip_conflicts')
    replace_table('tf2idb_equip_regions')
    replace_table('tf2idb_capabilities')
    replace_table('tf2idb_attributes')

    dbc.execute('VACUUM')
    db.commit()
    
if __name__ == "__main__":
    main();
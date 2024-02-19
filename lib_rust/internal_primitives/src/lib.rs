use std::collections::HashMap;

use godot::prelude::*;

// This is a module/crate in which the structures are shared between other gdextension crates
// but is NOT exposed to the Godot Engine.
// For example, interally one can benefit from using HashMap, but ones that are exposed
// to Godot Engine (via extension-library) will have to use Dictionary (viariant).
// Hence there will be a Converter trait of From/To (via .into()) for the shared structures
// for conviniences.

// TileMap::get_tileset() returns Option<Gd<crate::engine::TileSet>>, meaning you can
// only have at most 1 TileSet (or None) per TileMap.  And at the same time, we will
// assume that TileSet will be attached to the TileMap via the Godot Editor, so that
// we do not have to be too concerned about how many tiles are in the tileset, nor its
// dimensions, etc...
// We will ALSO assume that the map (Array[Array[Cell]]) is also Editor defined; BUT
// we will assume that Array.len() and Array[0].len() will be non-zero by the time
// the methods are called.
// There are two types of TileMaps for this game:
// * PlayfieldTileMap: This is the main tilemap that the player will interact with
// * QueueTileMap: This is the tilemap that will show the next 3 tiles that will be
//   available to the player
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BlockUnitsMapType {
    Undefined,
    PlayfieldTileMap, // an NxM grid
    QueueTileMap, // an 1xN or Nx1 grid, either way, assumes that map can be flattenend into a 1D array
}

// NOTE: This enum will need to be assigned to the TileSetScenesCollectionSource scenes (.tscn)
// as a meta-data so that we can identify not by PackedScene, but by the enum value
#[derive(Debug, Clone, Copy, Hash, Eq, PartialEq)] // need both Hash and Eq because it's used as dictionary key
pub enum BlockKeys {
    Undefined,
    Void,             // basically, empty space
    LineBlock1Edge,   // blocks one side
    LineBlock2Corner, // blocks two sides (90 degrees)
    LineBlock3T,      // blocks three sides
    LineBlock4All,    // blocks all sides
    Router1Cross,     // Cross shape (top-down 1 in 1 out, and left-right 1 in 1 out)
    Router1Straight,  // straight line (1 in 1 out)
    Router1Corner,    // 90 degree turn, 1 in 1 out
    Router1Tee,       // T shape (1 in, 2 out)
    Router,           // 1 in, 3 out
    RouteJoin2To1,    // 2 in, 1 out
    RouteJoin3To1,    // 3 in, 1 out
}
type CellIdType = i32; // this is the id of the cell (i.e. the type of block)
type LayerType = i32;
#[derive(Debug, Clone, Copy, PartialEq)]
struct BlockUnitCell {
    key: BlockKeys,
    position: Vector2i, // we're using godot primitives
    layer: LayerType,   // this is the layer of the cell
    cell_source_id: CellIdType,
}
// as much as I appreciate Tuples, they are anonymous and are ref'ed by positon (i.e. tup.0, tup.1, and tup.2, etc)
// so I'll stick with struct for my KVP values in case it grows fatter than 2 elements...
#[derive(Debug, Clone, PartialEq)]
struct BlockUnitCellKVPValue {
    source_id: CellIdType,
    scene: Option<Gd<PackedScene>>,
    resource_path: Option<GString>, // use GString here?
}

// e.g. let mut my_dict: BlockUnitCellDictionaryType<'static> = HashMap::new();  // Key: BlockKeys, Value: BlockUnitCellKVPValue
type TBlockUnitCellDictionaryType = HashMap<BlockKeys, BlockUnitCellKVPValue>;
#[derive(Debug, Clone, PartialEq)]
struct BlockUnitCellDictionaryType {
    dict: TBlockUnitCellDictionaryType, // HashMap can clone, but not copy
}
impl BlockUnitCellDictionaryType {
    fn new() -> Self {
        BlockUnitCellDictionaryType {
            dict: TBlockUnitCellDictionaryType::new(),
        }
    }
    fn insert(
        &mut self,
        key: BlockKeys,
        value: BlockUnitCellKVPValue,
    ) -> Option<BlockUnitCellKVPValue> {
        self.dict.insert(key, value)
    }
    fn get(&self, key: &BlockKeys) -> Option<&BlockUnitCellKVPValue> {
        self.dict.get(key)
    }
    fn remove(&mut self, key: &BlockKeys) -> Option<BlockUnitCellKVPValue> {
        self.dict.remove(key)
    }
    fn len(&self) -> usize {
        self.dict.len()
    }
    fn is_empty(&self) -> bool {
        self.dict.is_empty()
    }
    fn clear(&mut self) {
        self.dict.clear()
    }
    fn keys(&self) -> std::collections::hash_map::Keys<BlockKeys, BlockUnitCellKVPValue> {
        self.dict.keys()
    }
    fn values(&self) -> std::collections::hash_map::Values<BlockKeys, BlockUnitCellKVPValue> {
        self.dict.values()
    }
}

// To be able to render it on the Godot editor (i.e. Inspector), we need to have a way to convert
// the enum to a Godot primitive type (i.e. GString)
// Once From<T> is implemented (conversion traits), you can then do "into()"
// i.e. let gstring: GString = TileMapType::Undefined.into();
impl From<BlockUnitsMapType> for GString {
    fn from(tile_map_type: BlockUnitsMapType) -> Self {
        match tile_map_type {
            BlockUnitsMapType::Undefined => "Undefined".into(),
            BlockUnitsMapType::PlayfieldTileMap => "PlayfieldTileMap".into(),
            BlockUnitsMapType::QueueTileMap => "QueueTileMap".into(),
        }
    }
}
impl From<BlockUnitsMapType> for i64 {
    fn from(tile_map_type: BlockUnitsMapType) -> Self {
        match tile_map_type {
            BlockUnitsMapType::Undefined => BlockUnitsMapType::Undefined.into(),
            BlockUnitsMapType::PlayfieldTileMap => BlockUnitsMapType::PlayfieldTileMap.into(),
            BlockUnitsMapType::QueueTileMap => BlockUnitsMapType::QueueTileMap.into(),
        }
    }
}

impl TryFrom<GString> for BlockUnitsMapType {
    type Error = ();

    fn try_from(godot_string: GString) -> Result<Self, Self::Error> {
        match godot_string.to_string().as_str() {
            "Undefined" => Ok(BlockUnitsMapType::Undefined),
            "PlayfieldTileMap" => Ok(BlockUnitsMapType::PlayfieldTileMap),
            "QueueTileMap" => Ok(BlockUnitsMapType::QueueTileMap),
            _ => Err(()),
        }
    }
}
impl TryFrom<i64> for BlockUnitsMapType {
    type Error = ();

    // NOTE: Unfortunately, we will get into this issue of "lost in translation" symptoms
    // because C/C++ enums are equivalent to int in terms of sequential order of definition
    fn try_from(i: i64) -> Result<Self, Self::Error> {
        match i {
            0 => Ok(BlockUnitsMapType::Undefined),
            1 => Ok(BlockUnitsMapType::PlayfieldTileMap),
            2 => Ok(BlockUnitsMapType::QueueTileMap),
            _ => Err(()),
        }
    }
}

// rather than erroing, will just return an empty collection if cannot convert
// Hopefully, we can ASSUME that Godot Dictionary will always have UNIQUE keys
// (rust HashMap does upsert to prevent duplicates, hence we can assume at least
// from Rust side, it will always be unique)
impl From<Dictionary> for BlockUnitCellDictionaryType {
    fn from(dict: Dictionary) -> Self {
        let mut new_dict = BlockUnitCellDictionaryType::new();
        for variant_key in dict.keys_array().iter_shared() {
            let possible_value = dict.get(variant_key);
            if possible_value.is_some() {
                let variant_value = possible_value.unwrap();
                // see if key meets BlockKeys enum
//                let key_as_blockkeys: BlockKeys = BlockKeys::try_from(variant_key).unwrap();
//                if key_as_blockkeys.is_err() {
//                    continue;
//                }
//                else if key_as_blockkeys.unwrap() == BlockKeys::Undefined {
//                    continue;
//                }
//                // cast to see if Value is of TileSetScenesCollectionSource type, if not, skip
//                if ! variant_value.is_class::<TileSetScenesCollectionSource>() {
//                    continue;
//                }
//                let tile_set_scenes_collection_source  = variant_value as TileSetScenesCollectionSource;
//                let source_id = tile_set_scenes_collection_source.get_id() as CellIdType;
//                let possible_scene = tile_set_scenes_collection_source.get_scene() as Option<Gd<PackedScene>>;
//                let possible_resource_path = tile_set_scenes_collection_source.get_path() as Option<GString>;
//
//                let cell_unit = BlockUnitCellKVPValue {
//                    source_id: source_id,
//                    scene: possible_scene,
//                    resource_path: possible_resource_path  ,
//                };
//
//                // Hashmap upsert
//                new_dict.insert(key_as_blockkeys, cell_unit);
            }
        }
        new_dict
    }
}
impl From<BlockUnitCellDictionaryType> for Dictionary {
    fn from(dict: BlockUnitCellDictionaryType) -> Self {
        let mut new_dict = Dictionary::new();
//        for (key, value) in dict {
//            new_dict.insert(key.into(), value.into());
//        }
        new_dict
    }
}

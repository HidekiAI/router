use godot::prelude::*;

// CRITICAL: __MUST__ expose entry point or else you will get the error:
// "GDExtension entry point 'gdext_rust_init' not found in library ..."
#[gdextension]
unsafe impl ExtensionLibrary for entry_point::ForBlockUnits {}

pub mod entry_point {
    use std::{cell::Ref, collections::HashMap};

    use godot::{
        engine::{ITileMap, TileMap, TileSetScenesCollectionSource, TileSetSource},
        prelude::*,
    };
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
    #[derive(Debug, Clone, Copy, Hash, Eq, PartialEq)]  // need both Hash and Eq because it's used as dictionary key
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
    struct BlockUnitCell {
        key: BlockKeys,
        position: Vector2i, // we're using godot primitives
        layer: LayerType,   // this is the layer of the cell
        cell_source_id: CellIdType,
    }
    // as much as I appreciate Tuples, they are anonymous and are ref'ed by positon (i.e. tup.0, tup.1, and tup.2, etc)
    // so I'll stick with struct for my KVP values in case it grows fatter than 2 elements...
    struct BlockUnitCellKVPValue {
        source_id: CellIdType,
        scene: Option<Gd<PackedScene>>,
        resource_path: Option<GString>, // use GString here?
    }
    // e.g. let mut my_dict: BlockUnitCellDictionaryType<'static> = HashMap::new();  // Key: BlockKeys, Value: BlockUnitCellKVPValue
    type BlockUnitCellDictionaryType = HashMap<BlockKeys, BlockUnitCellKVPValue>;

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

    #[derive(GodotClass)]
    #[class(base=TileMap)]
    pub struct ForBlockUnits {
        base: godot::prelude::Base<TileMap>,

        // Note that we export as enum (@export_enum) because exporing as GString will not show pull-down list
        //#[export(enum = (Undefined=0, PlayfieldType=1, QueueType=2))] // Note that this enum (list) is not the same as TileMapType, but the order is relatively same...  (it's the C/C++ "enum is equivelant to int" mentality)
        //map_type_i64_1: i64,   // this gets visible to the Editor/Inspector, it's basically an index to enum defined in #export, so not too useful...

        // Seems @export_enum is broken, but fortunately, PROPERTY_HINT_ENUM works, so we will use that instead for pulldown selection
        // Unsure how it works interally, but will assume it works similar to .net Enum.TryParse() in which as long as the string is EXACT match to
        // the enum name, it will work.
        #[var(hint = PROPERTY_HINT_ENUM, hint_string = "Undefined, PlayfieldTileMap, QueueTileMap", usage_flags = [PROPERTY_USAGE_EDITOR])]
        map_type_string: GString,
        map_type_internal: BlockUnitsMapType, // this is the actual value that we will use (I do NOT want to deal with strings)

        cell_map: Vec<Vec<Option<BlockUnitCell>>>, // this is the 2D array of cells (i.e. the map)
        cell_type_lookup: BlockUnitCellDictionaryType, // this is the lookup table for the cell types
    }

    // NOTE: (I think) because ITileMap is derived from INode, here, if dealing with just
    // minimal interfaces of INode, you can get away with using INode instead of ITileMap
    // (or at least, it can compile)
    #[godot_api]
    impl ITileMap for ForBlockUnits {
        fn init(base: Base<TileMap>) -> Self {
            godot_print!("tile_related::MyTileExtension::init()");

            Self {
                base,
                map_type_internal: BlockUnitsMapType::Undefined,
                map_type_string: BlockUnitsMapType::Undefined.into(),
                cell_map: Vec::new(),
                cell_type_lookup: HashMap::new(),
            }
            // Q: Build cell_type_lookup dictionary here in init() or in ready()?
        }

        fn ready(&mut self) {
            godot_print!("tile_related::MyTileExtension::ready()");
            // build the cell_type_lookup dictionary here IF TileSet is set...
            // if not, we'll need to follow the pattern in which on the time of
            // getting, it will check if dictionary is empty, and if so, build it
            if self.base_mut().get_tileset().is_some() {
                // build the cell_type_lookup dictionary here IF it's not populated yet
                if self.cell_type_lookup.is_empty() {
                    self.cell_type_lookup = self.build_cell_type_lookup();
                }
            }

            // TODO: If persisted system (autoload) exist, load it here?
            // should, by here test for requirements (IF TileSet is not set, these tests should NOT be checked,
            // mainly because you cannot create a TileMap array without a TileSet):
            // * if it is TileMapType::PlayfieldTileMap then it should have at least a NxM grid where N >= 1 and M >= 2, or M >= 1 and N >= 2
            // * if it is TileMapType::QueueTileMap then it should have at least a 1xN or Nx1 grid where N >= 1
            // * TileSet (if set) should have at least 1 tile that is of type TileSetScenesCollectionSource, and that all tiles
            //   in the map are assigned with cell type of TileSetScenesCollectionSource
            if self.base_mut().get_tileset().is_none() {
                godot_print!("tile_related::MyTileExtension::ready() - TileSet is not set, so no further checks will be done");
                return;
            }
            // if the map is not set (dimension is 0x0), then we will not do any further checks
            let map_dimension = self.base_mut().get_used_rect().size;
            if map_dimension.x == 0 || map_dimension.y == 0 {
                godot_print!("tile_related::MyTileExtension::ready() - TileMap is not set, so no further checks will be done");
                return;
            }

            // get assigned (used) cell coordinates (flattened)
            let layer = 0;
            let used_cells_coord_gd = self.base_mut().get_used_cells(layer);
            // I really dislike Godot Array, so I want to use the regular Rust Vec instead
            let mut used_cell_coords: Vec<Vector2i> = Vec::new();
            for i in 0..used_cells_coord_gd.len() {
                let vec2i = used_cells_coord_gd.get(i);
                used_cell_coords.push(vec2i);
            }

            // and also build the 2D array of cells
            for x in 0..map_dimension.x {
                let mut row: Vec<Option<BlockUnitCell>> = Vec::new();
                for y in 0..map_dimension.y {
                    // NOTE: -1 means the cell is not assigned (basically, won't be in used_cell_coords above)
                    let cell_source_id = self
                        .base_mut()
                        .get_cell_source_id(layer, Vector2i::new(x, y));

                    if cell_source_id == -1 {
                        row.push(None);
                    } else {
                        // TODO: Perhaps verify that this coordinate/position matches used_cells_coords
                        let pos = Vector2i::new(x, y);
                        let key = BlockKeys::Undefined;
                        row.push(Some(BlockUnitCell {
                            key: key,
                            position: pos,
                            layer: layer,
                            cell_source_id: cell_source_id,
                        }));
                    }
                }
                self.cell_map.push(row);
            }

            if self.map_type_internal == BlockUnitsMapType::PlayfieldTileMap {
                if self.cell_map.len() < 2 {
                    godot_print!("tile_related::MyTileExtension::ready() - PlayfieldTileMap should have at least 2 rows or 2 columns");
                    return;
                }
                if self.cell_map[0].len() < 1 {
                    godot_print!("tile_related::MyTileExtension::ready() - PlayfieldTileMap should have at least 2 rows or 2 columns");
                    return;
                }
            } else if self.map_type_internal == BlockUnitsMapType::QueueTileMap {
                if self.cell_map.len() < 1 {
                    godot_print!("tile_related::MyTileExtension::ready() - QueueTileMap should have at least 1 row or 1 column");
                    return;
                }
                if self.cell_map[0].len() < 1 {
                    godot_print!("tile_related::MyTileExtension::ready() - QueueTileMap should have at least 1 row or 1 column");
                    return;
                }
            }
        }
    }

    impl ForBlockUnits {
        fn build_cell_type_lookup(&mut self) -> BlockUnitCellDictionaryType {
            let mut cell_type_lookup: BlockUnitCellDictionaryType = HashMap::new();
            // traverse the tileset and extract only the tiles that are of the type TileSetScenesCollectionSource
            if self.base().get_tileset().is_some() {
                let tileset = self.base().get_tileset().unwrap();
                for source_index in 0..tileset.get_source_count() {
                    let source_id = tileset.get_source_id(source_index);
                    let possible_source: Option<Gd<TileSetSource>> = match tileset.get_source(source_id) {
                        Some(tile_source) => {
                            let is_scene_collection = tile_source.is_class("TileSetScenesCollectionSource".into());

                            let tile_source_scenecollection: Option<Gd<TileSetScenesCollectionSource>> =
                                match is_scene_collection {
                                    true => {
                                        let mut tile_source_as_scenecollection_mut =
                                            tile_source.clone().cast::<TileSetScenesCollectionSource>();
                                        let scenes_in_this_tile =
                                            tile_source_as_scenecollection_mut.get_scene_tiles_count();
                                        for scne_tiles_index in 0..scenes_in_this_tile {
                                            let tile_id =
                                                tile_source_as_scenecollection_mut.get_scene_tile_id(scne_tiles_index);
                                            let possible_packed_scene: Option<Gd<PackedScene>> =
                                                tile_source_as_scenecollection_mut.get_scene_tile_scene(tile_id);
                                            let possible_resource_path: Option<GString> =
                                                match possible_packed_scene {
                                                    Some(packed_scene) => {
                                                        // i.e. "res://scenes/block_units/voice.tscn"
                                                        Some(packed_scene.get_path())
                                                    }
                                                    None => {
                                                        godot_print!("tile_related::MyTileExtension::build_cell_type_lookup() - packed_scene is None");
                                                        None
                                                    }
                                                };

                                            // We ASSUME that each scenes (.tscn) that are TileSet related, has an extra
                                            // meta-data assigned, in which it has the BLockKeys enum value to it...

                                            // check if this scene (possible_resource_path) already exists in the lookup dictionary
                                            // if so, just update the source_id; else add it to the dictionary
                                            //if let upserted_value =
                                            //    cell_type_lookup.entry(tile_source.get_key())
                                            //{
                                            //    upserted_value.source_id = source_id;
                                            //} else {
                                            //    let block_unit_cell_kvp_value =
                                            //        BlockUnitCellKVPValue {
                                            //            source_id: source_id,
                                            //            scene: possible_packed_scene,
                                            //            resource_path: possible_resource_path,
                                            //        };
                                            //    cell_type_lookup.insert(
                                            //        tile_source.get_key(),
                                            //        block_unit_cell_kvp_value,
                                            //    );
                                            //}

                                        }

                                        Some(tile_source_as_scenecollection_mut)
                                    }
                                    false => {
                                        godot_print!("tile_related::MyTileExtension::build_cell_type_lookup() - tile_source is not of class TileSetScenesCollectionSource");
                                        None
                                    }
                                };

                            Some(tile_source)
                        }
                        None => {
                            godot_print!("tile_related::MyTileExtension::build_cell_type_lookup() - tileset.get_source() returned None");
                            None
                        }
                    };
                }
            }
            cell_type_lookup
        }
    }
}

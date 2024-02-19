use std::collections::HashMap;

use godot::prelude::*;
//use godot::{engine::Engine, prelude::*};
// NOTE: Shared libs CANNOT export entry-points, for you WILL get a linker error
// of 'error LNK2005: gdext_rust_init already defined in...' error.
// In another words, for Autoload-based extensions, you'll need to do
// the 'get_singleton()' method in which you'd have to have it
// query by string, i.e.:
//        pub fn get_singleton_test(&self) -> Option<Variant> {
//            // we ASSUME that the singleton ForAutoloadPrimitives is a valid struct
//            // using gawd-awful-typo-error-prone string-based getter:
//            match godot::engine::Engine::singleton()
//                .get_singleton(StringName::from("ForAutoloadPrimitives"))
//            {
//                Some(mut singleton) => {
//                    // Sadly, because we cannot link to the singleton directly, we cannot cast<ForAutoLoadPrimitives>() or
//                    // try_cast<ForAutoLoadPrimitives>() to it, and just "trust" that the method "foo()" exists:
//                    // at least, if we can try_cast, we could have had another match() statement here
//                    // we ASSUME that method ForAutoloadPrimitives::foo() exists!
//                    let call_response = singleton.call("foo".into(), &[]);
//                    Some(call_response)
//                }
//                None => {
//                    //... do something, probably the best thing to do is complain that you'd need to make sure the autoload_primitives.gdextension exist
//                    godot_error!("tile_related::MyTileExtension::get_singleton_test() - ForAutoloadPrimitives singleton via autoload_primitives.gdextension is not loaded!");
//                    None
//                }
//            }
//        }
// Sadly, due to this approach (it's a viable approach, but it's not the best), you CANNOT
// declare dependencies of this crate disguised as GDExtension into your Cargo.toml
// and ASSUME that it's loaded into the scene (hence, you'd do the 'get_singleton()' method with string
// and may return None).
// NOTE: Note that on the GDScript side, it's more "useful" in a sens that you can just directly
// access it via simple logice:
//      AutoloadPrimitives.set_foo(42);
//      AutoLoadPrimitives.get_foo();
#[derive(GodotClass)]
#[class(tool, init, base=Object)] // uncomment this (with default init) and remove below (impl init)
pub struct AutoloadPrimitives {
    //base: Mutex<Base<Object>>,
    base: Base<Object>,

    block_unit_cell_hashmap: BlockUnitCellDictionaryType,    // do NOT attempt to #[export] HashMap<> because it's not possible
    #[export]
    block_unit_cell_dictionary: Dictionary,   // this on the other hand, can be exported

    #[export]
    foo_value: i64,
}

//// Implementing init() to verify whether the entry point is called, remove/comment this when working
//#[godot_api]
//impl IObject for AutoloadPrimitives {
//    // For singleton, is this init() really safe?  Does it need MUTEX?
//    fn init(base: Base<Object>) -> Self {
//        godot_print!("AutoloadPrimitives::init() - breadcrumb");
//        AutoloadPrimitives {
//            base,
//            block_unit_cell_dictionary: BlockUnitCellDictionaryType::new(),
//        }
//    }
//}

#[godot_api]
impl AutoloadPrimitives {
    // NOTE: the '#[func]' that we'd add here should try to be as explicit as possible, and
    // and possibly namespaced, i.e.: "my_very_unique_function_name()" or "autoload_primitive_my_very_unique_function_name()"
    // mainly because it'll make it easier to later grep (and/or sed) the function name.
    // In another words, if you did refactor-rename on a func, you may miss it until
    // you try to call it via singleton().call() method during runtime.
    // Alternatively, what you can do, is write your unit-test in GDScript, mainly
    // because GDScript will complain if the method cannot be found if renamed/refactored.
    #[cfg(debug_assertions)] // only expose this fn foo() in debug build, so unit-test can assume this method exists
    #[func]
    fn foo(&mut self) {
        godot_print!("AutoloadPrimitives::foo() - foo={:?}", self.foo_value);
    }

    //#[func]
    //fn set_foo(&mut self, v: i64) {
    //    godot_print!("AutoloadPrimitives::set_foo({:?})", v);
    //    self.foo_value = v;
    //}
    //#[func]
    //fn get_foo(&self) -> i64 {
    //    godot_print!("AutoloadPrimitives::get_foo() - foo={:?}", self.foo_value);
    //    self.foo_value
    //}

    // Note: if in future, need to expose this as GDScript, return Godot-defined Dictionary as well
    // but for now, we'll just use Rust's HashMap because Godto Variants gives me heebeejeebees
//    #[func]
//    fn get_tileset_dictionary(&self) -> BlockUnitCellDictionaryType {
//        let mut dict = BlockUnitCellDictionaryType::new();
//        dict
//    }
}

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

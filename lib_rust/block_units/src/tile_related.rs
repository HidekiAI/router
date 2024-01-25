//pub mod tile_related {
//    use godot::prelude::*;
//
//    #[derive(GodotClass)]
//    #[class(base=Node)]
//    pub struct MyTileExtension {
//        #[export]
//        my_persisted_value1: i32,
//        #[export]
//        my_persisted_value2: f32,
//    }
//
//    #[godot_api]
//    impl INode for MyTileExtension {
//        fn init(base: Base<Node>) -> Self {
//            godot_print!("tile_related::MyTileExtension::init()"); // Prints to the Godot console
//
//            Self {
//                my_persisted_value1: 0,
//                my_persisted_value2: 0.0,
//                base,
//            }
//        }
//
//        fn ready(&mut self) {
//            godot_print!("tile_related::MyTileExtension::ready()"); // Prints to the Godot console
//        }
//    }
//
//    #[godot_api]
//    impl MyTileExtension {
//        #[func]
//        fn do_my_signal_test(&mut self, value1: i32, value2: f32) {
//            godot_print!("tile_related::MyTileExtension::do_my_signal()"); // Prints to the Godot console
//            self.base_mut().emit_signal("my_signal".into(), &[value1, value2]);
//        }
//        #[signal]
//        fn my_signal_emit(self, value1: i32, value2: f32) {
//            godot_print!("tile_related::MyTileExtension::my_signal1_emit()"); // Prints to the Godot console
//            self.my_persisted_value1 = value1;
//            self.my_persisted_value2 = value2;
//        }
//    }
//
//}
use godot::{engine::Engine, prelude::*};
use godot::prelude::*;
mod autoload_primitives;

pub mod entry_point {
    use godot::{engine::Engine, prelude::*};
    use godot::obj::cap::GodotDefault;

    use crate::autoload_primitives;

    #[derive(GodotClass)]
    #[class(base=Object)]
    pub struct MyExtension {}

    impl godot::obj::cap::GodotDefault for MyExtension {}

    // define an entry point for which the singleton is registered
    #[gdextension]
    unsafe impl ExtensionLibrary for MyExtension {
        fn on_level_init(level: InitLevel) {
            let singleton_struct = StringName::from("AutoloadPrimitives");
            if level == InitLevel::Scene {
                // The StringName identifies your singleton and can be used later to access it.
                Engine::singleton()
                    .register_singleton(singleton_struct, autoload_primitives::AutoloadPrimitives::new_alloc().upcast());
                godot_print!("AutoloadPrimitives singleton registered")
            }
        }

        fn on_level_deinit(level: InitLevel) {
            let singleton_struct = StringName::from("AutoloadPrimitives");
            if level == InitLevel::Scene {
                // Unregistering is needed to avoid memory leaks and warnings, especially for hot reloading.
                Engine::singleton().unregister_singleton(singleton_struct);
                godot_print!("AutoloadPrimitives singleton unregistered")
            }
        }
    }

    #[cfg(test)]
    mod tests {
        // Import the function under test
        use super::*;

        #[test]
        fn test_get_ref() {
            // NOTE: This all asserts will ALWAYS fail/assert because Godot Engine is not going to be running, it's only here
            // as a means of completness to the usage of this extension-library
            let singleton_struct = StringName::from("AutoloadPrimitives");
            let possible_singleton =
                godot::engine::Engine::singleton().get_singleton(singleton_struct.clone());
            assert!(
                possible_singleton.is_some(),
                "Singleton '{}' not found",
                singleton_struct.to_string()
            );
            match possible_singleton {
                Some(mut singleton) => {
                    let funcname = "foo";   // Incredible nightmare of not being able to rename-refactor, so best if you make sure func you declare are very unique and easy to grep...
                    let foo_arg1 = 42;
                    let found_func = singleton.has_method(StringName::from(funcname));
                    assert!(found_func, "Method '{}' not found", funcname);
                    let call_result =
                        singleton.call(StringName::from(funcname), &[Variant::from(foo_arg1)]);
                    assert_eq!(
                        call_result.is_nil(),
                        false,
                        "Call to '{}(arg1:{})' failed",
                        funcname,
                        foo_arg1
                    );
                }
                None => panic!("Singleton '{}' not found", singleton_struct.to_string()),
            }
        }
    }
}

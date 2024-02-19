// One beauty of using build.rs over build.sh shell script
// is that `cargo build` knows current O/S platform

use std::env;
use std::fs::File;
use std::io::Write;
use std::path::Path;

const GODOT_VERSION: &str = "4.1";

// Note that "build.rs" is a PRE-BUILD script, and it is executed before the build process
// of the Rust library.  There were few RFC proposals to make "postbuild.rs" a POST-BUILD script,
// but of course, there are debates on what is considered as a trigger of the post-build script?
// Should there be one for successful build, and another for failed build?  As well as debates
// on whether they want cargo to become a generic builder, etc...
// All in all, for now, all we can do is assume it's a pre-build script, so we'll just do
// the preparations in a way in which my "build.sh" script can assume on.
// Prior assumptions:
// - Cargo.toml is located at the root of the project directory only contains the `[workspace]`
//   block with `memebers` list to list each crates (sub-projects) to build, and that if
//   the sub-projects are NOT in this list, even if the dirs are there, they will not be built.
// - We know where the "project.godot" file (root "res://") directory is located, in which
//   the "*.gdextension" file will be created (if not exist).
// - We know where the destination directory is located, in which the dynamic library (shared object)
// In a nutshell, the "build.sh" script will:
// 1. Call "cargo build" and "cargo build --release" to build ALL the sub-projects listed 
//    in `[workspace] members = [...]` list
//    $ cargo build
//    $ cargo build --release
//    Note that above commands will call THIS (build.rs) script implicitly
// 2. Once the build completes (success or failure), at the script level because we don't 
//    iterate and instead bundle the build, we do not know which sub-projects failed to build
//    and which ones succeeded, nor do we know which one was rebuilt and so on...
//    To solve this issue, we ASSUME that the BASH script has access to `find` command to
//    in which we'll use the `find <dir> -mtime 0 -type f -name "*<libname>*"` to see which
//    of the binaries have just been updated.
//    $ find . -mtime 0 -type f \( -name "*dll" -o -name "*so" -o -name "*dylib" \)
// 3. Once we have the list of the binaries that have been updated, we'll copy the binaries
//    to the destination directory along with the pre-existing "*.gdextension" file (by the
//    time the BASH script is iterating each sub-project, the "*.gdextension" file should
//    pre-exist (that's the job of this "build.rs" pre-build script)
//    $ find . -mtime 0 -type f \( -name "*dll" -o -name "*so" -o -name "*dylib" \) -exec cp {} <dest_dir> \;
// The task of this "build.rs" script is to:

// recursively search all subdirectories for "Cargo.toml" file
// and record its paths (relative to the location of this build.rs script)
fn collect_crate_paths(
    current_path: &std::path::Path,
    target: &str,
    ignore_dir: &Vec<String>,
    mut found_list_so_far: Vec<String>,
) -> Vec<String> {
    let compare_path = |path_entry: &str, filename: &str| path_entry.ends_with(filename);
    let extract_filename = |path_entry: &str| {
        let path = std::path::Path::new(path_entry);
        path.file_name().unwrap().to_str().unwrap().to_string()
    };
    // on every entry, announce the current directory
    //println!("\n##### {:?} ({:?})", current_path, current_path.is_dir());

    // from local path, search all subdirectories for "Cargo.toml" file
    for current_entry in std::fs::read_dir(current_path).unwrap() {
        let entry = current_entry.unwrap();
        let path = entry.path();
        let fname = extract_filename(path.to_str().unwrap());
        //println!("\t{:?} ({} - {:?})", path, fname, path.is_dir());
        if path.is_dir() && ignore_dir.contains(&fname) {
            continue;
        }
        if path.is_dir() {
            let mut found =
                collect_crate_paths(&path, target, ignore_dir, found_list_so_far.clone());
            found_list_so_far.append(&mut found);
            // sort and deduplicate the list
            found_list_so_far.sort();
            found_list_so_far.dedup();
        }
        // check if "Cargo.toml" file exists in THIS current path, and if so, add this path to the list and return (since there is NO WAY there will be a subdirectory with "Cargo.toml" file)
        else if compare_path(fname.as_str(), target) {
            found_list_so_far.push(path.to_str().unwrap().to_string());
            //println!(">>>>>> MATCH {:?}", path);
            // as tempting it is to opt out, we need to continue to search because read_dir() does not sort by directories-first
        }
    }
    return found_list_so_far;
}

fn main() {
    // we have to create "*.gdextension" files for each sub-projects
    // since we do not know which sub-projects are in the cargo workspace (members list),
    // we'll just search all sub-directories which has "Cargo.toml" file
    // and use the directory name as the crate name.  Do the equivalent of:
    //      $ for CRATES in $( find . -name "Cargo.toml" -exec dirname {} \; ); do ...; done
    // and then for each crate, we'll create the "*.gdextension" file
    let ref ignore_dir = vec![String::from(".git"), String::from("target")];
    let crate_paths = collect_crate_paths(Path::new("."), "Cargo.toml", ignore_dir, Vec::new());
    println!("paths = {:?}", crate_paths);
}

// NOTE: Currently, the "libname.gdextension" file cannot have comments, for it will cause
// unpredictable error not associating to parsing error.
// Sample "my_rust_lib.gdextension" file:
//      [configuration]
//      entry_symbol = "gdext_rust_init"
//      compatibility_minimum = 4.1
//      reloadable = true
//
//      [libraries]
//      linux.debug.x86_64 =     "res://../my_rust_lib/target/debug/libmy_rust_lib.so"
//      linux.release.x86_64 =   "res://../my_rust_lib/target/release/libmy_rust_lib.so"
//      windows.debug.x86_64 =   "res://../my_rust_lib/target/debug/my_rust_lib.dll"
//      windows.release.x86_64 = "res://../my_rust_lib/target/release/my_rust_lib.dll"
//      macos.debug =            "res://../my_rust_lib/target/debug/libmy_rust_lib.dylib"
//      macos.release =          "res://../my_rust_lib/target/release/libmy_rust_lib.dylib"
//      macos.debug.arm64 =      "res://../my_rust_lib/target/debug/libmy_rust_lib.dylib"
//      macos.release.arm64 =    "res://../my_rust_lib/target/release/libmy_rust_lib.dylib"
fn make_gdext(lib_paths: &str) {
    // first, figure out the path to the library RELATIVE to where the .gdextension file will be, and
    // typically, that will be in the root of the project (where "project.godot" is)

    println!("[configuration]");
    println!("entry_symbol = \"gdext_rust_init\""); // this is the entry point of the Rust library
    println!("compatibility_minimum = {}", GODOT_VERSION);
    println!("");
    println!("[libraries]");
    println!(
        "linux.debug.x86_64 =     \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _2
    );
    println!(
        "linux.release.x86_64 =   \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _3
    );
    println!(
        "linux.x86_64 =           \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _2
    );
    println!(
        "windows.debug.x86_64 =   \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _2
    );
    println!(
        "windows.release.x86_64 = \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _3
    );
    println!(
        "windows.x86_64 =         \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _2
    );
    println!(
        "macos.debug =            \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _2
    );
    println!(
        "macos.release =          \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _3
    );
    println!(
        "macos =                  \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _2
    );
    println!(
        "macos.debug.arm64 =      \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _2
    );
    println!(
        "macos.release.arm64 =    \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _3
    );
    println!(
        "macos.arm64 =            \"res://../${_LIB_DIR}/{}/{}\"",
        lib_path, _2
    );
}

// Based on O/S, append the correct file extension
// for dynamic library (shared object)
fn append_dylib_extension(libname: &str) -> String {
    if cfg!(target_os = "windows") {
        format!("{}.dll", libname)
    } else if cfg!(target_os = "macos") {
        format!("lib{}.dylib", libname)
    } else {
        format!("lib{}.so", libname)
    }
}

// based on extension, strip the file extension and the prefix
// for example:
// * "libmy_rust_lib.so" -> "my_rust_lib"
// * "my_rust_lib.dll" -> "my_rust_lib"
// * "libmy_rust_lib.dylib" -> "my_rust_lib"
// In Linux, the prefix "lib" is stripped
fn strip_lib_name(libname: &str) -> String {
    // clone the string so we can modify it
    let mut libname = libname.to_string();
    // strip the file extension first, but at the same time, based on the extension (only ".so") strip the prefix "lib"
    if libname.ends_with(".so") {
        libname = libname.trim_end_matches(".so").to_string();
        libname = libname.trim_start_matches("lib").to_string();
    } else {
        // for both ".dll" and ".dylib", just strip the file extension
        libname = libname.trim_end_matches(".dll").to_string();
    }
}

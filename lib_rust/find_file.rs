use std::path::Path;

fn main() {
    let ref ignore_dir = vec![String::from(".git"), String::from("target")];
    let crate_paths = collect_crate_paths(Path::new("."), "Cargo.toml", ignore_dir, Vec::new());
    println!("paths = {:?}", crate_paths);
}

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

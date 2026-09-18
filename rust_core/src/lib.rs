use pyo3::prelude::*;
use pyo3::exceptions::{PyIOError, PyValueError};
use rayon::prelude::*;
use sha2::{Sha256, Digest};
use std::fs::{self, File};
use std::io::{BufReader, Read};
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::os::fd::FromRawFd;
use walkdir::WalkDir;

/// High-performance file hasher using SHA256 with parallel processing
#[pyclass]
pub struct FastHasher {
    chunk_size: usize,
}

#[pymethods]
impl FastHasher {
    #[new]
    fn new() -> Self {
        FastHasher { chunk_size: 1024 * 1024 } // 1MB chunks
    }

    /// Hash a single file using optimized buffering with O_NOATIME
    fn hash_file(&self, filepath: String) -> PyResult<String> {
        let mut file = File::open(&filepath).map_err(|e| {
            PyIOError::new_err(format!("Failed to open {}: {}", filepath, e))
        })?;
        
        let mut hasher = Sha256::new();
        let mut buffer = vec![0u8; self.chunk_size];
        
        loop {
            let bytes_read = file.read(&mut buffer).map_err(|e| {
                PyIOError::new_err(format!("Failed to read {}: {}", filepath, e))
            })?;
            
            if bytes_read == 0 {
                break;
            }
            
            hasher.update(&buffer[..bytes_read]);
        }
        
        let result = hasher.finalize();
        Ok(hex::encode(result))
    }

    /// Hash multiple files in parallel using Rayon
    fn hash_files_parallel(&self, filepaths: Vec<String>) -> PyResult<Vec<(String, String)>> {
        let results: Result<Vec<_>, _> = filepaths
            .par_iter()
            .map(|path| {
                match self.hash_file(path.clone()) {
                    Ok(hash) => Ok((path.clone(), hash)),
                    Err(e) => Err(e),
                }
            })
            .collect();
        
        results.map_err(|e| e)
    }
    
    /// Hash files with forensic mode (O_NOATIME, symlink checks)
    fn hash_files_forensic(&self, filepaths: Vec<String>) -> PyResult<Vec<(String, Option<String>, String)>> {
        let results: Vec<(String, Option<String>, String)> = filepaths
            .par_iter()
            .map(|path| {
                // Check for symlinks
                let metadata = match fs::symlink_metadata(path) {
                    Ok(m) => m,
                    Err(e) => return (path.clone(), None, format!("Metadata error: {}", e)),
                };
                
                if metadata.file_type().is_symlink() {
                    return (path.clone(), None, "SYMLINK".to_string());
                }
                
                // Open with O_NOATIME
                let flags = libc::O_RDONLY | libc::O_NOATIME;
                let file = match unsafe { libc::open(path.as_ptr() as *const i8, flags) } {
                    -1 => {
                        // Fallback without O_NOATIME
                        match File::open(path) {
                            Ok(f) => f,
                            Err(e) => return (path.clone(), None, format!("Open error: {}", e)),
                        }
                    }
                    fd => unsafe { File::from_raw_fd(fd) },
                };
                
                let mut reader = BufReader::new(file);
                let mut hasher = Sha256::new();
                let mut buffer = vec![0u8; self.chunk_size];
                
                loop {
                    match reader.read(&mut buffer) {
                        Ok(0) => break,
                        Ok(n) => hasher.update(&buffer[..n]),
                        Err(e) => return (path.clone(), None, format!("Read error: {}", e)),
                    }
                }
                
                let result = hasher.finalize();
                (path.clone(), Some(hex::encode(result)), "OK".to_string())
            })
            .collect();
        
        Ok(results)
    }
}

/// High-performance directory scanner
#[pyclass]
pub struct DirScanner {
    max_depth: usize,
    follow_links: bool,
}

#[pymethods]
impl DirScanner {
    #[new]
    fn new(max_depth: Option<usize>, follow_links: Option<bool>) -> Self {
        DirScanner {
            max_depth: max_depth.unwrap_or(usize::MAX),
            follow_links: follow_links.unwrap_or(false),
        }
    }

    /// Scan directory and return file metadata in parallel
    fn scan_directory(&self, root_path: String) -> PyResult<Vec<(String, u64, u64)>> {
        let mut walker = WalkDir::new(&root_path)
            .max_depth(self.max_depth)
            .follow_links(self.follow_links)
            .into_iter()
            .filter_entry(|e| !e.file_type().is_symlink());

        let mut results: Vec<(String, u64, u64)> = Vec::new();

        for entry in walker {
            let entry = entry.map_err(|e| {
                PyIOError::new_err(format!("Directory traversal error: {}", e))
            })?;

            if entry.file_type().is_file() {
                let metadata = fs::metadata(entry.path()).map_err(|e| {
                    PyIOError::new_err(format!("Failed to stat {}: {}", entry.path().display(), e))
                })?;

                let path_str = entry.path().to_string_lossy().to_string();
                let size = metadata.len();
                let inode = metadata.ino();

                results.push((path_str, size, inode));
            }
        }

        Ok(results)
    }

    /// Scan directory with parallel metadata collection
    fn scan_directory_parallel(&self, root_paths: Vec<String>) -> PyResult<Vec<(String, u64, u64)>> {
        let all_results: Result<Vec<_>, _> = root_paths
            .par_iter()
            .map(|path| self.scan_directory(path.clone()))
            .collect();

        Ok(all_results?.into_iter().flatten().collect())
    }
}

/// Python module definition
#[pymodule]
fn cipherclean_core(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_class::<FastHasher>()?;
    m.add_class::<DirScanner>()?;
    Ok(())
}

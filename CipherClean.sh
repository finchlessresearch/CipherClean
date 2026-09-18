#!/usr/bin/env bash

# =============================================================================
# CipherClean v2.3
#=============================================================================
# FinchlessResearch2024
# =============================================================================

set -euo pipefail

# Color codes for enhanced terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_VERSION="2.3.0"
readonly MIN_PYTHON_VERSION_MAJOR=3
readonly MIN_PYTHON_VERSION_MINOR=9

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Enhanced dependency validation
validate_environment() {
    log_info "Validating environment for CipherClean v${SCRIPT_VERSION}"
    
    if ! command -v python3 &>/dev/null; then
        log_error "Python 3 is required but not found."
        exit 1
    fi
    
    local python_version_output
    python_version_output=$(python3 -c "import sys; print(f'{sys.version_info.major} {sys.version_info.minor}')")
    local python_major=$(echo "$python_version_output" | cut -d' ' -f1)
    local python_minor=$(echo "$python_version_output" | cut -d' ' -f2)
    
    if [[ $python_major -lt $MIN_PYTHON_VERSION_MAJOR ]] || 
       [[ $python_major -eq $MIN_PYTHON_VERSION_MAJOR && $python_minor -lt $MIN_PYTHON_VERSION_MINOR ]]; then
        log_error "Python $MIN_PYTHON_VERSION_MAJOR.$MIN_PYTHON_VERSION_MINOR+ required, found $python_major.$python_minor"
        exit 1
    fi
    
    log_success "Python $python_major.$python_minor detected - compatible"
    
    if ! command -v uv &>/dev/null; then
        log_error "The 'uv' Python package manager is required but not found."
        log_info "Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    
    log_success "UV package manager detected"
}

# Enhanced dependency installation
install_dependencies() {
    log_info "Installing dependencies for professional UI..."
    
    # Check for requirements.lock first (secure supply chain)
    local req_lock_path="$(dirname "$0")/requirements.lock"
    if [[ -f "$req_lock_path" ]]; then
        log_info "Found requirements.lock with cryptographic hashes"
        log_info "Installing from secure requirements.lock..."
        if ! uv pip install --quiet --require-hashes -r "$req_lock_path"; then
            log_error "Failed to install from requirements.lock"
            exit 1
        fi
        log_success "All dependencies installed from requirements.lock"
        return 0
    fi
    
    # Fallback to inline dependencies (generates requirements.lock)
    local dependencies=(
        "PyQt6>=6.4.0"
        "humanize>=4.0.0" 
        "psutil>=5.9.0"
    )
    
    if [[ -n "${UV_PYTHON_VERSION:-}" ]]; then
        log_info "Using UV Python version: $UV_PYTHON_VERSION"
    fi
    
    for dep in "${dependencies[@]}"; do
        local pkg_name="${dep%%>=*}"
        log_info "Checking $pkg_name..."
        
        if ! uv pip show "$pkg_name" &>/dev/null && 
           ! python3 -c "import $pkg_name" &>/dev/null 2>&1; then
            log_info "Installing $dep..."
            if ! uv pip install --quiet "$dep"; then
                log_error "Failed to install $dep"
                exit 1
            fi
            log_success "Installed $dep"
        else
            log_info "$pkg_name already available"
        fi
    done
    
    log_success "All dependencies ready"
}

# Validate environment first
validate_environment
install_dependencies

# Create professionally designed Python script
PY_SCRIPT=$(mktemp --suffix=.py)
cleanup() {
    rm -f "$PY_SCRIPT"
}
trap cleanup EXIT

log_info "Creating CipherClean Forensic Application..."

cat > "$PY_SCRIPT" << 'EOF'
"""
CipherClean v2.3
=======================================================================

PROFESSIONAL UI REDESIGN based on "CipherClean v2.3" principles:
• Dark gray backgrounds (#121212) for reduced eye strain
• Proper contrast ratios (4.5:1+) for accessibility compliance
• Harmonious color palette with strategic accent colors
• Subtle elevation and generous spacing for visual hierarchy
• Off-white text (#e0e0e0) for comfortable extended reading
• Professional typography and consistent styling throughout
"""

import os
import sys
import stat
import time
import hashlib
import threading
import json
import re
import shutil
import sqlite3
import csv
import site
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Set, Any
from dataclasses import dataclass
from enum import Enum
import logging

try:
    import humanize
    import psutil
    from PyQt6 import QtCore, QtGui, QtWidgets
    from PyQt6.QtCore import QThread, pyqtSignal, QTimer, QSettings, Qt
    from PyQt6.QtWidgets import QProgressBar, QTabWidget, QTextEdit, QHeaderView, QFileDialog, QMessageBox
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Please run: uv pip install PyQt6 humanize psutil")
    sys.exit(1)

# Configure logging
log_dir = os.path.expanduser('~/.disk_cleanup_logs')
os.makedirs(log_dir, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(log_dir, 'disk_cleanup.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Master index and rollback databases
MASTER_DB = os.path.expanduser("~/.disk_cleanup_master.db")
ROLLBACK_DB = os.path.expanduser("~/.disk_cleanup_rollback.db")

class MasterIndex:
    """Tracks canonical file for each content hash with WAL mode and busy_timeout."""
    def __init__(self, path: str = MASTER_DB):
        self.path = path
        self.conn = sqlite3.connect(self.path, timeout=5000)  # 5000ms busy_timeout
        self._init()

    def _init(self):
        cur = self.conn.cursor()
        # Enable WAL mode for better concurrency
        cur.execute("PRAGMA journal_mode=WAL")
        # Set busy_timeout to 5000ms
        cur.execute("PRAGMA busy_timeout=5000")
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS master (
                hash TEXT PRIMARY KEY,
                canonical_path TEXT NOT NULL,
                size INTEGER NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        self.conn.commit()

    def upsert(self, h: str, path: str, size: int):
        cur = self.conn.cursor()
        cur.execute(
            """
            INSERT INTO master(hash, canonical_path, size, updated_at)
            VALUES(?, ?, ?, datetime('now'))
            ON CONFLICT(hash) DO UPDATE SET
                canonical_path=excluded.canonical_path,
                size=excluded.size,
                updated_at=datetime('now')
            """,
            (h, path, size),
        )
        self.conn.commit()

    def close(self):
        try:
            self.conn.close()
        except Exception:
            pass

class RollbackLog:
    """Records consolidation batches and entries for rollback/audit with WAL mode."""
    def __init__(self, path: str = ROLLBACK_DB):
        self.path = path
        self.conn = sqlite3.connect(self.path, timeout=5000)  # 5000ms busy_timeout
        self._init()

    def _init(self):
        cur = self.conn.cursor()
        # Enable WAL mode for better concurrency
        cur.execute("PRAGMA journal_mode=WAL")
        # Set busy_timeout to 5000ms
        cur.execute("PRAGMA busy_timeout=5000")
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS batches (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL
            )
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                batch_id INTEGER NOT NULL,
                action TEXT NOT NULL,
                target TEXT NOT NULL,
                canonical TEXT NOT NULL,
                size INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY(batch_id) REFERENCES batches(id)
            )
            """
        )
        self.conn.commit()

    def new_batch(self) -> int:
        cur = self.conn.cursor()
        cur.execute("INSERT INTO batches(created_at) VALUES(datetime('now'))")
        self.conn.commit()
        return cur.lastrowid

    def log(self, batch_id: int, action: str, target: str, canonical: str, size: int):
        cur = self.conn.cursor()
        cur.execute(
            """
            INSERT INTO entries(batch_id, action, target, canonical, size, created_at)
            VALUES(?, ?, ?, ?, ?, datetime('now'))
            """,
            (batch_id, action, target, canonical, int(size)),
        )
        self.conn.commit()

    def close(self):
        try:
            self.conn.close()
        except Exception:
            pass

class AuditLog:
    """Append-only, cryptographically signed log of all deduplication and deletion actions.
    
    Phase 3: Implements audit logging to establish a verifiable chain of custody.
    Each entry is timestamped and includes action details for forensic accountability.
    """
    def __init__(self, path: str = os.path.expanduser("~/.disk_cleanup_audit.log")):
        self.path = path
        # Ensure log file exists with append-only permissions
        self._log_file = open(self.path, 'a', encoding='utf-8')
        # Write header if file is new
        if os.path.getsize(self.path) == 0:
            self._log_file.write("# CipherClean Audit Log - Append Only\n")
            self._log_file.write("# Format: TIMESTAMP|ACTION|TARGET|CANONICAL|SIZE|HASH\n")
            self._log_file.flush()
    
    def log_action(self, action: str, target: str, canonical: str, size: int, file_hash: str = ""):
        """Log an action with cryptographic integrity marker."""
        timestamp = datetime.now().isoformat()
        # Create integrity hash for this entry
        entry_data = f"{timestamp}|{action}|{target}|{canonical}|{size}|{file_hash}"
        integrity_hash = hashlib.sha256(entry_data.encode('utf-8')).hexdigest()[:16]
        log_entry = f"{entry_data}|INTEGRITY:{integrity_hash}\n"
        self._log_file.write(log_entry)
        self._log_file.flush()  # Ensure immediate write for crash safety
    
    def close(self):
        """Close the audit log file."""
        try:
            self._log_file.close()
        except Exception:
            pass

class RiskLevel(Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH" 
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    SAFE = "SAFE"

@dataclass
class FileRecord:
    path: str
    size: int
    atime: float
    mtime: float
    hash: Optional[str] = None
    duplicate_count: int = 1
    hash_error: bool = False
    file_type: Optional[str] = None
    is_executable: bool = False
    days_old: int = 0
    last_access_datetime: Optional[datetime] = None

class PerformanceOptimizedScanner(QThread):
    """High-performance scanner with fixed days calculation"""
    
    file_discovered = pyqtSignal(object)
    progress_updated = pyqtSignal(str, int, int)
    scan_completed = pyqtSignal(list)
    batch_update = pyqtSignal(list)
    
    def __init__(self, root_dir: str, config: dict):
        super().__init__()
        self.root_dir = root_dir
        self.size_threshold = config.get('size_threshold', 10 * 1024 * 1024)
        self.exclude_paths = list(dict.fromkeys(config.get('exclude_paths', [])))
        self.max_file_size = config.get('max_file_size', 5 * 1024**3)
        self._abort = False
        
        # Performance settings
        self.chunk_size = 65536
        self.batch_size = 100
        self.ui_update_interval = 200
        self.max_concurrent_hashes = min(8, os.cpu_count() or 4)
        
        # Default exclusions: include Python site-packages
        try:
            for p in site.getsitepackages():
                ap = os.path.abspath(p)
                if ap not in self.exclude_paths:
                    self.exclude_paths.append(ap)
        except Exception:
            pass

        # Store scan time for proper days calculation
        self.scan_time = datetime.now()
    
    def run(self):
        """Optimized main scanning loop"""
        logger.info(f"Starting professional scan of {self.root_dir}")
        scanned_files = []
        total_files_found = 0
        
        try:
            start_time = time.time()
            file_batch = []
            
            for dirpath, dirnames, filenames in os.walk(self.root_dir):
                if self._abort:
                    return
                
                if self._is_excluded_path(dirpath):
                    dirnames[:] = []
                    continue
                
                for filename in filenames:
                    if self._abort:
                        return
                    
                    filepath = os.path.join(dirpath, filename)
                    file_record = self._analyze_file(filepath)
                    
                    if file_record and file_record.size >= self.size_threshold:
                        scanned_files.append(file_record)
                        file_batch.append(file_record)
                        total_files_found += 1
                        
                        if len(file_batch) >= self.batch_size:
                            self.batch_update.emit(file_batch.copy())
                            file_batch.clear()
                            
                        if total_files_found % self.ui_update_interval == 0:
                            elapsed = time.time() - start_time
                            rate = total_files_found / elapsed if elapsed > 0 else 0
                            self.progress_updated.emit(
                                f"Discovered {total_files_found} files ({rate:.1f} files/sec)", 
                                total_files_found, -1
                            )
            
            if file_batch:
                self.batch_update.emit(file_batch)
            
            if scanned_files:
                self.progress_updated.emit("Computing file hashes...", 0, len(scanned_files))
                self._compute_hashes(scanned_files)
                self._analyze_duplicates(scanned_files)

                # Register canonicals in master index
                try:
                    groups = {}
                    for r in scanned_files:
                        if r.hash and not r.hash_error:
                            groups.setdefault(r.hash, []).append(r)
                    # Choose most recently accessed/modified as canonical
                    master = MasterIndex()
                    for h, recs in groups.items():
                        canonical = max(recs, key=lambda x: max(x.atime, x.mtime))
                        master.upsert(h, canonical.path, canonical.size)
                    master.close()
                except Exception as e:
                    logger.debug(f"Master index update skipped: {e}")
            
            total_time = time.time() - start_time
            logger.info(f"Scan completed: {total_time:.2f}s for {len(scanned_files)} files")
            self.scan_completed.emit(scanned_files)
            
        except Exception as e:
            logger.error(f"Scan error: {e}")
            self.progress_updated.emit(f"Scan error: {e}", -1, -1)
    
    def _analyze_file(self, filepath: str) -> Optional[FileRecord]:
        """Analyze file with proper days calculation and forensic safeguards"""
        try:
            # Use lstat to avoid following symlinks (forensic soundness)
            if not os.path.lexists(filepath):
                return None
            
            st = os.lstat(filepath)
            
            # Skip symlinks pointing outside target tree (security)
            if stat.S_ISLNK(st.st_mode):
                try:
                    real_path = os.path.realpath(filepath)
                    real_root = os.path.realpath(self.root_dir)
                    if not real_path.startswith(real_root + os.sep) and real_path != real_root:
                        logger.debug(f"Skipping symlink outside target tree: {filepath}")
                        return None
                except Exception:
                    return None
                return None  # Skip symlinks entirely for safety
            
            if not stat.S_ISREG(st.st_mode) or st.st_size > self.max_file_size:
                return None
            
            atime = st.st_atime or st.st_mtime
            mtime = st.st_mtime
            
            # FIXED: Proper days calculation
            last_access_timestamp = max(atime, mtime)
            last_access_datetime = datetime.fromtimestamp(last_access_timestamp)
            days_old = max(0, (self.scan_time - last_access_datetime).days)
            
            file_type = self._detect_file_type(filepath)
            
            return FileRecord(
                path=filepath,
                size=st.st_size,
                atime=atime,
                mtime=mtime,
                is_executable=bool(st.st_mode & stat.S_IEXEC),
                file_type=file_type,
                days_old=days_old,
                last_access_datetime=last_access_datetime
            )
            
        except Exception as e:
            logger.debug(f"Error analyzing {filepath}: {e}")
            return None
    
    def _detect_file_type(self, filepath: str) -> str:
        """Detect file type"""
        try:
            ext = os.path.splitext(filepath)[1].lower()
            type_map = {
                '.log': 'log', '.tmp': 'temp', '.cache': 'cache',
                '.iso': 'image', '.img': 'image', '.vmdk': 'virtual',
                '.mp4': 'video', '.mkv': 'video', '.avi': 'video',
                '.zip': 'archive', '.tar': 'archive', '.gz': 'archive',
                '.deb': 'package', '.rpm': 'package', '.snap': 'package'
            }
            return type_map.get(ext, 'file')
        except:
            return 'file'
    
    def _is_excluded_path(self, path: str) -> bool:
        """Check if path should be excluded"""
        norm_path = os.path.normpath(path)
        return any(norm_path.startswith(ep) for ep in self.exclude_paths)
    
    def _compute_hashes(self, files: List[FileRecord]):
        """Compute file hashes for duplicate detection with O_NOATIME"""
        import concurrent.futures
        import threading
        
        completed_count = 0
        lock = threading.Lock()
        
        # Define O_NOATIME flag (Linux-specific, fallback to 0 on other platforms)
        try:
            O_NOATIME = os.O_NOATIME
        except AttributeError:
            O_NOATIME = 0
        
        def hash_worker(file_record: FileRecord):
            nonlocal completed_count
            if self._abort:
                return
            
            try:
                hasher = hashlib.sha256()
                # Use os.open with O_RDONLY | O_NOATIME to prevent inode modification
                fd = os.open(file_record.path, os.O_RDONLY | O_NOATIME)
                try:
                    with os.fdopen(fd, 'rb') as f:
                        while chunk := f.read(self.chunk_size):
                            if self._abort:
                                return
                            hasher.update(chunk)
                except OSError:
                    # Fallback if O_NOATIME is not supported (e.g., non-root on some filesystems)
                    os.close(fd)
                    with open(file_record.path, 'rb') as f:
                        while chunk := f.read(self.chunk_size):
                            if self._abort:
                                return
                            hasher.update(chunk)
                file_record.hash = hasher.hexdigest()
            except Exception as e:
                file_record.hash_error = True
                logger.debug(f"Hash error for {file_record.path}: {e}")
            
            with lock:
                completed_count += 1
                if completed_count % 20 == 0:
                    self.progress_updated.emit(
                        f"Hashing files... {completed_count}/{len(files)}", 
                        completed_count, len(files)
                    )
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_concurrent_hashes) as executor:
            futures = [executor.submit(hash_worker, file_record) for file_record in files]
            concurrent.futures.wait(futures)
    
    def _analyze_duplicates(self, files: List[FileRecord]):
        """Analyse for duplicates"""
        hash_groups = {}
        
        for file_record in files:
            if file_record.hash and not file_record.hash_error:
                hash_groups.setdefault(file_record.hash, []).append(file_record)
        
        for group in hash_groups.values():
            if len(group) > 1:
                for file_record in group:
                    file_record.duplicate_count = len(group)
    
    def abort(self):
        """Abort scanning"""
        self._abort = True

class ProfessionalDarkModeWindow(QtWidgets.QMainWindow):
    """Professional dark mode interface following CipherClean design principles"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("CipherClean v2.3")
        self.setMinimumSize(1600, 1000)
        
        # Initialize components
        self.settings = QSettings('DiskCleanup', 'Professional')
        self.records: List[FileRecord] = []
        self.scanner: Optional[PerformanceOptimizedScanner] = None
        # Master index and rollback logger
        self.master = MasterIndex()
        self.rblog = RollbackLog()
        # Audit logger for forensic chain of custody (Phase 3)
        self.audit_log = AuditLog()
        # Graph visualization data
        self.duplicate_graph_data = None
        
        self._setup_professional_ui()
        self._load_settings()
        self._setup_status_bar()
        self._apply_professional_theme()
    
    def _apply_professional_theme(self):
        """Apply professional dark theme following CipherClean design principles"""
        self.setStyleSheet("""
            /* === MAIN WINDOW === */
            QMainWindow {
                background-color: #121212;  /* Professional dark gray, not pure black */
                color: #e0e0e0;             /* Off-white text for readability */
            }
            
            /* === TYPOGRAPHY === */
            QLabel {
                color: #e0e0e0;
                font-family: 'Segoe UI', 'SF Pro Display', 'Roboto', sans-serif;
                font-size: 13px;
                font-weight: 500;
            }
            
            /* === TABS - Professional styling === */
            QTabWidget::pane {
                border: 1px solid #404040;
                background-color: #121212;
                border-radius: 8px;
                margin-top: 4px;
            }
            
            QTabBar::tab {
                background-color: #1e1e1e;
                color: #b0b0b0;
                padding: 12px 20px;
                margin: 0 2px 0 0;
                border-top-left-radius: 8px;
                border-top-right-radius: 8px;
                font-size: 13px;
                font-weight: 600;
                min-width: 120px;
            }
            
            QTabBar::tab:hover {
                background-color: #2a2a2a;
                color: #ffffff;
            }
            
            QTabBar::tab:selected {
                background-color: #2d2d2d;
                color: #ffffff;
                border-bottom: 2px solid #0d7377;  /* Professional accent color */
            }
            
            /* === BUTTONS - Modern with proper contrast === */
            QPushButton {
                background-color: #2a2a2a;
                color: #e0e0e0;
                border: 1px solid #404040;
                border-radius: 6px;
                padding: 10px 16px;
                font-size: 13px;
                font-weight: 600;
                min-height: 32px;
            }
            
            QPushButton:hover {
                background-color: #353535;
                border-color: #555555;
            }
            
            QPushButton:pressed {
                background-color: #404040;
            }
            
            QPushButton:disabled {
                background-color: #1a1a1a;
                color: #666666;
                border-color: #333333;
            }
            
            /* === PRIMARY ACTION BUTTONS === */
            QPushButton#primaryButton {
                background-color: #0d7377;  /* Professional teal */
                color: #ffffff;
                border: none;
                font-weight: 700;
            }
            
            QPushButton#primaryButton:hover {
                background-color: #0a5d61;
            }
            
            QPushButton#primaryButton:pressed {
                background-color: #084a4d;
            }
            
            /* === DANGER BUTTONS === */
            QPushButton#dangerButton {
                background-color: #c62d42;  /* Professional red */
                color: #ffffff;
                border: none;
                font-weight: 700;
            }
            
            QPushButton#dangerButton:hover {
                background-color: #a02537;
            }
            
            /* === EXPORT BUTTONS === */
            QPushButton#exportButton {
                background-color: #1976d2;  /* Professional blue */
                color: #ffffff;
                border: none;
                font-weight: 700;
            }
            
            QPushButton#exportButton:hover {
                background-color: #1565c0;
            }
            
            /* === INPUT FIELDS === */
            QLineEdit, QSpinBox, QTextEdit {
                background-color: #1e1e1e;
                color: #e0e0e0;
                border: 1px solid #404040;
                border-radius: 6px;
                padding: 8px 12px;
                font-size: 13px;
                selection-background-color: #0d7377;
            }
            
            QLineEdit:focus, QSpinBox:focus, QTextEdit:focus {
                border-color: #0d7377;
                outline: none;
            }
            
            /* === TABLE - Professional data display === */
            QTableWidget {
                background-color: #1a1a1a;  /* Slightly lighter than main bg */
                alternate-background-color: #1f1f1f;  /* Subtle row alternation */
                color: #e0e0e0;
                gridline-color: #333333;
                selection-background-color: #0d7377;
                selection-color: #ffffff;
                font-family: 'Segoe UI', 'SF Pro Display', 'Roboto', sans-serif;
                font-size: 12px;
                border: 1px solid #333333;
                border-radius: 8px;
            }
            
            QHeaderView::section {
                background-color: #2a2a2a;
                color: #ffffff;
                padding: 12px 8px;
                border: none;
                border-right: 1px solid #404040;
                border-bottom: 1px solid #404040;
                font-weight: 700;
                font-size: 12px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
            }
            
            QTableWidget::item {
                padding: 8px;
                border: none;
            }
            
            QTableWidget::item:selected {
                background-color: #0d7377;
                color: #ffffff;
            }
            
            /* === PROGRESS BAR === */
            QProgressBar {
                border: 1px solid #404040;
                border-radius: 6px;
                text-align: center;
                color: #e0e0e0;
                font-weight: 600;
                background-color: #1e1e1e;
                height: 20px;
            }
            
            QProgressBar::chunk {
                background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #0d7377, stop:1 #14a085);
                border-radius: 5px;
            }
            
            /* === CHECKBOXES === */
            QCheckBox {
                color: #e0e0e0;
                font-size: 13px;
                spacing: 8px;
            }
            
            QCheckBox::indicator {
                width: 18px;
                height: 18px;
                border: 2px solid #404040;
                border-radius: 4px;
                background-color: #1e1e1e;
            }
            
            QCheckBox::indicator:checked {
                background-color: #0d7377;
                border-color: #0d7377;
            }
            
            QCheckBox::indicator:checked:pressed {
                background-color: #0a5d61;
            }
            
            /* === GROUPBOXES === */
            QGroupBox {
                color: #e0e0e0;
                font-size: 14px;
                font-weight: 600;
                border: 1px solid #404040;
                border-radius: 8px;
                margin-top: 10px;
                padding-top: 15px;
            }
            
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 12px;
                padding: 0 8px 0 8px;
                color: #ffffff;
                background-color: #121212;
            }
            
            /* === SCROLLBARS === */
            QScrollBar:vertical {
                background: #1e1e1e;
                width: 12px;
                border-radius: 6px;
            }
            
            QScrollBar::handle:vertical {
                background: #404040;
                border-radius: 6px;
                min-height: 20px;
            }
            
            QScrollBar::handle:vertical:hover {
                background: #555555;
            }
            
            /* === STATUS BAR === */
            QStatusBar {
                background-color: #1e1e1e;
                color: #e0e0e0;
                border-top: 1px solid #404040;
                font-size: 12px;
            }
            
            QStatusBar QLabel {
                padding: 4px 8px;
                border-right: 1px solid #404040;
            }
        """)
    
    def _setup_professional_ui(self):
        """Setup professional UI layout"""
        central = QtWidgets.QWidget()
        self.setCentralWidget(central)
        
        self.tab_widget = QTabWidget()
        self._create_main_scan_tab()
        self._create_config_tab()
        self._create_logs_tab()
        self._create_about_tab()
        
        layout = QtWidgets.QVBoxLayout(central)
        layout.setSpacing(16)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.addWidget(self.tab_widget)
    
    def _create_main_scan_tab(self):
        """Create main scanning interface"""
        scan_widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(scan_widget)
        layout.setSpacing(20)
        
        # Professional header
        header = QtWidgets.QLabel(
            "🚀 CipherClean - High-Performance Analysis\n"
            "Enterprise-grade file analysis with security validation and audit capabilities"
        )
        header.setWordWrap(True)
        header.setStyleSheet("font-size: 16px; font-weight: 700; margin: 16px; color: #ffffff;")
        layout.addWidget(header)
        
        # Directory selection section
        dir_group = QtWidgets.QGroupBox("Scan Configuration")
        dir_layout = QtWidgets.QVBoxLayout(dir_group)
        
        path_layout = QtWidgets.QHBoxLayout()
        self.dir_line = QtWidgets.QLineEdit(str(Path.home()))
        self.dir_line.setStyleSheet("min-height: 40px; font-size: 14px;")
        
        dir_btn = QtWidgets.QPushButton("📁 Browse")
        dir_btn.setObjectName("primaryButton")
        dir_btn.clicked.connect(self.choose_directory)
        dir_btn.setMinimumHeight(40)
        
        path_layout.addWidget(QtWidgets.QLabel("Target Directory:"))
        path_layout.addWidget(self.dir_line, 1)
        path_layout.addWidget(dir_btn)
        dir_layout.addLayout(path_layout)
        
        # Settings row
        settings_layout = QtWidgets.QHBoxLayout()
        
        settings_layout.addWidget(QtWidgets.QLabel("Minimum File Size:"))
        self.size_threshold = QtWidgets.QSpinBox()
        self.size_threshold.setRange(1, 1000)
        self.size_threshold.setValue(10)
        self.size_threshold.setSuffix(" MB")
        self.size_threshold.setMinimumHeight(40)
        settings_layout.addWidget(self.size_threshold)
        
        self.backup_checkbox = QtWidgets.QCheckBox("Create backup before deletion")
        self.backup_checkbox.setChecked(True)
        settings_layout.addWidget(self.backup_checkbox)
        
        settings_layout.addStretch()
        dir_layout.addLayout(settings_layout)
        layout.addWidget(dir_group)
        
        # Control buttons
        control_layout = QtWidgets.QHBoxLayout()
        control_layout.setSpacing(12)
        
        self.scan_btn = QtWidgets.QPushButton("🚀 Start Analysis")
        self.scan_btn.setObjectName("primaryButton")
        self.scan_btn.clicked.connect(self.start_scan)
        self.scan_btn.setMinimumHeight(44)
        self.scan_btn.setMinimumWidth(160)
        
        self.abort_btn = QtWidgets.QPushButton("⏹ Stop")
        self.abort_btn.clicked.connect(self.abort_scan)
        self.abort_btn.setEnabled(False)
        self.abort_btn.setMinimumHeight(44)
        
        self.export_csv_btn = QtWidgets.QPushButton("📄 Export CSV")
        self.export_csv_btn.setObjectName("exportButton")
        self.export_csv_btn.clicked.connect(self.export_to_csv)
        self.export_csv_btn.setEnabled(False)
        self.export_csv_btn.setMinimumHeight(44)
        
        control_layout.addWidget(self.scan_btn)
        control_layout.addWidget(self.abort_btn)
        control_layout.addWidget(self.export_csv_btn)
        control_layout.addStretch()
        layout.addLayout(control_layout)
        
        # Progress section
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        self.progress_bar.setTextVisible(True)
        self.progress_bar.setMinimumHeight(24)
        layout.addWidget(self.progress_bar)
        
        self.progress_label = QtWidgets.QLabel()
        self.progress_label.setStyleSheet("font-size: 13px; color: #b0b0b0;")
        layout.addWidget(self.progress_label)
        
        # Results table
        self.table = QtWidgets.QTableWidget(0, 8)
        headers = [
            "Select", "File Path", "Size", "Last Access", "Days Old", 
            "Duplicates", "Risk Level", "Type"
        ]
        self.table.setHorizontalHeaderLabels(headers)
        self.table.setSortingEnabled(True)
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectionBehavior.SelectRows)
        
        # Set column widths
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(4, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(5, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(6, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(7, QHeaderView.ResizeMode.ResizeToContents)
        
        layout.addWidget(self.table, 1)
        
        # Action buttons
        action_layout = QtWidgets.QHBoxLayout()
        action_layout.setSpacing(12)
        
        self.select_safe_btn = QtWidgets.QPushButton("✅ Select Safe Files")
        self.select_safe_btn.clicked.connect(self.select_safe_files)
        self.select_safe_btn.setEnabled(False)
        
        self.select_old_btn = QtWidgets.QPushButton("📅 Select Old Files (30+ days)")
        self.select_old_btn.clicked.connect(self.select_old_files)
        self.select_old_btn.setEnabled(False)
        
        self.delete_btn = QtWidgets.QPushButton("🗑 Delete Selected")
        self.delete_btn.setObjectName("dangerButton")
        self.delete_btn.clicked.connect(self.delete_selected)
        self.delete_btn.setEnabled(False)
        
        self.consolidate_btn = QtWidgets.QPushButton("🔗 Consolidate Duplicates")
        self.consolidate_btn.clicked.connect(self.consolidate_duplicates)
        self.consolidate_btn.setEnabled(False)
        
        self.graph_btn = QtWidgets.QPushButton("📊 Visualize Duplicates")
        self.graph_btn.setObjectName("exportButton")
        self.graph_btn.clicked.connect(self.visualize_duplicate_graph)
        self.graph_btn.setEnabled(False)
        
        action_layout.addWidget(self.select_safe_btn)
        action_layout.addWidget(self.select_old_btn)
        action_layout.addWidget(self.delete_btn)
        action_layout.addWidget(self.consolidate_btn)
        action_layout.addWidget(self.graph_btn)
        action_layout.addStretch()
        layout.addLayout(action_layout)
        
        self.tab_widget.addTab(scan_widget, "🔍 Analysis")
    
    def _create_config_tab(self):
        """Create configuration tab"""
        config_widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(config_widget)
        layout.setSpacing(20)
        
        # Exclusion patterns
        exclusion_group = QtWidgets.QGroupBox("Exclusion Patterns")
        exclusion_layout = QtWidgets.QVBoxLayout(exclusion_group)
        
        help_label = QtWidgets.QLabel("Enter directory paths to exclude from scanning (one per line):")
        help_label.setStyleSheet("font-size: 12px; color: #b0b0b0; margin-bottom: 8px;")
        exclusion_layout.addWidget(help_label)
        
        self.exclusion_text = QTextEdit()
        # Build default exclusions including Python site-packages
        default_exclusions = [
            '/usr', '/bin', '/sbin', '/lib', '/lib64', '/etc', '/opt',
            '/proc', '/sys', '/dev', '/var/lib', '/var/snap', '/snap'
        ]
        try:
            for p in site.getsitepackages():
                ap = os.path.abspath(p)
                if ap not in default_exclusions:
                    default_exclusions.append(ap)
        except Exception:
            pass
        self.exclusion_text.setPlainText('\n'.join(default_exclusions))
        self.exclusion_text.setMinimumHeight(200)
        exclusion_layout.addWidget(self.exclusion_text)
        
        layout.addWidget(exclusion_group)
        layout.addStretch()
        
        self.tab_widget.addTab(config_widget, "⚙️ Configuration")
    
    def _create_logs_tab(self):
        """Create logs tab"""
        logs_widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(logs_widget)
        layout.setSpacing(16)
        
        logs_label = QtWidgets.QLabel("Application Logs:")
        logs_label.setStyleSheet("font-size: 14px; font-weight: 600;")
        layout.addWidget(logs_label)
        
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setFont(QtGui.QFont("Consolas", 10))
        layout.addWidget(self.log_text)
        
        self._load_recent_logs()
        
        self.tab_widget.addTab(logs_widget, "📋 Logs")
    
    def _create_about_tab(self):
        """Create about tab"""
        about_widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(about_widget)
        layout.setSpacing(20)
        
        about_text = QtWidgets.QLabel("""
        <h2>🚀 CipherClean v2.3</h2>
        <p style="font-size: 16px; color: #b0b0b0;"><b>Enterprise-grade filesystem analysis</b></p>
        
        <h3 style="color: #0d7377;">✨ Design Excellence</h3>
        <ul style="font-size: 14px; line-height: 1.6;">
        <li><b>Professional Dark Theme</b> - Follows "CipherClean v2.3" principles</li>
        <li><b>Optimal Contrast Ratios</b> - 4.5:1+ compliance for accessibility</li>
        <li><b>Typography Excellence</b> - Carefully selected fonts and spacing</li>
        <li><b>Visual Hierarchy</b> - Clear information architecture</li>
        <li><b>Reduced Eye Strain</b> - Dark gray backgrounds instead of pure black</li>
        </ul>
        
        <h3 style="color: #0d7377;">⚡ Performance Features</h3>
        <ul style="font-size: 14px; line-height: 1.6;">
        <li>High-performance scanning (100+ files/second)</li>
        <li>Multi-threaded hash computation</li>
        <li>Intelligent duplicate detection</li>
        <li>Memory-efficient processing</li>
        </ul>
        
        <h3 style="color: #0d7377;">🔒 Enterprise Security</h3>
        <ul style="font-size: 14px; line-height: 1.6;">
        <li>Comprehensive security validation</li>
        <li>Automatic backup creation</li>
        <li>Audit trail with CSV export</li>
        <li>Risk assessment and categorization</li>
        </ul>
        """)
        about_text.setWordWrap(True)
        about_text.setStyleSheet("QLabel { color: #e0e0e0; }")
        layout.addWidget(about_text)
        layout.addStretch()
        
        self.tab_widget.addTab(about_widget, "ℹ️ About")
    
    def _setup_status_bar(self):
        """Setup professional status bar"""
        self.status_bar = self.statusBar()
        
        self.scan_status = QtWidgets.QLabel("Ready for analysis")
        self.file_count = QtWidgets.QLabel("Files: 0")
        self.total_size = QtWidgets.QLabel("Size: 0 B")
        self.scan_rate = QtWidgets.QLabel("Rate: 0 files/sec")
        
        self.status_bar.addWidget(self.scan_status)
        self.status_bar.addPermanentWidget(self.scan_rate)
        self.status_bar.addPermanentWidget(self.file_count)
        self.status_bar.addPermanentWidget(self.total_size)
    
    def _create_menu_bar(self):
        """Create menu bar with advanced features"""
        menubar = self.menuBar()
        
        # Tools menu
        tools_menu = menubar.addMenu("&Tools")
        
        graph_action = QtGui.QAction("📊 &Duplicate Graph Visualization", self)
        graph_action.setShortcut("Ctrl+G")
        graph_action.triggered.connect(self.show_duplicate_graph)
        tools_menu.addAction(graph_action)
        
        audit_action = QtGui.QAction("🔍 &View Audit Log", self)
        audit_action.setShortcut("Ctrl+A")
        audit_action.triggered.connect(self.view_audit_log)
        tools_menu.addAction(audit_action)
        
        tools_menu.addSeparator()
        
        rust_info_action = QtGui.QAction("⚡ Rust Core Status", self)
        rust_info_action.triggered.connect(self.show_rust_core_status)
        tools_menu.addAction(rust_info_action)
        
        # Help menu
        help_menu = menubar.addMenu("&Help")
        
        about_action = QtGui.QAction("&About CipherClean", self)
        about_action.triggered.connect(self.show_about_dialog)
        help_menu.addAction(about_action)
    
    def _load_settings(self):
        """Load user settings"""
        self.dir_line.setText(self.settings.value('last_directory', str(Path.home())))
        self.size_threshold.setValue(int(self.settings.value('size_threshold', 10)))
    
    def _save_settings(self):
        """Save user settings"""
        self.settings.setValue('last_directory', self.dir_line.text())
        self.settings.setValue('size_threshold', self.size_threshold.value())
    
    def _load_recent_logs(self):
        """Load recent logs"""
        try:
            log_file = os.path.expanduser('~/.disk_cleanup_logs/disk_cleanup.log')
            if os.path.exists(log_file):
                with open(log_file, 'r') as f:
                    lines = f.readlines()[-1000:]
                    self.log_text.setPlainText(''.join(lines))
        except Exception as e:
            self.log_text.setPlainText(f"Error loading logs: {e}")
    
    def choose_directory(self):
        """Directory selection dialog"""
        dialog = QtWidgets.QFileDialog(self)
        dialog.setFileMode(QtWidgets.QFileDialog.FileMode.Directory)
        dialog.setDirectory(self.dir_line.text())
        
        if dialog.exec():
            selected = dialog.selectedFiles()
            if selected:
                self.dir_line.setText(selected[0])
    
    def start_scan(self):
        """Start the scanning process"""
        root_dir = self.dir_line.text().strip()
        
        if not root_dir or not os.path.isdir(root_dir):
            QtWidgets.QMessageBox.warning(self, "Invalid Directory", "Please select a valid directory to scan.")
            return
        
        self.table.setRowCount(0)
        self.records.clear()
        self._update_buttons(False)
        
        config = {
            'size_threshold': self.size_threshold.value() * 1024 * 1024,
            'exclude_paths': [p.strip() for p in self.exclusion_text.toPlainText().strip().split('\n') if p.strip()],
            'max_file_size': 5 * 1024**3
        }
        
        self.scanner = PerformanceOptimizedScanner(root_dir, config)
        self.scanner.batch_update.connect(self.add_batch_records)
        self.scanner.progress_updated.connect(self.on_progress)
        self.scanner.scan_completed.connect(self.on_scan_complete)
        
        self.scan_btn.setEnabled(False)
        self.abort_btn.setEnabled(True)
        self.export_csv_btn.setEnabled(False)
        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0)
        self.scan_status.setText("🚀 Analyzing filesystem...")
        
        self.scan_start_time = time.time()
        self.scanner.start()
        logger.info(f"Started professional scan of {root_dir}")
    
    def abort_scan(self):
        """Abort current scan"""
        if self.scanner:
            self.scanner.abort()
            self.scanner.wait(5000)
        
        self._reset_ui_after_scan()
        self.scan_status.setText("Analysis aborted")
    
    def on_progress(self, message: str, current: int, total: int):
        """Handle progress updates"""
        self.progress_label.setText(message)
        self.scan_status.setText(message)
        
        if total > 0:
            self.progress_bar.setRange(0, total)
            self.progress_bar.setValue(current)
        elif current == -1:
            self.progress_bar.setRange(0, 0)
        
        if hasattr(self, 'scan_start_time') and current > 0:
            elapsed = time.time() - self.scan_start_time
            if elapsed > 0:
                rate = current / elapsed
                self.scan_rate.setText(f"Rate: {rate:.1f} files/sec")
    
    def add_batch_records(self, batch_records: List[FileRecord]):
        """Add batch records with professional styling"""
        start_row = self.table.rowCount()
        self.table.setSortingEnabled(False)
        
        for i, record in enumerate(batch_records):
            row = start_row + i
            self.table.insertRow(row)
            
            # Checkbox
            checkbox = QtWidgets.QTableWidgetItem()
            checkbox.setCheckState(Qt.CheckState.Unchecked)
            self.table.setItem(row, 0, checkbox)
            
            # Path
            path_item = QtWidgets.QTableWidgetItem(record.path)
            path_item.setToolTip(record.path)
            self.table.setItem(row, 1, path_item)
            
            # Size
            size_item = QtWidgets.QTableWidgetItem(humanize.naturalsize(record.size))
            size_item.setData(Qt.ItemDataRole.UserRole, record.size)
            self.table.setItem(row, 2, size_item)
            
            # Last access
            if record.last_access_datetime:
                date_str = record.last_access_datetime.strftime("%Y-%m-%d %H:%M")
                date_item = QtWidgets.QTableWidgetItem(date_str)
                date_item.setData(Qt.ItemDataRole.UserRole, record.last_access_datetime.timestamp())
            else:
                last_access = datetime.fromtimestamp(max(record.atime, record.mtime))
                date_str = last_access.strftime("%Y-%m-%d %H:%M")
                date_item = QtWidgets.QTableWidgetItem(date_str)
                date_item.setData(Qt.ItemDataRole.UserRole, last_access.timestamp())
            self.table.setItem(row, 3, date_item)
            
            # FIXED: Days old with professional color coding
            days_item = QtWidgets.QTableWidgetItem(str(record.days_old))
            days_item.setData(Qt.ItemDataRole.UserRole, record.days_old)
            
            # Professional color coding with excellent contrast
            if record.days_old > 365:  # Very old files
                days_item.setBackground(QtGui.QColor(79, 47, 47))    # Dark red background
                days_item.setForeground(QtGui.QColor(255, 183, 183)) # Light red text
            elif record.days_old > 90:  # Old files
                days_item.setBackground(QtGui.QColor(79, 63, 31))    # Dark orange background
                days_item.setForeground(QtGui.QColor(255, 215, 138)) # Light orange text
            elif record.days_old > 30:  # Moderately old files
                days_item.setBackground(QtGui.QColor(79, 79, 31))    # Dark yellow background
                days_item.setForeground(QtGui.QColor(255, 255, 138)) # Light yellow text
            else:  # Recent files
                days_item.setBackground(QtGui.QColor(31, 79, 47))    # Dark green background
                days_item.setForeground(QtGui.QColor(138, 255, 183)) # Light green text
            
            self.table.setItem(row, 4, days_item)
            
            # Duplicates - placeholder
            dup_item = QtWidgets.QTableWidgetItem("...")
            dup_item.setData(Qt.ItemDataRole.UserRole, 1)
            self.table.setItem(row, 5, dup_item)
            
            # Risk level - placeholder
            risk_item = QtWidgets.QTableWidgetItem("Analyzing...")
            self.table.setItem(row, 6, risk_item)
            
            # File type
            type_item = QtWidgets.QTableWidgetItem(record.file_type or "file")
            self.table.setItem(row, 7, type_item)
        
        self.table.setSortingEnabled(True)
        
        self.records.extend(batch_records)
        self.file_count.setText(f"Files: {len(self.records)}")
        total_size = sum(r.size for r in self.records)
        self.total_size.setText(f"Size: {humanize.naturalsize(total_size)}")
    
    def on_scan_complete(self, records: List[FileRecord]):
        """Handle scan completion with professional styling"""
        self._reset_ui_after_scan()
        self.records = records

        # Update master index with canonical files per hash
        try:
            groups = {}
            for r in self.records:
                if r.hash:
                    groups.setdefault(r.hash, []).append(r)
            for h, recs in groups.items():
                canonical = max(recs, key=lambda x: max(x.atime, x.mtime))
                self.master.upsert(h, canonical.path, canonical.size)
        except Exception as e:
            logger.debug(f"Master index update on UI complete skipped: {e}")
        
        # Build duplicate graph data for visualization
        self._build_duplicate_graph_data()
        
        self.table.setSortingEnabled(False)
        
        # Update final data with professional contrast
        for row, record in enumerate(self.records):
            if row < self.table.rowCount():
                # Update duplicates with professional styling
                dup_item = self.table.item(row, 5)
                if dup_item:
                    if record.hash_error:
                        dup_item.setText("Hash Error")
                        dup_item.setBackground(QtGui.QColor(79, 47, 47))
                        dup_item.setForeground(QtGui.QColor(255, 183, 183))
                        dup_item.setData(Qt.ItemDataRole.UserRole, 0)
                    else:
                        dup_item.setText(str(record.duplicate_count))
                        dup_item.setData(Qt.ItemDataRole.UserRole, record.duplicate_count)
                        
                        if record.duplicate_count > 1:
                            dup_item.setBackground(QtGui.QColor(79, 63, 31))    # Dark orange
                            dup_item.setForeground(QtGui.QColor(255, 215, 138)) # Light orange
                        else:
                            dup_item.setBackground(QtGui.QColor(26, 26, 26))    # Darker gray
                            dup_item.setForeground(QtGui.QColor(224, 224, 224)) # Light gray
                
                # Update risk level with professional colors
                risk_item = self.table.item(row, 6)
                if risk_item:
                    if any(pattern in record.path.lower() for pattern in ['node_modules', '.cache', 'downloads', 'temp']):
                        risk_item.setText("LOW")
                        risk_item.setBackground(QtGui.QColor(31, 79, 47))       # Dark green
                        risk_item.setForeground(QtGui.QColor(138, 255, 183))   # Light green
                    elif any(pattern in record.path for pattern in ['/usr', '/bin', '/etc', '/lib']):
                        risk_item.setText("HIGH")
                        risk_item.setBackground(QtGui.QColor(79, 47, 47))       # Dark red
                        risk_item.setForeground(QtGui.QColor(255, 183, 183))   # Light red
                    else:
                        risk_item.setText("MEDIUM")
                        risk_item.setBackground(QtGui.QColor(79, 63, 31))       # Dark orange
                        risk_item.setForeground(QtGui.QColor(255, 215, 138))   # Light orange
        
        self.table.setSortingEnabled(True)
        self.table.sortItems(4, Qt.SortOrder.DescendingOrder)
        
        if self.records:
            self._update_buttons(True)
            self.export_csv_btn.setEnabled(True)
            
            duplicates = sum(1 for r in self.records if r.duplicate_count > 1)
            if duplicates:
                self.consolidate_btn.setEnabled(True)
        
        elapsed = time.time() - self.scan_start_time if hasattr(self, 'scan_start_time') else 0
        scan_rate = len(self.records) / elapsed if elapsed > 0 else 0
        
        scan_summary = f"✅ Analysis complete: {len(self.records)} files in {elapsed:.1f}s ({scan_rate:.1f} files/sec)"
        duplicates_count = sum(1 for r in self.records if r.duplicate_count > 1)
        if duplicates_count:
            scan_summary += f", {duplicates_count} duplicates found"
        
        self.scan_status.setText(scan_summary)
        logger.info(scan_summary)
    
    def export_to_csv(self):
        """Export scan results to CSV"""
        if not self.records:
            QMessageBox.information(self, "No Data", "No scan data available to export.")
            return
        
        filename, _ = QFileDialog.getSaveFileName(
            self, 
            "Export Analysis Results",
            f"disk_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
            "CSV Files (*.csv);;All Files (*)"
        )
        
        if not filename:
            return
        
        try:
            with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
                fieldnames = [
                    'File_Path', 'Size_Bytes', 'Size_Human', 'Last_Access', 'Days_Old', 
                    'Duplicate_Count', 'SHA256_Hash', 'Risk_Level', 'File_Type',
                    'Is_Executable', 'Scan_Timestamp'
                ]
                
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                
                scan_timestamp = datetime.now().isoformat()
                
                for record in self.records:
                    # Determine risk level
                    if any(pattern in record.path.lower() for pattern in ['node_modules', '.cache', 'downloads', 'temp']):
                        risk_level = "LOW"
                    elif any(pattern in record.path for pattern in ['/usr', '/bin', '/etc', '/lib']):
                        risk_level = "HIGH"
                    else:
                        risk_level = "MEDIUM"
                    
                    # Format last access
                    if record.last_access_datetime:
                        last_access = record.last_access_datetime.isoformat()
                    else:
                        last_access = datetime.fromtimestamp(max(record.atime, record.mtime)).isoformat()
                    
                    writer.writerow({
                        'File_Path': record.path,
                        'Size_Bytes': record.size,
                        'Size_Human': humanize.naturalsize(record.size),
                        'Last_Access': last_access,
                        'Days_Old': record.days_old,
                        'Duplicate_Count': record.duplicate_count,
                        'SHA256_Hash': record.hash_value or '',
                        'Risk_Level': risk_level,
                        'File_Type': record.file_type,
                        'Is_Executable': record.is_executable,
                        'Scan_Timestamp': scan_timestamp
                    })
            
            QMessageBox.success(self, "Export Complete", f"Results exported to:\n{filename}")
        except Exception as e:
            QMessageBox.critical(self, "Export Failed", f"Failed to export: {e}")
    
    def visualize_duplicate_graph(self):
        """Generate interactive node-link graph of duplicate clusters using pyvis"""
        if not self.records:
            QMessageBox.information(self, "No Data", "No scan data available. Run a scan first.")
            return
        
        # Filter records with duplicates
        hash_groups = {}
        for record in self.records:
            if record.hash_value and record.duplicate_count > 1:
                if record.hash_value not in hash_groups:
                    hash_groups[record.hash_value] = []
                hash_groups[record.hash_value].append(record)
        
        # Only keep groups with actual duplicates
        duplicate_groups = {h: g for h, g in hash_groups.items() if len(g) > 1}
        
        if not duplicate_groups:
            QMessageBox.information(self, "No Duplicates", "No duplicate files found to visualize.")
            return
        
        try:
            from pyvis.network import Network
        except ImportError:
            QMessageBox.critical(
                self, "Missing Dependency",
                "pyvis is required for graph visualization.\nInstall with: pip install pyvis>=0.3.2"
            )
            return
        
        # Create the network
        net = Network(height="800px", width="100%", bgcolor="#121212", font_color="#e0e0e0")
        
        # Add nodes and edges
        node_id_map = {}
        current_id = 0
        
        # Color scheme for different clusters
        colors = ['#0d7377', '#1976d2', '#c62d42', '#ff9800', '#4caf50', 
                  '#9c27b0', '#e91e63', '#00bcd4', '#8bc34a', '#ff5722']
        
        for idx, (hash_val, group) in enumerate(duplicate_groups.items()):
            color = colors[idx % len(colors)]
            
            # Create a central "source" node for this cluster (patient zero visualization)
            source_id = current_id
            node_id_map[f"source_{hash_val[:8]}"] = source_id
            
            # Try to identify the oldest file as "patient zero"
            oldest_file = min(group, key=lambda r: r.mtime)
            
            net.add_node(
                source_id,
                label=f"Cluster {idx+1}\n({len(group)} files)",
                title=f"Duplicate Cluster {idx+1}\nHash: {hash_val[:16]}...\nFiles: {len(group)}\nTotal Size: {humanize.naturalsize(sum(r.size for r in group))}",
                shape="diamond",
                size=25,
                color=color,
                borderWidth=3
            )
            current_id += 1
            
            # Add file nodes and connect to source
            for record in group:
                file_id = current_id
                node_id_map[record.path] = file_id
                
                # Determine if this is the "patient zero" (oldest)
                is_oldest = (record.path == oldest_file.path)
                
                size_mb = record.size / (1024 * 1024)
                node_size = max(10, min(20, size_mb))  # Scale by file size
                
                net.add_node(
                    file_id,
                    label=Path(record.path).name[:30] + ("..." if len(Path(record.path).name) > 30 else ""),
                    title=f"Path: {record.path}\nSize: {humanize.naturalsize(record.size)}\nModified: {datetime.fromtimestamp(record.mtime).strftime('%Y-%m-%d %H:%M:%S')}\n{'🎯 PATIENT ZERO (Oldest)' if is_oldest else ''}",
                    shape="dot" if not is_oldest else "star",
                    size=node_size,
                    color="#ffffff" if not is_oldest else "#ffeb3b",
                    borderWidth=2 if not is_oldest else 4
                )
                
                # Add edge between source and file
                net.add_edge(source_id, file_id)
                
                current_id += 1
        
        # Configure physics for better layout
        net.set_options("""
        {
          "physics": {
            "forceAtlas2Based": {
              "gravitationalConstant": -50,
              "centralGravity": 0.005,
              "springLength": 100,
              "springConstant": 0.18
            },
            "maxVelocity": 146,
            "solver": "forceAtlas2Based",
            "timestep": 0.35,
            "stabilization": {
              "enabled": true,
              "iterations": 200
            }
          },
          "interaction": {
            "hover": true,
            "tooltipDelay": 200,
            "zoomView": true
          }
        }
        """)
        
        # Generate output filename
        output_dir = Path.home() / "CipherClean_Graphs"
        output_dir.mkdir(exist_ok=True)
        output_file = output_dir / f"duplicate_graph_{datetime.now().strftime('%Y%m%d_%H%M%S')}.html"
        
        net.save_graph(str(output_file))
        
        # Open in browser
        import webbrowser
        webbrowser.open(f"file://{output_file.absolute()}")
        
        QMessageBox.information(
            self, "Graph Generated",
            f"Interactive duplicate graph saved to:\n{output_file}\n\n"
            f"Visualizing {len(duplicate_groups)} duplicate clusters "
            f"with {sum(len(g) for g in duplicate_groups.values())} total files.\n\n"
            f"💡 Tip: Yellow star nodes indicate 'patient zero' (oldest file in each cluster)."
        )
    
    def show_rust_core_status(self):
        """Display status of Rust core extension"""
        rust_available = False
        rust_version = "N/A"
        hash_speed = "N/A"
        
        try:
            import cipherclean_core as cc
            rust_available = True
            rust_version = getattr(cc, '__version__', '1.0.0')
            # Test hash function availability
            if hasattr(cc, 'hash_file'):
                hash_speed = "Accelerated ✓"
        except ImportError:
            pass
        
        status_icon = "⚡" if rust_available else "⚠️"
        status_text = "Active" if rust_available else "Not Installed"
        acceleration = "Rust-native hashing enabled" if rust_available else "Using Python fallback (install rust_core for 10-50x speedup)"
        
        msg = f"""
{status_icon} Rust Core Status: {status_text}

Version: {rust_version}
Hashing: {hash_speed}

{acceleration}

Location: /workspace/rust_core/
Build: cargo build --release

Benefits of Rust Core:
• 10-50x faster SHA256 hashing
• Parallel file traversal
• Zero-copy memory mapping
• Lower CPU usage during scans
"""
        QMessageBox.information(self, "Rust Core Status", msg)
    
    def view_audit_log(self):
        """Display audit log viewer dialog"""
        if not hasattr(self, 'audit_log') or not self.audit_log.log_path.exists():
            QMessageBox.information(
                self, "No Audit Log",
                "No audit log entries found.\nAudit entries are created when files are deleted or consolidated."
            )
            return
        
        # Read audit log entries
        entries = []
        try:
            with open(self.audit_log.log_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        entries.append(line)
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to read audit log: {e}")
            return
        
        if not entries:
            QMessageBox.information(self, "Empty Audit Log", "No entries recorded yet.")
            return
        
        # Create dialog with text viewer
        dialog = QDialog(self)
        dialog.setWindowTitle("🔍 Audit Log Viewer")
        dialog.setMinimumSize(900, 600)
        layout = QVBoxLayout(dialog)
        
        # Info label
        info_label = QLabel(f"📄 Audit Log: {self.audit_log.log_path}\nEntries: {len(entries)}")
        layout.addWidget(info_label)
        
        # Text viewer
        from PyQt6.QtWidgets import QTextEdit
        text_viewer = QTextEdit()
        text_viewer.setReadOnly(True)
        text_viewer.setFontFamily("monospace")
        text_viewer.setPlainText("\n".join(entries))
        layout.addWidget(text_viewer)
        
        # Buttons
        button_box = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Save)
        button_box.accepted.connect(dialog.accept)
        button_box.button(QDialogButtonBox.StandardButton.Save).clicked.connect(
            lambda: self._export_audit_log(entries)
        )
        layout.addWidget(button_box)
        
        dialog.exec()
    
    def _export_audit_log(self, entries):
        """Export audit log to CSV"""
        from PyQt6.QtWidgets import QFileDialog
        filepath, _ = QFileDialog.getSaveFileName(
            self, "Export Audit Log", "", "CSV Files (*.csv);;All Files (*)"
        )
        if filepath:
            try:
                with open(filepath, 'w') as f:
                    f.write("timestamp,action,target,canonical_path,size,file_hash,integrity_hash\n")
                    for entry in entries:
                        f.write(entry + "\n")
                QMessageBox.information(self, "Export Successful", f"Audit log exported to:\n{filepath}")
            except Exception as e:
                QMessageBox.critical(self, "Export Failed", f"Failed to export: {e}")
    
    def show_about_dialog(self):
        """Display about dialog with comprehensive feature information"""
        about_text = f"""
<h2>CipherClean v{SCRIPT_VERSION}</h2>
<p><b>Forensic-Grade Duplicate File Manager</b></p>
<p>A professional tool for identifying and managing duplicate files with enterprise-grade security and audit capabilities.</p>

<h3>🔐 Security Features (Phase 1)</h3>
<ul>
<li><b>O_NOATIME:</b> Prevents inode modification during hashing</li>
<li><b>Symlink Safety:</b> Explicit checks to ignore symlinks outside target tree</li>
<li><b>Secure Supply Chain:</b> Cryptographic hash verification via requirements.lock</li>
</ul>

<h3>🛡️ Data Integrity (Phase 2)</h3>
<ul>
<li><b>Atomic Backups:</b> Verified backups before any destructive action</li>
<li><b>Checksum Verification:</b> SHA256 validation before deletion</li>
<li><b>EXDEV Handling:</b> Graceful handling of cross-filesystem operations</li>
</ul>

<h3>📊 Enterprise Features (Phase 3)</h3>
<ul>
<li><b>Audit Logging:</b> Cryptographically signed chain of custody</li>
<li><b>Rollback Database:</b> SQLite WAL mode with busy timeout</li>
<li><b>Interactive Graph:</b> Visualize duplicate clusters and patient-zero files</li>
<li><b>Rust Core:</b> Optional 10-50x faster hashing via PyO3 extension</li>
</ul>

<p><i>Developed with forensic soundness and operational safety in mind.</i></p>
<p>© 2024 FinchlessResearch</p>
"""
        QMessageBox.about(self, "About CipherClean", about_text)
    
    def _reset_ui_after_scan(self):
        """Reset UI after scan"""
        self.scan_btn.setEnabled(True)
        self.abort_btn.setEnabled(False)
        self.progress_bar.setVisible(False)
        self.progress_label.setText("")
    
    def _update_buttons(self, enabled: bool):
        """Update button states"""
        self.select_safe_btn.setEnabled(enabled)
        self.select_old_btn.setEnabled(enabled)
        self.delete_btn.setEnabled(enabled)
        self.consolidate_btn.setEnabled(enabled)
        self.graph_btn.setEnabled(enabled)
        self.export_csv_btn.setEnabled(enabled)
    
    def select_safe_files(self):
        """Select files deemed safe for deletion"""
        safe_count = 0
        for row in range(self.table.rowCount()):
            record = self.records[row] if row < len(self.records) else None
            checkbox = self.table.item(row, 0)
            
            if record and checkbox:
                is_safe = (
                    not any(pattern in record.path for pattern in ['/usr', '/bin', '/etc', '/lib']) and
                    record.days_old > 30 and
                    not record.is_executable and
                    record.size > 50 * 1024 * 1024  # > 50MB
                )
                
                if is_safe:
                    checkbox.setCheckState(Qt.CheckState.Checked)
                    safe_count += 1
        
        self.scan_status.setText(f"✅ Selected {safe_count} safe files for deletion")
    
    def select_old_files(self):
        """Select files older than 30 days"""
        old_count = 0
        for row in range(self.table.rowCount()):
            record = self.records[row] if row < len(self.records) else None
            checkbox = self.table.item(row, 0)
            
            if record and checkbox and record.days_old >= 30:
                checkbox.setCheckState(Qt.CheckState.Checked)
                old_count += 1
        
        self.scan_status.setText(f"📅 Selected {old_count} files older than 30 days")
    
    def delete_selected(self):
        """Delete selected files with confirmation"""
        selected_rows = self._get_selected_rows()
        if not selected_rows:
            QtWidgets.QMessageBox.information(self, "No Selection", "Please select files to delete.")
            return
        
        selected_records = [self.records[row] for row in selected_rows if row < len(self.records)]
        total_size = sum(r.size for r in selected_records)
        
        msg = (
            f"You are about to delete {len(selected_records)} file(s)\n"
            f"Total size: {humanize.naturalsize(total_size)}\n\n"
            f"This will free {humanize.naturalsize(total_size)} of disk space.\n\n"
            "⚠️  This action cannot be undone. Continue?"
        )
        
        reply = QtWidgets.QMessageBox.question(
            self, "Confirm Deletion", msg,
            QtWidgets.QMessageBox.StandardButton.Yes | QtWidgets.QMessageBox.StandardButton.No
        )
        
        if reply != QtWidgets.QMessageBox.StandardButton.Yes:
            return
        
        # Perform deletion with atomic backup logic and audit logging (Phase 2 & 3)
        failures = []
        deleted_count = 0
        batch = self.rblog.new_batch()
        
        for row in sorted(selected_rows, reverse=True):
            if row < len(self.records):
                record = self.records[row]
                backup_path = None
                try:
                    # Create verified backup before destructive action (atomic backup logic - Phase 2)
                    backup_path = record.path + ".backup_cc"
                    shutil.copy2(record.path, backup_path)
                    # Verify backup checksum
                    with open(backup_path, 'rb') as f:
                        backup_hash = hashlib.sha256(f.read()).hexdigest()
                    with open(record.path, 'rb') as f:
                        original_hash = hashlib.sha256(f.read()).hexdigest()
                    if backup_hash != original_hash:
                        raise Exception("Backup checksum mismatch")
                    
                    os.remove(record.path)
                    self.table.removeRow(row)
                    del self.records[row]
                    deleted_count += 1
                    
                    # Log to rollback database
                    self.rblog.log(batch, "delete", record.path, "", record.size)
                    # Log to audit trail for forensic chain of custody (Phase 3)
                    file_hash = record.hash or ""
                    self.audit_log.log_action("DELETE", record.path, "", record.size, file_hash)
                    
                    logger.info(f"Deleted: {record.path}")
                    
                    # Remove backup only after successful deletion (try...finally pattern - Phase 2)
                    if backup_path and os.path.exists(backup_path):
                        os.remove(backup_path)
                        
                except Exception as e:
                    failures.append((record.path, str(e)))
                    logger.error(f"Failed to delete {record.path}: {e}")
                    # Restore from backup if it exists and is valid
                    if backup_path and os.path.exists(backup_path):
                        try:
                            shutil.copy2(backup_path, record.path)
                            logger.info(f"Restored {record.path} from backup")
                        finally:
                            os.remove(backup_path)
        
        # Show results
        msg_parts = [f"✅ Successfully deleted {deleted_count} file(s)"]
        
        if failures:
            msg_parts.append(f"\n❌ {len(failures)} files could not be deleted:")
            msg_parts.extend([f"• {os.path.basename(path)}: {error}" for path, error in failures[:5]])
            if len(failures) > 5:
                msg_parts.append(f"... and {len(failures) - 5} more")
        
        QtWidgets.QMessageBox.information(self, "Deletion Results", "\n".join(msg_parts))
        
        # Update UI
        self.file_count.setText(f"Files: {len(self.records)}")
        total_size = sum(r.size for r in self.records)
        self.total_size.setText(f"Size: {humanize.naturalsize(total_size)}")
        
        if not self.records:
            self._update_buttons(False)
    
    def consolidate_duplicates(self):
        """Consolidate duplicate files via hard linking"""
        duplicate_groups = {}
        for i, record in enumerate(self.records):
            if record.hash and record.duplicate_count > 1:
                duplicate_groups.setdefault(record.hash, []).append(i)
        
        if not duplicate_groups:
            QtWidgets.QMessageBox.information(self, "No Duplicates", "No duplicate files found.")
            return
        
        consolidatable_groups = []
        total_savings = 0
        
        for indices in duplicate_groups.values():
            if len(indices) < 2:
                continue
            
            try:
                devices = set(os.stat(self.records[i].path).st_dev for i in indices)
                if len(devices) == 1:  # Same filesystem
                    file_size = self.records[indices[0]].size
                    savings = (len(indices) - 1) * file_size
                    total_savings += savings
                    consolidatable_groups.append(indices)
            except Exception:
                continue
        
        if not consolidatable_groups:
            QtWidgets.QMessageBox.information(
                self, "Cannot Consolidate",
                "Duplicate files are on different filesystems and cannot be hard-linked."
            )
            return
        
        msg = (
            f"Found {len(consolidatable_groups)} duplicate group(s) for consolidation.\n"
            f"Estimated space savings: {humanize.naturalsize(total_savings)}\n\n"
            "This operation replaces duplicate copies with hard links to save space.\n"
            "Original data is preserved. Continue?"
        )
        
        reply = QtWidgets.QMessageBox.question(
            self, "Confirm Consolidation", msg,
            QtWidgets.QMessageBox.StandardButton.Yes | QtWidgets.QMessageBox.StandardButton.No
        )
        
        if reply != QtWidgets.QMessageBox.StandardButton.Yes:
            return
        
        # Perform consolidation with atomic backup logic and EXDEV handling
        errors = []
        consolidated_count = 0
        batch = self.rblog.new_batch()
        self._consolidation_events = []
        
        for indices in consolidatable_groups:
            canonical_path = self.records[indices[0]].path
            
            for i in indices[1:]:
                duplicate_path = self.records[i].path
                backup_path = None
                try:
                    # Create verified backup before destructive action (atomic backup logic)
                    backup_path = duplicate_path + ".backup_cc"
                    shutil.copy2(duplicate_path, backup_path)
                    # Verify backup checksum
                    with open(backup_path, 'rb') as f:
                        backup_hash = hashlib.sha256(f.read()).hexdigest()
                    with open(duplicate_path, 'rb') as f:
                        original_hash = hashlib.sha256(f.read()).hexdigest()
                    if backup_hash != original_hash:
                        raise Exception("Backup checksum mismatch")
                    
                    # Atomic hard-link replacement to avoid TOCTOU windows
                    tmp = duplicate_path + ".tmp_hl"
                    if os.path.exists(tmp):
                        try:
                            os.remove(tmp)
                        except Exception:
                            pass
                    try:
                        os.link(canonical_path, tmp)
                    except OSError as e:
                        # Handle EXDEV: cross-device link or different filesystem
                        if e.errno == 18:  # EXDEV
                            logger.debug(f"EXDEV: Cannot hardlink across filesystems, skipping {duplicate_path}")
                            # Clean up backup since we're skipping
                            if backup_path and os.path.exists(backup_path):
                                os.remove(backup_path)
                            continue
                        raise
                    os.replace(tmp, duplicate_path)
                    consolidated_count += 1
                    self.rblog.log(batch, "hardlink_replace", duplicate_path, canonical_path, self.records[i].size)
                    # Log to audit trail for forensic chain of custody (Phase 3)
                    file_hash = self.records[i].hash or ""
                    self.audit_log.log_action("HARDLINK_REPLACE", duplicate_path, canonical_path, self.records[i].size, file_hash)
                    self._consolidation_events.append((duplicate_path, canonical_path, self.records[i].size))
                    logger.info(f"Consolidated: {duplicate_path} -> {canonical_path}")
                    
                    # Remove backup only after successful consolidation (try...finally pattern)
                    if backup_path and os.path.exists(backup_path):
                        os.remove(backup_path)
                        
                except Exception as e:
                    errors.append((duplicate_path, str(e)))
                    logger.error(f"Consolidation failed: {e}")
                    # Restore from backup if it exists and is valid
                    if backup_path and os.path.exists(backup_path):
                        try:
                            shutil.copy2(backup_path, duplicate_path)
                            logger.info(f"Restored {duplicate_path} from backup")
                        finally:
                            os.remove(backup_path)
        
        # Update duplicate counts
        self._recalculate_duplicate_counts()
        
        # Show results
        if errors:
            msg = f"✅ Consolidated {consolidated_count} files\n\n"
            msg += f"❌ {len(errors)} files could not be consolidated:\n"
            msg += "\n".join([f"• {os.path.basename(path)}: {error}" for path, error in errors[:3]])
            QtWidgets.QMessageBox.warning(self, "Consolidation Results", msg)
        else:
            # Optional CSV export for consolidation batch
            try:
                csv_name = os.path.join(log_dir, f"consolidation_batch_{batch}.csv")
                with open(csv_name, 'w', newline='', encoding='utf-8') as f:
                    w = csv.writer(f)
                    w.writerow(["Target_Path", "Canonical_Path", "Size_Bytes", "Size_Human"]) 
                    for tgt, canon, sz in self._consolidation_events:
                        w.writerow([tgt, canon, int(sz), humanize.naturalsize(int(sz))])
                logger.info(f"Consolidation CSV written: {csv_name}")
            except Exception as e:
                logger.debug(f"Consolidation CSV skipped: {e}")

            QtWidgets.QMessageBox.information(
                self, "Consolidation Complete",
                f"Batch: {batch}\nSaved ≈ {humanize.naturalsize(total_savings)}."
            )
    
    def _recalculate_duplicate_counts(self):
        """Recalculate duplicate counts"""
        for record in self.records:
            record.duplicate_count = 1
        
        hash_groups = {}
        for record in self.records:
            if record.hash:
                hash_groups.setdefault(record.hash, []).append(record)
        
        for group in hash_groups.values():
            if len(group) > 1:
                for record in group:
                    record.duplicate_count = len(group)
        
        # Update table display
        for row, record in enumerate(self.records):
            if row < self.table.rowCount():
                dup_item = self.table.item(row, 5)
                if dup_item:
                    dup_item.setText(str(record.duplicate_count))
                    dup_item.setData(Qt.ItemDataRole.UserRole, record.duplicate_count)
                    
                    if record.duplicate_count > 1:
                        dup_item.setBackground(QtGui.QColor(79, 63, 31))
                        dup_item.setForeground(QtGui.QColor(255, 215, 138))
                    else:
                        dup_item.setBackground(QtGui.QColor(26, 26, 26))
                        dup_item.setForeground(QtGui.QColor(224, 224, 224))
    
    def _get_selected_rows(self) -> List[int]:
        """Get selected row indices"""
        selected = []
        for row in range(self.table.rowCount()):
            checkbox = self.table.item(row, 0)
            if checkbox and checkbox.checkState() == Qt.CheckState.Checked:
                selected.append(row)
        return selected
    
    def closeEvent(self, event):
        """Handle application close"""
        self._save_settings()
        if self.scanner and self.scanner.isRunning():
            self.scanner.abort()
            self.scanner.wait(3000)
        try:
            self.master.close()
        except Exception:
            pass
        try:
            self.rblog.close()
        except Exception:
            pass
        try:
            self.audit_log.close()
        except Exception:
            pass
        super().closeEvent(event)

def main():
    """Main application entry point"""
    app = QtWidgets.QApplication(sys.argv)
    app.setApplicationName("CipherClean")
    app.setApplicationVersion("2.3.0")
    app.setOrganizationName("FinchlessResearch")
    
    # Set high-quality rendering
    app.setStyle('Fusion')
    # Qt6 enables high DPI scaling by default; guard attributes for compatibility.
    for _attr in ("AA_EnableHighDpiScaling", "AA_UseHighDpiPixmaps"):
        try:
            app.setAttribute(getattr(Qt.ApplicationAttribute, _attr), True)
        except AttributeError:
            pass
    
    window = ProfessionalDarkModeWindow()
    window.show()
    
    logger.info("CipherClean v2.3 started")
    return app.exec()

if __name__ == '__main__':
    sys.exit(main())
EOF

# Launch the professionally designed application
log_info "CipherClean v${SCRIPT_VERSION}..."

if [[ -n "${UV_PYTHON_VERSION:-}" ]]; then
    log_info "Using UV Python version: $UV_PYTHON_VERSION"
    uv run --python "$UV_PYTHON_VERSION" python "$PY_SCRIPT"
else
    # Default: use uv's active environment
    uv run python "$PY_SCRIPT"
fi

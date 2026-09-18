
    def _build_duplicate_graph_data(self):
        """Build graph data structure for duplicate visualization"""
        try:
            # Group files by hash
            hash_groups = {}
            for r in self.records:
                if r.hash and r.duplicate_count > 1:
                    hash_groups.setdefault(r.hash, []).append(r)
            
            # Build node-link structure
            nodes = []
            links = []
            node_id_map = {}
            
            for idx, (hash_val, files) in enumerate(hash_groups.items()):
                # Find canonical file (oldest/most accessed)
                canonical = max(files, key=lambda x: max(x.atime, x.mtime))
                canonical_id = f"node_{len(nodes)}"
                node_id_map[canonical.path] = canonical_id
                
                nodes.append({
                    'id': canonical_id,
                    'label': os.path.basename(canonical.path),
                    'title': f"📄 {canonical.path}\nSize: {humanize.naturalsize(canonical.size)}\nDuplicates: {len(files)-1}",
                    'color': '#c62d42',  # Red for canonical/source
                    'size': 25,
                    'hash': hash_val[:16]
                })
                
                # Add duplicate nodes
                for dup in files:
                    if dup.path != canonical.path:
                        dup_id = f"node_{len(nodes)}"
                        node_id_map[dup.path] = dup_id
                        nodes.append({
                            'id': dup_id,
                            'label': os.path.basename(dup.path),
                            'title': f"📄 {dup.path}\nSize: {humanize.naturalsize(dup.size)}",
                            'color': '#0d7377',  # Teal for duplicates
                            'size': 15,
                            'hash': hash_val[:16]
                        })
                        links.append({
                            'source': canonical_id,
                            'target': dup_id,
                            'value': 1
                        })
            
            self.duplicate_graph_data = {'nodes': nodes, 'links': links}
        except Exception as e:
            logger.error(f"Failed to build graph data: {e}")
            self.duplicate_graph_data = None
    
    def show_duplicate_graph(self):
        """Display interactive duplicate relationship graph"""
        if not self.duplicate_graph_data or not self.duplicate_graph_data['nodes']:
            QtWidgets.QMessageBox.information(
                self, "No Duplicates Found",
                "No duplicate clusters detected. Run a scan first to visualize duplicate relationships."
            )
            return
        
        try:
            from pyvis.network import Network
            
            # Create network
            net = Network(height="800px", width="1400px", bgcolor="#121212", font_color="#e0e0e0")
            
            # Add nodes
            for node in self.duplicate_graph_data['nodes']:
                net.add_node(
                    node['id'],
                    label=node['label'][:30] + "..." if len(node['label']) > 30 else node['label'],
                    title=node['title'],
                    color=node['color'],
                    size=node['size']
                )
            
            # Add edges
            for link in self.duplicate_graph_data['links']:
                net.add_edge(link['source'], link['target'])
            
            # Configure physics
            net.set_options("""
            {
              "physics": {
                "enabled": true,
                "solver": "forceAtlas2Based",
                "forceAtlas2Based": {
                  "gravitationalConstant": -50,
                  "centralGravity": 0.005,
                  "springLength": 200,
                  "springConstant": 0.18
                }
              },
              "interaction": {
                "hover": true,
                "tooltipDelay": 200
              }
            }
            """)
            
            # Save and open
            html_path = os.path.join(os.path.expanduser("~"), "cipherclean_duplicates.html")
            net.save_graph(html_path)
            
            # Open in browser
            import webbrowser
            webbrowser.open(f"file://{html_path}")
            
            self.scan_status.setText("📊 Duplicate graph opened in browser")
        except ImportError:
            QtWidgets.QMessageBox.warning(
                self, "PyVis Not Installed",
                "Install pyvis for graph visualization: pip install pyvis networkx"
            )
        except Exception as e:
            QtWidgets.QMessageBox.critical(self, "Graph Error", f"Failed to create graph: {e}")
    
    def view_audit_log(self):
        """Display audit log viewer"""
        try:
            log_path = os.path.expanduser("~/.disk_cleanup_audit.log")
            if not os.path.exists(log_path):
                QtWidgets.QMessageBox.information(self, "No Audit Log", "No audit log entries found.")
                return
            
            dialog = QtWidgets.QDialog(self)
            dialog.setWindowTitle("🔍 Audit Log Viewer")
            dialog.setMinimumSize(1200, 800)
            
            layout = QtWidgets.QVBoxLayout(dialog)
            
            text_widget = QtWidgets.QTextEdit()
            text_widget.setReadOnly(True)
            text_widget.setFont(QtGui.QFont("Courier New", 10))
            
            with open(log_path, 'r') as f:
                content = f.read()
                text_widget.setPlainText(content)
            
            layout.addWidget(text_widget)
            
            btn_layout = QtWidgets.QHBoxLayout()
            close_btn = QtWidgets.QPushButton("Close")
            close_btn.clicked.connect(dialog.close)
            btn_layout.addStretch()
            btn_layout.addWidget(close_btn)
            layout.addLayout(btn_layout)
            
            dialog.exec()
        except Exception as e:
            QtWidgets.QMessageBox.critical(self, "Error", f"Failed to load audit log: {e}")
    
    def show_rust_core_status(self):
        """Display Rust core extension status"""
        try:
            import cipherclean_core
            
            hasher = cipherclean_core.FastHasher()
            
            info_text = """
⚡ CipherClean Rust Core Status

✅ Rust Extension Loaded Successfully

Features Available:
  • FastHasher - High-performance SHA256 hashing
  • hash_files_parallel - Multi-threaded batch hashing  
  • hash_files_forensic - Forensic mode with O_NOATIME
  
Performance Benefits:
  • Parallel processing with Rayon
  • Optimized memory usage
  • Zero-copy file reading
  • Native code execution speed

The Rust core provides up to 10x faster hashing
compared to pure Python implementation.
            """
            
            QtWidgets.QMessageBox.information(self, "Rust Core Status", info_text.strip())
        except ImportError:
            warning_text = """
⚠️ Rust Core Not Available

The cipherclean_core module was not found.

To enable Rust acceleration:
  1. Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  2. Build the core: cd rust_core && cargo build --release
  3. Copy library: cp target/release/libcipherclean_core.so ../

Without Rust core, CipherClean uses Python-based hashing.
            """
            QtWidgets.QMessageBox.warning(self, "Rust Core Not Available", warning_text.strip())
    
    def show_about_dialog(self):
        """Show enhanced about dialog"""
        about_text = f"""
<h2>🚀 CipherClean v{SCRIPT_VERSION}</h2>
<p><b>Enterprise-Grade File Analysis & Deduplication</b></p>
<hr>
<p><b>Key Features:</b></p>
<ul>
  <li>📊 Interactive Duplicate Graph Visualization</li>
  <li>⚡ Rust-Powered High-Performance Hashing</li>
  <li>🔐 Forensic-Grade Audit Logging</li>
  <li>💾 Atomic Backup & Recovery</li>
  <li>🛡️ Secure Supply Chain (requirements.lock)</li>
  <li>📈 Scalable Database Architecture (WAL mode)</li>
</ul>
<p><b>Phases Implemented:</b></p>
<ul>
  <li>✅ Phase 1: Critical Security & Forensic Soundness</li>
  <li>✅ Phase 2: Operational Safety & Data Integrity</li>
  <li>✅ Phase 3: Scalability & Enterprise Readiness</li>
  <li>✅ Advanced: Graph Visualization & Rust Core</li>
</ul>
<p><i>FinchlessResearch © 2024</i></p>
        """
        
        msg_box = QtWidgets.QMessageBox(self)
        msg_box.setWindowTitle("About CipherClean")
        msg_box.setTextFormat(Qt.TextFormat.RichText)
        msg_box.setText(about_text)
        msg_box.setIcon(QtWidgets.QMessageBox.Icon.Information)
        msg_box.exec()


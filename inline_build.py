import os
import re

# --- CONFIGURATION ---
BUILD_DIR = 'build/web'
OUTPUT_FILE = 'build/web/single_index.html'
# ---------------------

def inline_flutter_build():
    index_path = os.path.join(BUILD_DIR, 'index.html')
    main_js_path = os.path.join(BUILD_DIR, 'main.dart.js')
    flutter_js_path = os.path.join(BUILD_DIR, 'flutter.js')

    # 1. Validation
    if not os.path.exists(index_path):
        print(f"Error: {index_path} not found. Run 'flutter build web' first.")
        return
    if not os.path.exists(main_js_path):
        print(f"Error: {main_js_path} not found. Ensure you built for JS, not Wasm.")
        return

    print(f"Reading files from {BUILD_DIR}...")
    
    with open(index_path, 'r', encoding='utf-8') as f:
        html_content = f.read()

    with open(main_js_path, 'r', encoding='utf-8') as f:
        main_js_content = f.read()

    # flutter.js might be named differently or merged in newer versions, but usually exists
    flutter_js_content = ""
    if os.path.exists(flutter_js_path):
        with open(flutter_js_path, 'r', encoding='utf-8') as f:
            flutter_js_content = f.read()
    else:
        print("Warning: flutter.js not found. Proceeding without it (might be okay if bootstrap is different).")

    # 2. Clean up the HTML
    # Remove the standard script tags to prevent double-loading or 404s
    html_content = re.sub(r'<script[^>]*src=["\']flutter\.js["\'][^>]*>.*?</script>', '', html_content, flags=re.DOTALL)
    html_content = re.sub(r'<script[^>]*src=["\']main\.dart\.js["\'][^>]*>.*?</script>', '', html_content, flags=re.DOTALL)
    
    # Optional: Fix <base href="/"> to be relative for local file opening
    if '<base href="/">' in html_content:
        print("Adjusting <base href> for local file usage...")
        html_content = html_content.replace('<base href="/">', '<base href="./">')

    # 3. Construct the Injection Script
    # We explicitly define the loader to ensure it runs immediately
    injection = f"""
    <script>
      // [INLINE] flutter.js content
      {flutter_js_content}

      // [INLINE] main.dart.js content
      {main_js_content}

      // [INLINE] Bootstrap Logic
      // This mimics the standard window.addEventListener('load') logic but ensures it uses the code we just injected.
      window.addEventListener('load', function(ev) {{
        // Download main.dart.js is already "done" since it's inlined.
        // We trigger the engine initialization directly.
        if (typeof _flutter !== 'undefined' && _flutter.loader) {{
            _flutter.loader.loadEntrypoint({{
                onEntrypointLoaded: function(engineInitializer) {{
                    engineInitializer.initializeEngine().then(function(appRunner) {{
                        appRunner.runApp();
                    }});
                }}
            }});
        }} else {{
            console.error("Flutter loader not found. The inline script failed to initialize _flutter.");
        }}
      }});
    </script>
    """

    # 4. Inject into Body
    # We append it right before the closing body tag
    if '</body>' in html_content:
        final_html = html_content.replace('</body>', injection + '</body>')
    else:
        final_html = html_content + injection

    # 5. Write Output
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write(final_html)

    print(f"Success! Single file generated: {OUTPUT_FILE}")
    print("Note: Icons (FontManifest) and Assets are NOT inlined by this script.")

if __name__ == "__main__":
    inline_flutter_build()
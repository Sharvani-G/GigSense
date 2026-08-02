import os
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. http.post(..., headers: { ... })
    # We want to inject 'ngrok-skip-browser-warning': 'true' into existing headers.
    def replace_headers(match):
        headers_content = match.group(1)
        if "'ngrok-skip-browser-warning'" not in headers_content and '"ngrok-skip-browser-warning"' not in headers_content:
            return f"headers: {{{headers_content}, 'ngrok-skip-browser-warning': 'true'}}"
        return match.group(0)

    content = re.sub(r'headers:\s*\{([^}]+)\}', replace_headers, content)

    # 2. http.post(url) where headers are missing
    # We need to add headers if they don't exist.
    # Be careful not to replace when headers are already there.
    def replace_post_no_headers(match):
        call_content = match.group(1)
        if 'headers:' not in call_content:
            # Insert headers right after the URL
            parts = call_content.split(',', 1)
            if len(parts) == 1:
                return f"http.post({parts[0]}, headers: {{'ngrok-skip-browser-warning': 'true'}})"
            else:
                return f"http.post({parts[0]}, headers: {{'ngrok-skip-browser-warning': 'true'}},{parts[1]})"
        return match.group(0)
    
    content = re.sub(r'http\.post\(([^)]+)\)', replace_post_no_headers, content)
    
    # 3. http.get(url) where headers are missing
    def replace_get_no_headers(match):
        call_content = match.group(1)
        if 'headers:' not in call_content:
            parts = call_content.split(',', 1)
            if len(parts) == 1:
                return f"http.get({parts[0]}, headers: {{'ngrok-skip-browser-warning': 'true'}})"
            else:
                return f"http.get({parts[0]}, headers: {{'ngrok-skip-browser-warning': 'true'}},{parts[1]})"
        return match.group(0)

    content = re.sub(r'http\.get\(([^)]+)\)', replace_get_no_headers, content)
    
    # 4. http.MultipartRequest
    # We add ..headers['ngrok-skip-browser-warning'] = 'true'
    content = re.sub(r"http\.MultipartRequest\('POST', url\)", r"http.MultipartRequest('POST', url)\n        ..headers['ngrok-skip-browser-warning'] = 'true'", content)
    
    # 5. http.Request (e.g. in chat_screen.dart)
    content = re.sub(r"request\.headers\['Content-Type'\] = 'application/json';", r"request.headers['Content-Type'] = 'application/json';\n      request.headers['ngrok-skip-browser-warning'] = 'true';", content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

for root, _, files in os.walk(r'c:\SHARAN PROJECTS\Synaptrix-gigshield\app\lib\screens'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
print("Patched dart files.")

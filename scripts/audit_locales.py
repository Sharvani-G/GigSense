import os
import re
import sys

def audit_keys():
    # Find strings.dart relatively from the script location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    strings_file = os.path.normpath(os.path.join(script_dir, "../app/lib/i18n/strings.dart"))
    
    if not os.path.exists(strings_file):
        # Fallback to current working directory layout
        strings_file = os.path.normpath(os.path.join(os.getcwd(), "app/lib/i18n/strings.dart"))
        
    if not os.path.exists(strings_file):
        print(f"Error: Could not find strings.dart at: {strings_file}")
        sys.exit(1)
        
    print(f"Auditing translation file: {strings_file}")
    
    with open(strings_file, "r", encoding="utf-8") as f:
        content = f.read()

    langs = ['en', 'hi', 'kn', 'te', 'ta', 'ml']
    maps = {}
    
    for lang in langs:
        lang_start = content.find(f"'{lang}': {{")
        if lang_start == -1:
            print(f"Error: Could not find language block for '{lang}'")
            continue
        
        brace_count = 0
        block = ""
        started = False
        for char in content[lang_start:]:
            if char == '{':
                brace_count += 1
                started = True
            elif char == '}':
                brace_count -= 1
                if started and brace_count == 0:
                    block += char
                    break
            if started:
                block += char
        
        matches = re.findall(r"'([^']+)':\s*'([^']*)'", block)
        maps[lang] = {k: v for k, v in matches}

    en_keys = set(maps.get('en', {}).keys())
    print(f"Loaded English map with {len(en_keys)} keys.\n")

    has_gaps = False
    for lang in langs:
        if lang == 'en':
            continue
        lang_map = maps.get(lang, {})
        lang_keys = set(lang_map.keys())
        
        missing = en_keys - lang_keys
        empty = {k for k in en_keys if k in lang_map and not lang_map[k]}
        
        if missing or empty:
            has_gaps = True
            print(f"--- Language: {lang} ---")
            if missing:
                print(f"Missing {len(missing)} keys: {sorted(list(missing))}")
            if empty:
                print(f"Empty {len(empty)} keys: {sorted(list(empty))}")
            print()
            
    if not has_gaps:
        print("Success: All languages have 100% key parity with English!")
        sys.exit(0)
    else:
        print("Failure: Missing or empty keys found.")
        sys.exit(1)

if __name__ == "__main__":
    audit_keys()

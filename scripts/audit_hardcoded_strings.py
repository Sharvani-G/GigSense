import os
import re
import sys

# Configure UTF-8 stdout to prevent Windows CP1252 encoding crashes
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def strip_comments(content):
    content = re.sub(r'/\*[\s\S]*?\*/', '', content)
    lines = content.split('\n')
    clean_lines = []
    for line in lines:
        in_quote = False
        quote_char = None
        comment_idx = -1
        for idx, char in enumerate(line):
            if char in ["'", '"']:
                if not in_quote:
                    in_quote = True
                    quote_char = char
                elif quote_char == char:
                    escaped = False
                    back_idx = idx - 1
                    while back_idx >= 0 and line[back_idx] == '\\':
                        escaped = not escaped
                        back_idx -= 1
                    if not escaped:
                        in_quote = False
                        quote_char = None
            elif char == '/' and not in_quote:
                if idx + 1 < len(line) and line[idx + 1] == '/':
                    comment_idx = idx
                    break
        if comment_idx != -1:
            clean_lines.append(line[:comment_idx])
        else:
            clean_lines.append(line)
    return '\n'.join(clean_lines)

def parse_first_argument(args_str):
    in_quote = False
    quote_char = None
    triple_quote = False
    paren_depth = 0
    bracket_depth = 0
    brace_depth = 0
    
    arg_chars = []
    
    idx = 0
    while idx < len(args_str):
        char = args_str[idx]
        
        if not in_quote and (args_str[idx:idx+3] == "'''" or args_str[idx:idx+3] == '"""'):
            in_quote = True
            triple_quote = True
            quote_char = args_str[idx:idx+3]
            arg_chars.append(quote_char)
            idx += 3
            continue
        elif in_quote and triple_quote and args_str[idx:idx+3] == quote_char:
            in_quote = False
            triple_quote = False
            arg_chars.append(quote_char)
            quote_char = None
            idx += 3
            continue
            
        if not in_quote and char in ["'", '"']:
            in_quote = True
            quote_char = char
            arg_chars.append(char)
            idx += 1
            continue
        elif in_quote and not triple_quote and char == quote_char:
            escaped = False
            back_idx = len(arg_chars) - 1
            while back_idx >= 0 and arg_chars[back_idx] == '\\':
                escaped = not escaped
                back_idx -= 1
            if not escaped:
                in_quote = False
                quote_char = None
            arg_chars.append(char)
            idx += 1
            continue
            
        if not in_quote:
            if char == '(':
                paren_depth += 1
            elif char == ')':
                paren_depth -= 1
            elif char == '[':
                bracket_depth += 1
            elif char == ']':
                bracket_depth -= 1
            elif char == '{':
                brace_depth += 1
            elif char == '}':
                brace_depth -= 1
            elif char == ',' and paren_depth == 0 and bracket_depth == 0 and brace_depth == 0:
                break
                
        arg_chars.append(char)
        idx += 1
        
    return "".join(arg_chars).strip()

def check_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        original_content = f.read()
        
    content = strip_comments(original_content)
    
    violations = []
    
    line_starts = [0]
    for m in re.finditer('\n', original_content):
        line_starts.append(m.end())
        
    original_lines = original_content.split('\n')
    lines = content.split('\n')
    for line_idx, line in enumerate(lines):
        line_num = line_idx + 1
        if 'audit-ignore' in original_lines[line_idx]:
            continue
        for match in re.finditer(r'\bText\(', line):
            start_pos = match.start()
            remaining_content = "\n".join(lines[line_idx:])[start_pos + 5:]
            
            paren_depth = 1
            in_quote = False
            quote_char = None
            triple_quote = False
            args_chars = []
            
            idx = 0
            while idx < len(remaining_content) and paren_depth > 0:
                char = remaining_content[idx]
                
                if not in_quote and (remaining_content[idx:idx+3] == "'''" or remaining_content[idx:idx+3] == '"""'):
                    in_quote = True
                    triple_quote = True
                    quote_char = remaining_content[idx:idx+3]
                    args_chars.append(quote_char)
                    idx += 3
                    continue
                elif in_quote and triple_quote and remaining_content[idx:idx+3] == quote_char:
                    in_quote = False
                    triple_quote = False
                    args_chars.append(quote_char)
                    quote_char = None
                    idx += 3
                    continue
                    
                if not in_quote and char in ["'", '"']:
                    in_quote = True
                    quote_char = char
                    args_chars.append(char)
                    idx += 1
                    continue
                elif in_quote and not triple_quote and char == quote_char:
                    escaped = False
                    back_idx = len(args_chars) - 1
                    while back_idx >= 0 and args_chars[back_idx] == '\\':
                        escaped = not escaped
                        back_idx -= 1
                    if not escaped:
                        in_quote = False
                        quote_char = None
                    args_chars.append(char)
                    idx += 1
                    continue
                    
                if not in_quote:
                    if char == '(':
                        paren_depth += 1
                    elif char == ')':
                        paren_depth -= 1
                        if paren_depth == 0:
                            break
                            
                args_chars.append(char)
                idx += 1
                
            args_str = "".join(args_chars).strip()
            first_arg = parse_first_argument(args_str)
            
            is_literal = False
            check_arg = first_arg
            if check_arg.startswith('r') or check_arg.startswith('R'):
                check_arg = check_arg[1:].strip()
                
            if (check_arg.startswith("'") and check_arg.endswith("'")) or \
               (check_arg.startswith('"') and check_arg.endswith('"')):
                is_literal = True
                
            if is_literal:
                stripped_literal = check_arg
                if stripped_literal.startswith("'''") or stripped_literal.startswith('"""'):
                    stripped_literal = stripped_literal[3:-3]
                else:
                    stripped_literal = stripped_literal[1:-1]
                
                # REFINEMENT: Remove Dart string interpolations (${...} and $var) before checking for letters
                # to prevent flagging variables as hardcoded strings.
                stripped_literal = re.sub(r'\$\{.*?\}', '', stripped_literal)
                stripped_literal = re.sub(r'\$[a-zA-Z0-9_]+', '', stripped_literal)
                
                if re.search(r'[a-zA-Z]', stripped_literal):
                    violations.append((line_num, first_arg))
                    
    return violations

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    screens_dir = os.path.normpath(os.path.join(script_dir, "../app/lib/screens"))
    
    if not os.path.exists(screens_dir):
        screens_dir = os.path.normpath(os.path.join(os.getcwd(), "app/lib/screens"))
        
    if not os.path.exists(screens_dir):
        print(f"Error: Could not find screens directory at {screens_dir}")
        sys.exit(1)
        
    print(f"Auditing Flutter screen files in: {screens_dir}\n")
    
    all_violations = {}
    
    for root, dirs, files in os.walk(screens_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                violations = check_file(filepath)
                if violations:
                    rel_path = os.path.relpath(filepath, screens_dir)
                    all_violations[rel_path] = violations
                    
    if all_violations:
        print("Failure: Hardcoded user-facing strings found in Text widgets!\n")
        for filepath, list_viols in sorted(all_violations.items()):
            print(f"File: [screens/{filepath}]")
            for line_num, arg in list_viols:
                print(f"  Line {line_num}: Text({arg})")
            print()
        sys.exit(1)
    else:
        print("Success: Zero hardcoded user-facing strings found in Text widgets!")
        sys.exit(0)

if __name__ == '__main__':
    main()

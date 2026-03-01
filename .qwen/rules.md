# Global Rules for This Project

## Shell Command Syntax (CRITICAL)

**This project is on Windows (win32). ALWAYS use Windows cmd.exe or PowerShell syntax, NEVER bash/unix syntax.**

### Common Mistakes to Avoid

❌ **DON'T use bash syntax:**
```bash
command1 & command2           # bash background/chain
command > /dev/null 2>&1      # unix null device
command >nul & other          # mixed syntax (WRONG)
$VAR                          # bash variable
$(command)                    # bash command substitution
```

✅ **DO use Windows cmd.exe syntax:**
```cmd
command1 && command2          # chain (success only)
command1 & command2           # chain (always)
command >nul 2>&1             # redirect all output to null
%VAR%                         # cmd variable
start "" "path\to\app.exe"    # launch application
```

✅ **Or use PowerShell:**
```powershell
command1; command2            # chain commands
$var                          # PowerShell variable
Start-Process "path\to\app.exe"
```

### Specific Patterns

| Task | Bash (WRONG) | Windows cmd (CORRECT) |
|------|--------------|----------------------|
| Suppress output | `cmd > /dev/null 2>&1` | `cmd >nul 2>&1` |
| Chain commands | `cmd1 & cmd2` | `cmd1 && cmd2` or `cmd1 & cmd2` |
| Background process | `cmd &` | `start "" "cmd.exe"` |
| Check exit code | `$?` | `%ERRORLEVEL%` |
| Environment var | `$VAR` or `${VAR}` | `%VAR%` |

### Common Error Messages

If you see these, you're using wrong syntax:
- `ERROR: Input redirection is not supported` - Using bash redirection in cmd
- `The syntax of the command is incorrect` - Mixed bash/cmd syntax
- `'command' is not recognized` - Using unix commands on Windows

### Build Commands for This Project

**PC Server (Rust):**
```cmd
cd pc && cargo build --release
```

**Mobile App (Flutter - Windows):**
```cmd
cd mobile && flutter build windows --debug
```

**Mobile App (Flutter - Android):**
```cmd
cd mobile && flutter build apk --debug
```

**Clean and rebuild:**
```cmd
cd mobile && flutter clean && flutter pub get && flutter build windows --debug
```

---

## Testing Requirements

**Before claiming something works:**
1. Actually run the test yourself
2. Verify the output
3. Don't assume - test!

**For connection testing:**
1. Create test scripts (Python/PowerShell)
2. Run both server and client tests
3. Report actual results, not expectations

---

## Documentation Standards

1. **Use Windows paths** in README (`\` not `/`)
2. **Full paths** - don't truncate or abbreviate
3. **Test all commands** before documenting
4. **Include troubleshooting** sections

---

*Last Updated: 2026-03-01*
*Reason: Repeated bash/cmd syntax errors throughout development session*

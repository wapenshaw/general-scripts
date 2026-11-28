# Tool selection: do not shell out for what a dedicated tool does

`bash` rejects these commands before they run with `Tool "bash" is blocked by tool policy.`, and each rejected call wastes a turn. Pick the dedicated tool first; do not try the shell form to see whether it is allowed.

| Not in `bash`                                                 | Use                                                    |
|---------------------------------------------------------------|--------------------------------------------------------|
| `cat`, `head`, `tail`, `less`, `more`, `bat`                  | `read` (ranges `file:50-80`, last lines `file:-20`)    |
| `grep`, `rg`, `ag`, `ack`, `findstr`, `Select-String`         | `grep` (`path` takes `;`-separated files, dirs, globs) |
| `find`, `fd`, `ls -R`, `rg --files`, `tree`                   | `glob`                                                 |
| `sed -i`, `perl -i`, `awk -i inplace`                         | `edit`                                                 |
| `echo ... > file`, `cat <<EOF > file`, `tee file`             | `write` (new file) or `edit` (existing file)           |
| `nohup`, trailing `&`, dev servers, watchers, `tail -f`       | `bash` with `name` (a managed service)                 |

- Every command in a chain is checked: one blocked form after `;`, `&&`, `||` or a newline rejects the whole call, and a `cd dir &&` prefix changes nothing. Split the chain: dedicated-tool calls for the blocked parts, `bash` only for the rest. `| head`/`| tail` are unnecessary; `read` and `grep` return bounded output.
- After a rejection, follow the `Reason:` line and switch tools. Never retry a reworded shell form (another binary, `xargs`, `sh -c`) to get past the check.
- Batch independent `read`, `grep` and `glob` calls in one turn instead of chaining them in one `bash` command.
- `bash` is for what has no dedicated tool: `git`, `gh`, build/test runners, package managers, process control.

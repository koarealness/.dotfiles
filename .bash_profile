# ~/.bash_profile: Executed for login shells.
# For a comprehensive setup, this file sources other configuration files.

# Source all rc files and profile extensions.
# - .path: Manages the command-line PATH in an architecture-aware way.
# - .bash_prompt: Contains the prompt configuration.
# - .exports: Defines environment variables.
# - .aliases: Contains shell aliases.
# - .functions: Holds custom shell functions.
# - .extra: For personal, non-committed settings.
for file in ~/.{path,bash_prompt,exports,aliases,functions,extra}; do
	if [ -r "$file" ] && [ -f "$file" ]; then
		source "$file"
	fi
done
unset file

# --- Shell Options ---

# Case-insensitive globbing (e.g., `ls *.jpg` matches `.JPG`).
shopt -s nocaseglob

# Append to the Bash history file, rather than overwriting it.
shopt -s histappend

# Autocorrect typos in path names when using `cd`.
shopt -s cdspell

# Enable modern Bash features if available (Bash 4+).
# - autocd: Enter a directory name without `cd`.
# - globstar: Recursive globbing with `**`.
for option in autocd globstar; do
	shopt -s "$option" 2> /dev/null
done

# --- Bash Completion ---

# Determine Homebrew prefix based on architecture.
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

# Load Bash completion if installed via Homebrew.
if [ -f "${HOMEBREW_PREFIX}/share/bash-completion/bash_completion" ]; then
  source "${HOMEBREW_PREFIX}/share/bash-completion/bash_completion"
fi

# --- Custom Completions ---

# Enable tab completion for `g` as an alias for `git`.
if type _git &> /dev/null; then
	complete -o default -o nospace -F _git g
fi

# Add tab completion for SSH hostnames from ~/.ssh/config.
if [ -e "$HOME/.ssh/config" ]; then
	complete -o "default" -o "nospace" \
		-W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" \
		scp sftp ssh
fi

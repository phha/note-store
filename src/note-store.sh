#!/usr/bin/env bash

# Copyright (C) 2012 - 2017 Jason A. Donenfeld <Jason@zx2c4.com> and
# Philipp Hack <philipp.hack@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

PREFIX="${NOTE_STORE_DIR:-$HOME/note-store}"
SUFFIX="${NOTE_STORE_SUFFIX:-md}"
EXTENSIONS="${NOTE_STORE_EXTENSIONS_DIR:-$PREFIX/.extensions}"

#
# BEGIN helper functions
#

check_sneaky_paths() {
	  local path
	  for path in "$@"; do
		    [[ $path =~ /\.\.$ || $path =~ ^\.\./ || $path =~ /\.\./ || $path =~ ^\.\.$ ]] && die "Error: You've attempted to pass a sneaky path to notes. Go home."
	  done
}

git_add_file() {
	  [[ -n $INNER_GIT_DIR ]] || return
	  git -C "$INNER_GIT_DIR" add "$1" || return
	  [[ -n $(git -C "$INNER_GIT_DIR" status --porcelain "$1") ]] || return
	  git_commit "$2"
}

git_commit() {
	[[ -n $INNER_GIT_DIR ]] || return
	git -C "$INNER_GIT_DIR" commit -m "$1"
}

set_git() {
	INNER_GIT_DIR="${1%/*}"
	while [[ ! -d $INNER_GIT_DIR && ${INNER_GIT_DIR%/*}/ == "${PREFIX%/}/"* ]]; do
		INNER_GIT_DIR="${INNER_GIT_DIR%/*}"
	done
	[[ $(git -C "$INNER_GIT_DIR" rev-parse --is-inside-work-tree 2>/dev/null) == true ]] || INNER_GIT_DIR=""
}

init() {
	  [[ -n $PREFIX ]] && check_sneaky_paths "$PREFIX"
	  [[ -n $PREFIX && ! -d $PREFIX && -e $PREFIX ]] && die "Error: $PREFIX exists but is not a directory."
	  [[ -n $PREFIX && -d $PREFIX ]] && return
    mkdir -p "$PREFIX"
    echo "Note store \"$PREFIX\" initialized."
}

die() {
	echo "$@" >&2
	exit 1
}

yesno() {
	[[ -t 0 ]] || return 0
	local response
	read -r -p "$1 [y/N] " response
	[[ $response == [yY] ]] || exit 1
}

#
# END helper functions
#

#
# BEGIN platform definable
#
GETOPT="getopt"

source "$(dirname "$0")/platform/$(uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]').sh" 2>/dev/null # PLATFORM_FUNCTION_FILE
#
# END platform definable
#


#
# BEGIN subcommand functions
#

cmd_show() {
	[[ $# -eq 0 || $# -eq 1 ]] || die "Usage: $PROGRAM $COMMAND [note-title]"

	local path="$1"
	local notefile="$PREFIX/$path.${SUFFIX}"
	check_sneaky_paths "$path"

	if [[ -f $notefile ]]; then
    cat "$notefile" || exit $?
	elif [[ -d $PREFIX/$path ]]; then
		if [[ -z $path ]]; then
			echo "Notes"
		else
			echo "${path%\/}"
		fi
		tree -C -l --noreport "$PREFIX/$path" | tail -n +2 | sed -E "s/\.${SUFFIX}(\x1B\[[0-9]+m)?( ->|$)/\1\2/g" # remove extension at end of line, but keep colors
	elif [[ -z $path ]]; then
		die "Error: note store is empty."
	else
		die "Error: $path is not in the note store."
	fi
}

cmd_insert() {
	local opts append=0 force=0
	opts="$($GETOPT -o af -l append,force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-a|--append) append=1; shift ;;
		-f|--force) force=1; shift ;;
    --) shift; break ;;
	esac done
	local path="${1%/}"
	local notefile="$PREFIX/$path.${SUFFIX}"

	[[ $err -ne 0 || $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND [--append,-a] [--force,-f] note-title"
	[[ -e $notefile && ( $force -eq 0 || $append -eq 0 ) ]] && die "Note already exists and neither force nor append was set."

  init
	check_sneaky_paths "$path"
	set_git "$notefile"

	mkdir -p -v "$PREFIX/$(dirname "$path")"
  if [[ -t 0 ]]; then
    echo "Enter contents of $path and press Ctrl+D when finished:"
    echo
  fi
  local action="Add"
  if [[ $append -eq 1 ]]; then
    [[ -f "notefile" ]] && action="Append to"
    cat >>"$notefile"
  else
    [[ -f "notefile" ]] && action="Overwrite"
    cat >"$notefile"
  fi
	git_add_file "$notefile" "$action note $path"
}

cmd_edit() {
  init
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND note-title"

	local path="${1%/}"
	check_sneaky_paths "$path"
	mkdir -p -v "$PREFIX/$(dirname "$path")"
	local notefile="$PREFIX/$path.${SUFFIX}"
	set_git "$notefile"

	local action="Add"
	[[ -f $notefile ]] && action="Edit"
	${EDITOR:-vi} "$notefile"
	git_add_file "$notefile" "$action $path using ${EDITOR:-vi}."
}

cmd_delete() {
	local opts recursive="" force=0
	opts="$($GETOPT -o rf -l recursive,force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-r|--recursive) recursive="-r"; shift ;;
		-f|--force) force=1; shift ;;
		--) shift; break ;;
	esac done
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND [--recursive,-r] [--force,-f] note-title"
	local path="$1"
	check_sneaky_paths "$path"
  local notedir="$PREFIX/${path%/}"
  local notefile="$PREFIX/$path.${SUFFIX}"
  [[ -f $notefile && -d $notedir && $path == */ || ! -f $notefile ]] && notefile="${notedir%/}/"
  [[ -e $notefile ]] || die "error: $path is not in the note store."
  set_git "$notefile"

  [[ $force -eq 1 ]] || yesno "are you sure you would like to delete $path?"

  rm $recursive -f -v "$notefile"
  set_git "$notefile"
  if [[ -n $INNER_GIT_DIR && ! -e $notefile ]]; then
    git -C "$INNER_GIT_DIR" rm -qr "$notefile"
    set_git "$notefile"
    git_commit "remove $path from store."
  fi
  rmdir -p "${notefile%/*}" 2>/dev/null
}

cmd_copy_move() {
	local opts move=1 force=0
	[[ $1 == "copy" ]] && move=0
	shift
	opts="$($GETOPT -o f -l force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-f|--force) force=1; shift ;;
		--) shift; break ;;
	esac done
	[[ $# -ne 2 ]] && die "Usage: $PROGRAM $COMMAND [--force,-f] old-path new-path"
	check_sneaky_paths "$@"
	local old_path="$PREFIX/${1%/}"
	local old_dir="$old_path"
	local new_path="$PREFIX/$2"

	if ! [[ -f $old_path.${SUFFIX} && -d $old_path && $1 == */ || ! -f $old_path.${SUFFIX} ]]; then
		old_dir="${old_path%/*}"
		old_path="${old_path}.${SUFFIX}"
	fi
	echo "$old_path"
	[[ -e $old_path ]] || die "Error: $1 is not in the note store."

	mkdir -p -v "${new_path%/*}"
	[[ -d $old_path || -d $new_path || $new_path == */ ]] || new_path="${new_path}.${SUFFIX}"

	local interactive="-i"
	[[ ! -t 0 || $force -eq 1 ]] && interactive="-f"

	set_git "$new_path"
	if [[ $move -eq 1 ]]; then
		mv $interactive -v "$old_path" "$new_path" || exit 1

		set_git "$new_path"
		if [[ -n $INNER_GIT_DIR && ! -e $old_path ]]; then
			git -C "$INNER_GIT_DIR" rm -qr "$old_path" 2>/dev/null
			set_git "$new_path"
			git_add_file "$new_path" "Rename ${1} to ${2}."
		fi
		set_git "$old_path"
		if [[ -n $INNER_GIT_DIR && ! -e $old_path ]]; then
			git -C "$INNER_GIT_DIR" rm -qr "$old_path" 2>/dev/null
			set_git "$old_path"
			[[ -n $(git -C "$INNER_GIT_DIR" status --porcelain "$old_path") ]] && git_commit "Remove ${1}."
		fi
		rmdir -p "$old_dir" 2>/dev/null
	else
		cp $interactive -r -v "$old_path" "$new_path" || exit 1
		git_add_file "$new_path" "Copy ${1} to ${2}."
	fi
}

cmd_git() {
  init
	set_git "$PREFIX/"
	if [[ $1 == "init" ]]; then
		INNER_GIT_DIR="$PREFIX"
		git -C "$INNER_GIT_DIR" "$@" || exit 1
		git_add_file "$PREFIX" "Add current contents of note store."
	elif [[ -n $INNER_GIT_DIR ]]; then
		git -C "$INNER_GIT_DIR" "$@"
	else
		die "Error: the note store is not a git repository. Try \"$PROGRAM git init\"."
	fi
}

cmd_grep() {
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND search-string"
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND search-string"
	local search="$1" notefile grepresults
	while read -r -d "" notefile; do
		grepresults="$(cat "$notefile" | grep --color=always "$search")"
		[[ $? -ne 0 ]] && continue
		notefile="${notefile%.${SUFFIX}}"
		notefile="${notefile#$PREFIX/}"
		local notefile_dir="${notefile%/*}/"
		[[ $notefile_dir == "${notefile}/" ]] && notefile_dir=""
		notefile="${notefile##*/}"
		printf "\e[94m%s\e[1m%s\e[0m:\n" "$notefile_dir" "$notefile"
		echo "$grepresults"
	done < <(find -L "$PREFIX" -path '*/.git' -prune -o -iname \*.${SUFFIX} -print0)
}

cmd_find() {
	[[ $# -eq 0 ]] && die "Usage: $PROGRAM $COMMAND note-titles..."
	IFS="," eval 'echo "Search Terms: $*"'
	local terms="*$(printf '%s*|*' "$@")"
	tree -C -l --noreport -P "${terms%|*}" --prune --matchdirs --ignore-case "$PREFIX" | tail -n +2 | sed -E "s/\.${SUFFIX}(\x1B\[[0-9]+m)?( ->|$)/\1\2/g"
}

cmd_extension_or_show() {
	if ! cmd_extension "$@"; then
		COMMAND="show"
		cmd_show "$@"
	fi
}

SYSTEM_EXTENSION_DIR=""
cmd_extension() {
	check_sneaky_paths "$1"
	local user_extension system_extension extension
	[[ -n $SYSTEM_EXTENSION_DIR ]] && system_extension="$SYSTEM_EXTENSION_DIR/$1.bash"
	[[ $NOTE_STORE_ENABLE_EXTENSIONS == true ]] && user_extension="$EXTENSIONS/$1.bash"
	if [[ -n $user_extension && -f $user_extension && -x $user_extension ]]; then
		extension="$user_extension"
	elif [[ -n $system_extension && -f $system_extension && -x $system_extension ]]; then
		extension="$system_extension"
	else
		return 1
	fi
	shift
	source "$extension" "$@"
	return 0
}

cmd_usage() {
	cmd_version
	echo
	cat <<-_EOF
	Usage:
	    $PROGRAM [ls] [subfolder]
	        List notes.
	    $PROGRAM find note-titles...
	    	List notes that match note-titles.
	    $PROGRAM [show] note-title
	        Show existing note.
	    $PROGRAM grep search-string
	        Search for notes containing search-string.
	    $PROGRAM insert [--append,-a] [--force,-f] note-title
	        Insert new note from stdin. Do not overwrite existing
          note unless forced. Optionally append to existing note.
	    $PROGRAM edit note
	        Insert a new note or edit an existing note using ${EDITOR:-vi}.
	    $PROGRAM rm [--recursive,-r] [--force,-f] note-title
	        Remove existing note or directory, optionally forcefully.
	    $PROGRAM mv [--force,-f] old-path new-path
	        Renames or moves old-path to new-path, optionally forcefully.
	    $PROGRAM cp [--force,-f] old-path new-path
	        Copies old-path to new-path, optionally forcefully.
	    $PROGRAM git git-command-args...
	        If the note store is a git repository, execute a git command
	        specified by git-command-args.
	    $PROGRAM help
	        Show this text.
	    $PROGRAM version
	        Show version information.

	More information may be found in the notes(1) man page.
	_EOF
}

cmd_version() {
	echo $PROGRAM: the simple unix note manager v1.0.0
}

#
# END subcommand functions
#

PROGRAM="${0##*/}"
COMMAND="$1"

case "$1" in
	  help|--help) shift;		cmd_usage "$@" ;;
	  version|--version) shift;	cmd_version "$@" ;;
	  show|ls|list) shift;		cmd_show "$@" ;;
	  find|search) shift;		cmd_find "$@" ;;
	  grep) shift;			cmd_grep "$@" ;;
	  insert|add) shift;		cmd_insert "$@" ;;
	  edit) shift;			cmd_edit "$@" ;;
	  delete|rm|remove) shift;	cmd_delete "$@" ;;
	  rename|mv) shift;		cmd_copy_move "move" "$@" ;;
	  copy|cp) shift;			cmd_copy_move "copy" "$@" ;;
	  git) shift;			cmd_git "$@" ;;
	  *)				cmd_extension_or_show "$@" ;;
esac
exit 0

# @Author: Dreamcat4
# @Date:   2019-08-04 12:27:23
# @Last Modified by:   Dreamcat4
# @Last Modified time: 2019-08-05 18:47:51


# _tsession_folder()
# {
#   # check that we have manually created a symlink to the teleport cluster's log / sessions folder
#   _teleport_home="${HOME}/.teleport"
#   _sessions_folder="${_teleport_home}/sessions"

#   if [ ! -L "$_sessions_folder" ] && [ ! -d "$_sessions_folder" ]; then
#     echo "error: no symlink to sessions folder \"$_sessions_folder\""
#     echo "usually this is found at \${TELEPORT_HOME}/data/log/\${CLUSTER_GUID}/sessions/default"
#     return 1
#   fi
# }

# _teleport_home="${HOME}/.teleport"

# You need to set these to point to your teleport data folder
_teleport_logs="/var/lib/teleport/data/log"

# set your favorite browser executable, to open logs into after ansi2html
# _browser="firefox"


if [ ! "$_browser" ]; then
  for _b in firefox chromium-browser chrome; do
    if [ "$(command -v $_b)" ]; then
      _browser="$_b"
      break
    fi
  done
fi



_t_get_tmp()
{
  if [ "$XDG_RUNTIME_DIR" ]; then
    echo "$XDG_RUNTIME_DIR"
  else
    _uid="$(id -u)"
    if [ -d "/run/user/${_uid}" ]; then
      echo "/run/user/${_uid}"
    else
      echo "/tmp"
    fi
  fi
}

_tgrep()
{
  # _tsession_folder
  # zgrep "$@" ${_teleport_home}/sessions/*chunks.gz | sed -e "s,\x1B\[[0-9;]*[a-lA-Ln-zN-Z],,g" -e "s,\e\[?25[hl],,g"

  _chunks_files="$(find "$_teleport_logs" -name "*.chunks.gz")"
  zgrep "$@" $_chunks_files | sed -e "s,\x1B\[[0-9;]*[a-lA-Ln-zN-Z],,g" -e "s,\e\[?25[hl],,g"
}

tgrep()
{
  # * grep the teleport log files
  # * takes grep flags and syntax just omit the <files> at the end
  # * tries to remove any troublesome escape or control characters
  # * outputs results to stdout, just like grep - because it is grep!
  # * also copy each matching session guid to clipboard

  _tgrep "$@"

  # export matching sessions as tgrep_guids

  # _matches="$(zgrep -l "$@" ${_teleport_home}/sessions/*chunks.gz)"
  # _chunks_files="$(find "$_teleport_logs" -name "*.chunks.gz")"
  _matches="$(zgrep -l "$@" $_chunks_files)"

  tgrep_guids="$(echo "$_matches" | grep -o -E "[0-9a-fA-F-]{36}")"
  export tgrep_guids

  #  copy matching session guids to clipboard
  if [ "$DISPLAY" ] && [ "$(command -v xclip)" ]; then
    echo "$tgrep_guids" | xclip -selection clipboard -i &> /dev/null
  fi

  # restore missing cursor
  printf "\e[?25h"
}

tless()
{
  # * tgrep then open in less program each matching log file in turn
  # * takes grep flags and syntax just like tgrep
  # * tries to remove any troublesome escape or control characters
  # * also copy each matching session guid to clipboard

  _less_args="$LESS_ARGS"
  _matches="$(_tgrep -l "$@")"

  if [ "$_matches" ]; then

    less -r $_less_args $_matches

    tgrep_guids="$(echo "$_matches" | grep -o -E "[0-9a-fA-F-]{36}")"
    tless_guids="$tgrep_guids"
    export tgrep_guids tless_guids

    #  copy matching session guids to clipboard
    if [ "$DISPLAY" ] && [ "$(command -v xclip)" ]; then
      echo "$tgrep_guids" | xclip -selection clipboard -i &> /dev/null
    fi

    # restore missing cursor
    printf "\e[?25h"
  else
    echo "no matches found"
  fi
}

_topen()
{
  # * tgrep then open in your \$_browser each matching log file
  # * takes a list of session guids to open as its arguments
  # * tries to remove any troublesome escape or control characters
  # * output is converted to a colorized html file with ansi2html
  # * also copy each matching session guid to clipboard

  _pwd="$PWD"

  # take session guids as input,
  _guids="$@"
  [ "$_guids" ] || return 1

  # _tsession_folder

  if [ ! -d "$_tmpdir" ]; then
    _tmpdir="$(mktemp -d --dry-run --tmpdir="$(_t_get_tmp)")"
    mkdir -p "$_tmpdir"
    chmod 0700 "$_tmpdir"
  fi
  cd "$_tmpdir"

  _all_chunks_file="${_tmpdir}/all.chunks"
  printf "" > $_all_chunks_file

  unset _files _html_files
  for _guid in $_guids; do

    _chunks_files="$(find "$_teleport_logs" -name "*.chunks.gz")"
    _chunks_gz="$(echo "$_chunks_files" | grep "$_guid")"

    # echo "$_chunks_files"

    if [ "$_chunks_gz" ]; then
      _chunks_file="${_sessions_folder}/${_chunks_gz}"
      # ls -lsa "${_sessions_folder}/${_chunks_gz}"
      # ls -lsa "${_chunks_file}"

      # decompress them into a temp folder
      if [ -e "$_chunks_file" ]; then
        # _file="$(basename ${_chunks_file%.gz})"
        _file="${_tmpdir}/$(basename ${_chunks_file%.gz})"
        echo "y" | gzip -q -d -k -c "$_chunks_file" > "${_file}"

        # sed -i -e "s,\x1B\[[0-9;]*[a-lA-Ln-zN-Z],,g" -e "s,\e\[?25[hl],,g"  "$_chunks_file"

        ansi2html --contrast --style "body {background-color: rgb(37, 35, 35);};" --title "$_file" < "$_file" > "${_file}.html"
        sed -i -e "s|pre {|pre { font-family: \"Droid Sans Mono\",\"monospace\",monospace,\"Droid Sans Fallback\";line-height: 17px;font-size: 14px;|" "${_file}.html"

        echo "file: ${_file}:" >> $_all_chunks_file
        cat "$_file" >> $_all_chunks_file
        printf "\n\n\n\n" >> $_all_chunks_file

        _files="$_files $_file"
        _html_files="$_html_files ${_file}.html"
      else
        echo "error: could not resolve chunks file"
      fi

    else
      # its a guid
      # ls -lsa "$_sessions_folder"/*"$_guid"*
      echo "not found"
    fi

  done

  if [ "$(echo "$_files" | wc -w)" -gt 1 ]; then

    _all_chunks_file_html=${_all_chunks_file}.html
    ansi2html --contrast --style "body {background-color: rgb(37, 35, 35);};" --title "$_all_chunks_file" < "$_all_chunks_file" > "$_all_chunks_file_html"
    sed -i -e "s|pre {|pre { font-family: \"Droid Sans Mono\",\"monospace\",monospace,\"Droid Sans Fallback\";line-height: 17px;font-size: 14px;|" "$_all_chunks_file_html"

    # --style "$(cat ${_teleport_home}/terminal.css 2>/dev/null)"

    _open_tmpdir="$_tmpdir"
  else
    unset _all_chunks_file _all_chunks_file_html _open_tmpdir
  fi

  _output="$_all_chunks_file ${_files# *}"
  echo "${_output# *}"

  # subl -w "$_all_chunks_file" $_files

  $_browser ${_all_chunks_file_html} $_html_files $_open_tmpdir 2> /dev/null &
  # $_browser "${_all_chunks_file_html}" $_html_files &
  # $_browser $_html_files &
  _pid="$!"
  sleep 1
  wait $_pid

  while [ "$_pid" ]; do
    _pid="$(ps -C $_browser -o pid=)"
    sleep 1
  done

  # # unfortunately - we cannot use xdg-open because it returns immediately
  # open "${_chunks_file%.gz}" &
  # _pids="${_pids} $!"
  # echo "$_pids"

  # handle cleanup
  cd "$_pwd"
  rm -rf "$_tmpdir"
}

topen()
{
  _topen "$@" &
}


tgopen()
{
  # * combines tgrep with topen, to directly open matches sessions in \$_browser
  # * takes grep flags and syntax just like tgrep
  # * tries to remove any troublesome escape or control characters
  # * output is converted to a colorized html file with ansi2html
  # * also copy each matching session guid to clipboard

  _matches="$(_tgrep -l "$@")"

  if [ "$_matches" ]; then

    # _output="$(topen "$_matches")"
    topen "$_matches"

    tgrep_guids="$(echo "$_matches" | grep -o -E "[0-9a-fA-F-]{36}")"
    tless_guids="$tgrep_guids"
    export tgrep_guids tless_guids

    #  copy matching session guids to clipboard
    if [ "$DISPLAY" ] && [ "$(command -v xclip)" ]; then
      echo "$tgrep_guids" | xclip -selection clipboard -i &> /dev/null
    fi

    # # does not work until after login
    # for _guid in $tgrep_guids; do
    #   _urls="$_urls https://teleport.dkr:3080/web/player/cluster/teleport.dkr/sid/${_guid}"
    # done
    # firefox $_urls &

    # restore missing cursor
    printf "\e[?25h"

  else
    echo "no matches found"
  fi
}


tloghelp()
{
    cat <<- EOF

    tloghelp:

      * print this message

    tgrep:

      * grep the teleport log files
      * takes grep flags and syntax just omit the <files> at the end
      * tries to remove any troublesome escape or control characters
      * outputs results to stdout, just like grep - because it is grep!
      * also copy each matching session guid to clipboard

    tless:

      * tgrep then open in less program each matching log file in turn
      * takes grep flags and syntax just like tgrep
      * tries to remove any troublesome escape or control characters
      * also copy each matching session guid to clipboard

    topen:

      * tgrep then open in your \$_browser each matching log file
      * takes a list of session guids to open as its arguments
      * tries to remove any troublesome escape or control characters
      * output is converted to a colorized html file with ansi2html
      * also copy each matching session guid to clipboard

    tgopen:
      * combines tgrep with topen, to directly open matches sessions in \$_browser
      * takes grep flags and syntax just like tgrep
      * tries to remove any troublesome escape or control characters
      * output is converted to a colorized html file with ansi2html
      * also copy each matching session guid to clipboard

    Examples:

      # grep for something across all the locally found teleport logs, outputs to stdout
      tgrep -i "my search string"

      # open matching sessions in the program less, with ansi colorized output
      tless -i "my search string"

      # get (from the X windows clipboard) the list of session guids where grep found a match
      _teleport_session_guids="\$(xclip -selection clipboard -o)"

      # run those session logs through ansi2html, in a tmp folder, open in \$_browser
      topen \$_teleport_session_guids

      # perform a tgrep, and then directly open the matching session logs in the browser instead of stdout
      tgopen -i "my search string"

EOF
}






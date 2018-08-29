#!/bin/bash
#
# ble-autoload "$_ble_base/lib/core-complete.sh" ble/widget/complete
#

ble-import "$_ble_base/lib/core-syntax.sh"

_ble_complete_rex_rawparamx='^('$_ble_syntax_bash_simple_rex_element'*)\$[a-zA-Z_][a-zA-Z_0-9]*$'

function ble-complete/string#search-longest-suffix-in {
  local needle=$1 haystack=$2
  local l=0 u=${#needle}
  while ((l<u)); do
    local m=$(((l+u)/2))
    if [[ $haystack == *"${needle:m}"* ]]; then
      u=$m
    else
      l=$((m+1))
    fi
  done
  ret=${needle:l}
}
function ble-complete/string#common-suffix-prefix {
  local lhs=$1 rhs=$2
  if ((${#lhs}<${#rhs})); then
    local i n=${#lhs}
    for ((i=0;i<n;i++)); do
      ret=${lhs:i}
      [[ $rhs == "$ret"* ]] && return
    done
    ret=
  else
    local j m=${#rhs}
    for ((j=m;j>0;j--)); do
      ret=${rhs::j}
      [[ $lhs == *"$ret" ]] && return
    done
    ret=
  fi
}

## ble-complete 内で共通で使われるローカル変数
##
## @var COMP1 COMP2 COMPS COMPV
##   COMP1-COMP2 は補完対象の範囲を指定します。
##   COMPS は COMP1-COMP2 にある文字列を表し、
##   COMPV は COMPS の評価値 (クォート除去、簡単なパラメータ展開をした値) を表します。
##   COMPS に複雑な構造が含まれていて即時評価ができない場合は
##   COMPV は unset になります。必要な場合は [[ $comps_flags == *v* ]] で判定して下さい。
##   ※ [[ -v COMPV ]] は bash-4.2 以降です。
##
## @var comp_type
##   候補生成に関連するフラグ文字列。各フラグに対応する文字を含む。
##
##   a 文字 a を含む時、曖昧補完に用いる候補を生成する。
##     曖昧一致するかどうかは呼び出し元で判定されるので、
##     曖昧一致する可能性のある候補をできるだけ多く生成すれば良い。
##
##   i 文字 i を含む時、大文字小文字を区別しない補完候補生成を行う。
##
##   s 文字 s を含む時、ユーザの入力があっても中断しない事を表す。
##

function ble-complete/check-cancel {
  [[ $comp_type != *s* ]] && ble-decode/has-input
}

#==============================================================================
# action

## 既存の action
##
##   ble-complete/action:plain
##   ble-complete/action:word
##   ble-complete/action:file
##   ble-complete/action:progcomp
##   ble-complete/action:command
##   ble-complete/action:variable
##
## action の実装
##
## 関数 ble-complete/action:$ACTION/initialize
##   基本的に INSERT を設定すれば良い
##   @var[in    ] CAND
##   @var[in,out] ACTION
##   @var[in,out] DATA
##   @var[in,out] INSERT
##     COMP1-COMP2 を置き換える文字列を指定します
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##
##   @var[in    ] COMP_PREFIX
##
##   @var[in    ] comps_flags
##     以下のフラグ文字からなる文字列です。
##
##     p パラメータ展開の直後に於ける補完である事を表します。
##       直後に識別子を構成する文字を追記する時に対処が必要です。
##
##     v COMPV が利用可能である事を表します。
##
##     S クォート ''  の中にいる事を表します。
##     E クォート $'' の中にいる事を表します。
##     D クォート ""  の中にいる事を表します。
##     I クォート $"" の中にいる事を表します。
##
##     Note: shopt -s nocaseglob のため、フラグ文字は
##       大文字・小文字でも重複しないように定義する必要がある。
##
## 関数 ble-complete/action:$ACTION/complete
##   一意確定時に、挿入文字列・範囲に対する加工を行います。
##   例えばディレクトリ名の場合に / を後に付け加える等です。
##
##   @var[in] CAND
##   @var[in] ACTION
##   @var[in] DATA
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type comps_flags
##
##   @var[in,out] insert suffix
##     補完によって挿入される文字列を指定します。
##     加工後の挿入する文字列を返します。
##
##   @var[in] insert_beg insert_end
##     補完によって置換される範囲を指定します。
##
##   @var[in,out] insert_flags
##     以下のフラグ文字の組み合わせの文字列です。
##
##     r   [in] 既存の部分を保持したまま補完が実行される事を表します。
##         それ以外の時、既存の入力部分も含めて置換されます。
##     m   [out] 候補一覧 (menu) の表示を要求する事を表します。
##     n   [out] 再度補完を試み (確定せずに) 候補一覧を表示する事を要求します。
##

function ble-complete/action/util/complete.addtail {
  suffix=$suffix$1
}
function ble-complete/action/util/complete.close-quotation {
  case $comps_flags in
  (*[SE]*) ble-complete/action/util/complete.addtail \' ;;
  (*[DI]*) ble-complete/action/util/complete.addtail \" ;;
  esac
}

#------------------------------------------------------------------------------

# action/plain

function ble-complete/action:plain/initialize {
  if [[ $CAND == "$COMPV"* ]]; then
    local ins=${CAND:${#COMPV}} ret

    # 単語内の文脈に応じたエスケープ
    case $comps_flags in
    (*S*)    ble/string#escape-for-bash-single-quote "$ins"; ins=$ret ;;
    (*E*)    ble/string#escape-for-bash-escape-string "$ins"; ins=$ret ;;
    (*[DI]*) ble/string#escape-for-bash-double-quote "$ins"; ins=$ret ;;
    (*)   ble/string#escape-for-bash-specialchars "$ins"; ins=$ret ;;
    esac

    # Note: 現在の simple-word の定義だと引用符内にパラメータ展開を許していないので、
    #  必然的にパラメータ展開が直前にあるのは引用符の外である事が保証されている。
    #  以下は、今後 simple-word の引用符内にパラメータ展開を許す時には修正が必要。
    if [[ $comps_flags == *p* && $ins == [a-zA-Z_0-9]* ]]; then
      case $comps_flags in
      (*[DI]*)
        if [[ $COMPS =~ $_ble_complete_rex_rawparamx ]]; then
          local rematch1=${BASH_REMATCH[1]}
          INSERT=$rematch1'${'${COMPS:${#rematch1}+1}'}'$ins
          return
        else
          ins='""'$ins
        fi ;;
      (*) ins='\'$ins ;;
      esac
    fi

    INSERT=$COMPS$ins
  else
    local ret
    ble/string#escape-for-bash-specialchars "$CAND"; INSERT=$ret
  fi
}
function ble-complete/action:plain/complete { :; }

# action/word

function ble-complete/action:word/initialize {
  ble-complete/action:plain/initialize
}
function ble-complete/action:word/complete {
  ble-complete/action/util/complete.close-quotation
  ble-complete/action/util/complete.addtail ' '
}

# action/file

function ble-complete/action:file/initialize {
  ble-complete/action:plain/initialize
}
function ble-complete/action:file/complete {
  if [[ -e $CAND || -h $CAND ]]; then
    if [[ -d $CAND ]]; then
      [[ $CAND != */ ]] &&
        ble-complete/action/util/complete.addtail /
    else
      ble-complete/action/util/complete.close-quotation
      ble-complete/action/util/complete.addtail ' '
    fi
  fi
}
function ble-complete/action:file/getg {
  if [[ -h $CAND ]]; then
    ble-color-face2g filename_link
  elif [[ -d $CAND ]]; then
    ble-color-face2g filename_directory
  elif [[ -S $CAND ]]; then
    ble-color-face2g filename_socket
  elif [[ -b $CAND ]]; then
    ble-color-face2g filename_block
  elif [[ -c $CAND ]]; then
    ble-color-face2g filename_character
  elif [[ -p $CAND ]]; then
    ble-color-face2g filename_pipe
  elif [[ -x $CAND ]]; then
    ble-color-face2g filename_executable
  elif [[ -e $CAND ]]; then
    ble-color-face2g filename_other
  else
    ble-color-face2g filename_warning
  fi
}

# action/argument

function ble-complete/action:progcomp/initialize {
  if [[ $DATA == *:filenames:* ]]; then
    ble-complete/action:file/initialize
  else
    ble-complete/action:plain/initialize
  fi
}
function ble-complete/action:progcomp/complete {
  if [[ $DATA == *:filenames:* ]]; then
    ble-complete/action:file/complete
  else
    if [[ -d $CAND ]]; then
      [[ $CAND != */ ]] &&
        ble-complete/action/util/complete.addtail /
    else
      ble-complete/action/util/complete.close-quotation
      ble-complete/action/util/complete.addtail ' '
    fi
  fi

  [[ $DATA == *:nospace:* ]] && suffix=${suffix%' '}
}
function ble-complete/action:progcomp/getg {
  if [[ $DATA == *:filenames:* ]]; then
    ble-complete/action:file/getg
  fi
}

# action/command

function ble-complete/action:command/initialize {
  ble-complete/action:plain/initialize
}
function ble-complete/action:command/complete {
  if [[ -d $CAND ]]; then
    [[ $CAND != */ ]] &&
      ble-complete/action/util/complete.addtail /
  elif ! type "$CAND" &>/dev/null; then
    # 関数名について縮約されたもので一意確定した時。
    #
    # Note: 関数名について縮約されている時、
    #   本来は一意確定でなくても一意確定として此処に来ることがある。
    #   そのコマンドが存在していない時に、縮約されていると判定する。
    #
    if [[ $CAND == */ ]]; then
      # 縮約されていると想定し続きの補完候補を出す。
      insert_flags=${insert_flags}n
    fi
  else
    ble-complete/action/util/complete.close-quotation
    ble-complete/action/util/complete.addtail ' '
  fi
}

# action/variable

function ble-complete/action:variable/initialize { ble-complete/action:plain/initialize; }
function ble-complete/action:variable/complete {
  case $DATA in
  (assignment) 
    # var= 等に於いて = を挿入
    ble-complete/action/util/complete.addtail '=' ;;
  (braced)
    # ${var 等に於いて } を挿入
    ble-complete/action/util/complete.addtail '}' ;;
  esac
}

#==============================================================================
# source

## 関数 ble-complete/cand/yield ACTION CAND DATA
##   @param[in] ACTION
##   @param[in] CAND
##   @param[in] DATA
##   @var[in] COMP_PREFIX
function ble-complete/cand/yield {
  local ACTION=$1 CAND=$2 DATA="${*:3}"
  [[ $flag_force_fignore ]] && ! ble-complete/.fignore/filter "$CAND" && return

  local PREFIX_LEN=0
  [[ $CAND == "$COMP_PREFIX"* ]] && PREFIX_LEN=${#COMP_PREFIX}

  local INSERT=$CAND
  ble-complete/action:"$ACTION"/initialize

  local icand
  ((icand=cand_count++))
  cand_cand[icand]=$CAND
  cand_word[icand]=$INSERT
  cand_pack[icand]=$ACTION:${#CAND},${#INSERT},$PREFIX_LEN:$CAND$INSERT$DATA
}

_ble_complete_cand_varnames=(ACTION CAND INSERT DATA PREFIX_LEN)

## 関数 ble-complete/cand/unpack data
##   @param[in] data
##     ACTION:ncand,ninsert,PREFIX_LEN:$CAND$INSERT$DATA
##   @var[out] ACTION CAND INSERT DATA PREFIX_LEN
function ble-complete/cand/unpack {
  local pack=$1
  ACTION=${pack%%:*} pack=${pack#*:}
  local text=${pack#*:}
  ble/string#split pack , "${pack%%:*}"
  CAND=${text::pack[0]}
  INSERT=${text:pack[0]:pack[1]}
  DATA=${text:pack[0]+pack[1]}
  PREFIX_LEN=${pack[2]}
}

## 定義されている source
##
##   source/wordlist
##   source/command
##   source/file
##   source/dir
##   source/argument
##   source/variable
##
## source の実装
##
## 関数 ble-complete/source:$name args...
##   @param[in] args...
##     ble-syntax/completion-context/generate で設定されるユーザ定義の引数。
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##
##   @var[out] COMP_PREFIX
##     ble-complete/cand/yield で参照される一時変数。
##

# source/wordlist

function ble-complete/source:wordlist {
  [[ $comps_flags == *v* ]] || return 1
  [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  local cand
  for cand; do
    if [[ $cand == "$COMPV"* ]]; then
      ble-complete/cand/yield word "$cand"
    fi
  done
}

# source/command

function ble-complete/source:command/.contract-by-slashes {
  local slashes=${COMPV//[!'/']}
  ble/bin/awk -F / -v baseNF=${#slashes} '
    function initialize_common() {
      common_NF = NF;
      for (i = 1; i <= NF; i++) common[i] = $i;
      common_degeneracy = 1;
      common0_NF = NF;
      common0_str = $0;
    }
    function print_common(_, output) {
      if (!common_NF) return;

      if (common_degeneracy == 1) {
        print common0_str;
        common_NF = 0;
        return;
      }

      output = common[1];
      for (i = 2; i <= common_NF; i++)
        output = output "/" common[i];

      # Note:
      #   For candidates `a/b/c/1` and `a/b/c/2`, prints `a/b/c/`.
      #   For candidates `a/b/c` and `a/b/c/1`, prints `a/b/c` and `a/b/c/1`.
      if (common_NF == common0_NF) print output;
      print output "/";

      common_NF = 0;
    }

    {
      if (NF <= baseNF + 1) {
        print_common();
        print $0;
      } else if (!common_NF) {
        initialize_common();
      } else {
        n = common_NF < NF ? common_NF : NF;
        for (i = baseNF + 1; i <= n; i++)
          if (common[i] != $i) break;
        matched_length = i - 1;

        if (matched_length <= baseNF) {
          print_common();
          initialize_common();
        } else {
          common_NF = matched_length;
          common_degeneracy++;
        }
      }
    }

    END { print_common(); }
  '
}

function ble-complete/source:command/gen.1 {
  [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}
  # Note: 何故か compgen -A command はクォート除去が実行されない。
  #   compgen -A function はクォート除去が実行される。
  #   従って、compgen -A command には直接 COMPV を渡し、
  #   compgen -A function には compv_quoted を渡す。
  compgen -c -- "$COMPV"
  if [[ $COMPV == */* ]]; then
    local q="'" Q="'\''"
    local compv_quoted="'${COMPV//$q/$Q}'"
    compgen -A function -- "$compv_quoted"
  fi
}

function ble-complete/source:command/gen {
  if [[ $comp_type != *a* && $bleopt_complete_contract_function_names ]]; then
    ble-complete/source:command/gen.1 |
      ble-complete/source:command/.contract-by-slashes
  else
    ble-complete/source:command/gen.1
  fi

  # ディレクトリ名列挙 (/ 付きで生成する)
  #
  #   Note: shopt -q autocd &>/dev/null かどうかに拘らず列挙する。
  #
  #   Note: compgen -A directory (以下のコード参照) はバグがあって、
  #     bash-4.3 以降でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #     [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}
  #     compgen -A directory -S / -- "$compv_quoted"
  #
  local ret
  ble-complete/source:file/.construct-pathname-pattern "$COMPV"
  ble-complete/util/eval-pathname-expansion "$ret/"
  ((${#ret[@]})) && printf '%s\n' "${ret[@]}"
}
function ble-complete/source:command {
  [[ $comps_flags == *v* ]] || return 1
  [[ ! $COMPV ]] && shopt -q no_empty_cmd_completion && return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  local cand arr i=0
  local compgen
  ble/util/assign compgen ble-complete/source:command/gen
  [[ $compgen ]] || return 1
  ble/util/assign-array arr 'sort -u <<< "$compgen"' # 1 fork/exec
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

    # workaround: 何故か compgen -c -- "$compv_quoted" で
    #   厳密一致のディレクトリ名が混入するので削除する。
    [[ $cand != */ && -d $cand ]] && ! type "$cand" &>/dev/null && continue

    ble-complete/cand/yield command "$cand"
  done
}

# source/file

function ble-complete/util/eval-pathname-expansion {
  local pattern=$1

  local old_noglob=
  if [[ -o noglob ]]; then
    noglob=1
    set +f
  fi

  local old_nullglob=
  if ! shopt -q nullglob; then
    old_nullglob=0
    shopt -s nullglob
  fi

  local old_nocaseglob=
  if [[ $comp_type == *i* ]]; then
    if ! shopt -q nocaseglob; then
      old_nocaseglob=0
      shopt -s nocaseglob
    fi
  else
    if shopt -q nocaseglob; then
      old_nocaseglob=1
      shopt -u nocaseglob
    fi
  fi

  IFS= GLOBIGNORE= eval 'ret=($pattern)' 2>/dev/null

  if [[ $old_nocaseglob ]]; then
    if ((old_nocaseglob)); then
      shopt -s nocaseglob
    else
      shopt -u nocaseglob
    fi
  fi

  [[ $old_nullglob ]] && shopt -u nullglob

  [[ $old_noglob ]] && set -f
}

## 関数 ble-complete/source:file/.construct-ambiguous-pathname-pattern path
##   指定された path に対応する曖昧一致パターンを生成します。
##   例えばalpha/beta/gamma に対して a*/b*/g* でファイル名を生成します。
##
##   @param[in] path
##   @var[out] ret
##
##   @remarks
##     a*/b*/g* だと曖昧一致しないファイル名も生成されるが、
##     生成後のフィルタによって一致しないものは除去されるので気にしない。
##
function ble-complete/source:file/.construct-ambiguous-pathname-pattern {
  local path=$1
  local pattern= i=0
  local names; ble/string#split names / "$1"
  local name
  for name in "${names[@]}"; do
    ((i++)) && pattern=$pattern/
    if [[ $name ]]; then
      ble/string#escape-for-bash-glob "${name::1}"
      pattern="$pattern$ret*"
    fi
  done
  [[ $pattern ]] || pattern="*"
  ret=$pattern
}
## 関数 ble-complete/source:file/.construct-pathname-pattern path
##   @param[in] path
##   @var[out] ret
function ble-complete/source:file/.construct-pathname-pattern {
  local path=$1
  if [[ $comp_type == *a* ]]; then
    ble-complete/source:file/.construct-ambiguous-pathname-pattern "$path"; local pattern=$ret
  else
    ble/string#escape-for-bash-glob "$path"; local pattern=$ret*
  fi
  ret=$pattern
}

function ble-complete/source:file {
  [[ $comps_flags == *v* ]] || return 1
  [[ $comp_type != *a* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  #   Note: compgen -A file (以下のコード参照) はバグがあって、
  #     bash-4.0 と 4.1 でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #     local q="'" Q="'\''"; local compv_quoted="'${COMPV//$q/$Q}'"
  #     local candidates; ble/util/assign-array candidates 'compgen -A file -- "$compv_quoted"'

  local ret
  ble-complete/source:file/.construct-pathname-pattern "$COMPV"
  ble-complete/util/eval-pathname-expansion "$ret"
  local -a candidates; candidates=("${ret[@]}")

  local cand
  for cand in "${candidates[@]}"; do
    [[ -e $cand || -h $cand ]] || continue
    [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
    ble-complete/cand/yield file "$cand"
  done
}

# source/dir

function ble-complete/source:dir {
  [[ $comps_flags == *v* ]] || return 1
  [[ $comp_type != *a* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  # Note: compgen -A directory (以下のコード参照) はバグがあって、
  #   bash-4.3 以降でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #   local q="'" Q="'\''"; local compv_quoted="'${COMPV//$q/$Q}'"
  #   local candidates; ble/util/assign-array candidates 'compgen -A directory -S / -- "$compv_quoted"'

  local ret
  ble-complete/source:file/.construct-pathname-pattern "$COMPV"
  ble-complete/util/eval-pathname-expansion "$ret/"
  local -a candidates; candidates=("${ret[@]}")

  local cand
  for cand in "${candidates[@]}"; do
    [[ -d $cand ]] || continue
    [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
    [[ $cand == / ]] || cand=${cand%/}
    ble-complete/cand/yield file "$cand"
  done
}

# source/argument (complete -p)

function ble-complete/source:argument/.progcomp-helper-vars {
  COMP_LINE=
  COMP_WORDS=()
  local shell_specialchars=']\ ["'\''`$|&;<>()*?{}!^'$'\n\t'
  local word delta=0 index=0 q="'" Q="'\''" qq="''"
  for word in "${comp_words[@]}"; do
    local ret close_type
    if ble-syntax:bash/simple-word/close-open-word "$word"; then
      ble-syntax:bash/simple-word/eval "$ret"
      ((index)) && [[ $ret == *["$shell_specialchars"]* ]] &&
        ret="'${ret//$q/$Q}'" ret=${ret#"$qq"} ret=${ret%"$qq"} # コマンド名以外はクォート
      ((index<=comp_cword&&(delta+=${#ret}-${#word})))
      word=$ret
    fi
    ble/array#push COMP_WORDS "$word"

    if ((index++==0)); then
      COMP_LINE=$word
    else
      COMP_LINE="$COMP_LINE $word"
    fi
  done

  COMP_CWORD=$comp_cword
  COMP_POINT=$((comp_point+delta))
  COMP_TYPE=9
  COMP_KEY="${KEYS[${#KEYS[@]}-1]:-9}" # KEYS defined in ble-decode/widget/.call-keyseq

  # 直接渡す場合。$'' などがあると bash-completion が正しく動かないので、
  # エスケープを削除して適当に処理する。
  #
  # COMP_WORDS=("${comp_words[@]}")
  # COMP_LINE="$comp_line"
  # COMP_POINT="$comp_point"
  # COMP_CWORD="$comp_cword"
  # COMP_TYPE=9
  # COMP_KEY="${KEYS[${#KEYS[@]}-1]:-9}" # KEYS defined in ble-decode/widget/.call-keyseq
}
function ble-complete/source:argument/.progcomp-helper-prog {
  if [[ $comp_prog ]]; then
    (
      local COMP_WORDS COMP_CWORD
      export COMP_LINE COMP_POINT COMP_TYPE COMP_KEY
      ble-complete/source:argument/.progcomp-helper-vars
      local cmd=${comp_words[0]} cur=${comp_words[comp_cword]} prev=${comp_words[comp_cword-1]}
      "$comp_prog" "$cmd" "$cur" "$prev"
    )
  fi
}
function ble-complete/source:argument/.progcomp-helper-func {
  [[ $comp_func ]] || return
  local -a COMP_WORDS
  local COMP_LINE COMP_POINT COMP_CWORD COMP_TYPE COMP_KEY
  ble-complete/source:argument/.progcomp-helper-vars

  # compopt に介入して -o/+o option を読み取る。
  local fDefault=
  function compopt {
    builtin compopt "$@"; local ret="$?"

    local -a ospec
    while (($#)); do
      local arg=$1; shift
      case "$arg" in
      (-*)
        local ic c
        for ((ic=1;ic<${#arg};ic++)); do
          c=${arg:ic:1}
          case "$c" in
          (o)    ospec[${#ospec[@]}]="-$1"; shift ;;
          ([DE]) fDefault=1; break 2 ;;
          (*)    ((ret==0&&(ret=1))) ;;
          esac
        done ;;
      (+o) ospec[${#ospec[@]}]="+$1"; shift ;;
      (*)
        # 特定のコマンドに対する compopt 指定
        return "$ret" ;;
      esac
    done

    local s
    for s in "${ospec[@]}"; do
      case "$s" in
      (-*) comp_opts=${comp_opts//:"${s:1}":/:}${s:1}: ;;
      (+*) comp_opts=${comp_opts//:"${s:1}":/:} ;;
      esac
    done

    return "$ret"
  }

  local cmd=${comp_words[0]} cur=${comp_words[comp_cword]} prev=${comp_words[comp_cword-1]}
  "$comp_func" "$cmd" "$cur" "$prev"; local ret=$?
  unset -f compopt

  if [[ $is_default_completion && $ret == 124 ]]; then
    is_default_completion=retry
  fi
}

## 関数 ble-complete/source:argument/.progcomp
##   @var[out] comp_opts
##
##   @var[in] COMP1 COMP2 COMPV COMPS comp_type
##     ble-complete/source の標準的な変数たち。
##
##   @var[in] comp_words comp_line comp_point comp_cword
##     ble-syntax:bash/extract-command によって生成される変数たち。
##
##   @var[in] 他色々
##   @exit 入力がある時に 148 を返します。
function ble-complete/source:argument/.progcomp {
  shopt -q progcomp || return 1
  [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}

  local comp_prog= comp_func=
  local cmd=${comp_words[0]} compcmd= is_default_completion=

  if complete -p "$cmd" &>/dev/null; then
    compcmd=$cmd
  elif [[ $cmd == */?* ]] && complete -p "${cmd##*/}" &>/dev/null; then
    compcmd=${cmd##*/}
  elif complete -p -D &>/dev/null; then
    is_default_completion=1
    compcmd='-D'
  fi

  [[ $compcmd ]] || return 1

  local -a compargs compoptions
  local ret iarg=1
  ble/util/assign ret 'complete -p "$compcmd" 2>/dev/null'
  ble/string#split-words compargs "$ret"
  while ((iarg<${#compargs[@]})); do
    local arg=${compargs[iarg++]}
    case "$arg" in
    (-*)
      local ic c
      for ((ic=1;ic<${#arg};ic++)); do
        c=${arg:ic:1}
        case "$c" in
        ([abcdefgjksuvE])
          ble/array#push compoptions "-$c" ;;
        ([pr])
          ;; # 無視 (-p 表示 -r 削除)
        ([AGWXPS])
          ble/array#push compoptions "-$c" "${compargs[iarg++]}" ;;
        (o)
          local o=${compargs[iarg++]}
          comp_opts=${comp_opts//:"$o":/:}$o:
          ble/array#push compoptions "-$c" "$o" ;;
        (F)
          comp_func=${compargs[iarg++]}
          ble/array#push compoptions "-$c" ble-complete/source:argument/.progcomp-helper-func ;;
        (C)
          comp_prog=${compargs[iarg++]}
          ble/array#push compoptions "-$c" ble-complete/source:argument/.progcomp-helper-prog ;;
        (*)
          # -D, etc. just discard
        esac
      done ;;
    (*)
      ;; # 無視
    esac
  done

  ble-complete/check-cancel && return 148

  # Note: 一旦 compgen だけで ble/util/assign するのは、compgen をサブシェルではなく元のシェルで評価する為である。
  #   補完関数が遅延読込になっている場合などに、読み込まれた補完関数が次回から使える様にする為に必要である。
  local q="'" Q="'\''"
  local compgen compv_quoted="'${COMPV//$q/$Q}'"
  ble/util/assign compgen 'compgen "${compoptions[@]}" -- "$compv_quoted" 2>/dev/null'

  # Note: complete -D 補完仕様に従った補完関数が 124 を返したとき再度始めから補完を行う。
  #   ble-complete/source:argument/.progcomp-helper-func 関数内で補間関数の終了ステータスを確認し、
  #   もし 124 だった場合には is_default_completion に retry を設定する。
  if [[ $is_default_completion == retry && ! $_ble_complete_retry_guard ]]; then
    local _ble_complete_retry_guard=1
    ble-complete/source:argument/.progcomp
    return
  fi

  [[ $compgen ]] || return 1

  # Note: git の補完関数など勝手に末尾に space をつけ -o nospace を指定する物が存在する。
  #   単語の後にスペースを挿入する事を意図していると思われるが、
  #   通常 compgen (例: compgen -f) で生成される候補に含まれるスペースは、
  #   挿入時のエスケープ対象であるので末尾の space もエスケープされてしまう。
  #
  #   仕方がないので sed で各候補の末端の [[:space:]]+ を除去する。
  #   これだとスペースで終わるファイル名を挿入できないという実害が発生するが、
  #   そのような変な補完関数を作るのが悪いのである。
  local use_workaround_for_git=
  if [[ $comp_func == __git* && $comp_opts == *:nospace:* ]]; then
    use_workaround_for_git=1
    comp_opts=${comp_opts//:nospace:/:}
  fi

  # Note: "$COMPV" で始まる単語だけを候補として列挙する為に sed /^$rex_compv/ でフィルタする。
  #   compgen に -- "$COMPV" を渡しても何故か思うようにフィルタしてくれない為である。
  #   (compgen -W "$(compgen ...)" -- "$COMPV" の様にしないと駄目なのか?)
  local arr ret
  ble/string#escape-for-sed-regex "$COMPV"; local rex_compv=$ret
  if [[ $use_workaround_for_git ]]; then
    ble/util/assign-array arr 'ble/bin/sed -n "/^\$/d;/^$rex_compv/{s/[[:space:]]\{1,\}\$//;p;}" <<< "$compgen" | ble/bin/sort -u' 2>/dev/null
  else
    ble/util/assign-array arr 'ble/bin/sed -n "/^\$/d;/^$rex_compv/p" <<< "$compgen" | ble/bin/sort -u' 2>/dev/null
  fi

  local action=progcomp
  [[ $comp_opts == *:filenames:* && $COMPV == */* ]] && COMP_PREFIX=${COMPV%/*}/

  local cand i=0 count=0
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148
    ble-complete/cand/yield "$action" "$cand" "$comp_opts"
    ((count++))
  done

  ((count!=0))
}

## 関数 ble-complete/source:argument/.generate-user-defined-completion
##   ユーザ定義の補完を実行します。ble/cmdinfo/complete:コマンド名
##   という関数が定義されている場合はそれを使います。
##   それ以外の場合は complete によって登録されているプログラム補完が使用されます。
##
##   @var[in] comp_index
##   @var[in] (variables set by ble-syntax/parse)
##
function ble-complete/source:argument/.generate-user-defined-completion {
  local comp_words comp_line comp_point comp_cword
  ble-syntax:bash/extract-command "$comp_index" || return 1

  local cmd=${comp_words[0]}
  if ble/is-function "ble/cmdinfo/complete:$cmd"; then
    "ble/cmdinfo/complete:$cmd"
  elif [[ $cmd == */?* ]] && ble/is-function "ble/cmdinfo/complete:${cmd##*/}"; then
    "ble/cmdinfo/complete:${cmd##*/}"
  else
    ble-complete/source:argument/.progcomp
  fi
}

function ble-complete/source:argument {
  local comp_opts=:
  local old_cand_count=$old_cand_count

  # try complete&compgen
  ble-complete/source:argument/.generate-user-defined-completion; local exit=$?
  [[ $exit == 0 || $exit == 148 ]] && return "$exit"

  # 候補が見付からない場合
  if [[ $comp_opts == *:dirnames:* ]]; then
    ble-complete/source:dir
  else
    # filenames, default, bashdefault
    ble-complete/source:file
  fi

  if ((cand_count<=old_cand_count)); then
    if local rex='^/?[-a-zA-Z_]+[:=]'; [[ $COMPV =~ $rex ]]; then
      # var=filename --option=filename /I:filename など。
      local prefix=$BASH_REMATCH value=${COMPV:${#BASH_REMATCH}}
      local COMP_PREFIX=$prefix
      [[ $comp_type != *a* && $value =~ ^.+/ ]] && COMP_PREFIX=$prefix${BASH_REMATCH[0]}

      local ret cand
      ble-complete/source:file/.construct-pathname-pattern "$value"
      ble-complete/util/eval-pathname-expansion "$ret"
      for cand in "${ret[@]}"; do
        [[ -e $cand || -h $cand ]] || continue
        [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
        ble-complete/cand/yield file "$prefix$cand"
      done
    fi
  fi
}

# source/variable

function ble-complete/source:variable {
  [[ $comps_flags == *v* ]] || return 1
  [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}

  local action=variable
  local data=
  case $1 in
  ('=') data=assignment ;;
  ('b') data=braced ;;
  esac

  local q="'" Q="'\''"
  local compv_quoted="'${COMPV//$q/$Q}'"
  local cand arr
  ble/util/assign-array arr 'compgen -v -- "$compv_quoted"'

  # 既に完全一致している場合は、より前の起点から補完させるために省略
  [[ $1 != '=' && ${#arr[@]} == 1 && $arr == "$COMPV" ]] && return

  local i=0
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148
    ble-complete/cand/yield "$action" "$cand" "$data"
  done
}

#------------------------------------------------------------------------------
# 候補生成

## @var[out] cand_count
##   候補の数
## @arr[out] cand_cand
##   候補文字列
## @arr[out] cand_word
##   挿入文字列 (～ エスケープされた候補文字列)
##
## @arr[out] cand_pack
##   補完候補のデータを一つの配列に纏めたもの。
##   要素を使用する際は以下の様に変数に展開して使う。
##
##     local "${_ble_complete_cand_varnames[@]}"
##     ble-complete/cand/unpack "${cand_pack[0]}"
##
##   先頭に ACTION が格納されているので
##   ACTION だけ参照する場合には以下の様にする。
##
##     local ACTION=${cand_pack[0]%%:*}
##

## 関数 ble-complete/util/construct-ambiguous-regex text
##   曖昧一致に使う正規表現を生成します。
##   @param[in] text
##   @var[in] comp_type
##   @var[out] ret
function ble-complete/util/construct-ambiguous-regex {
  local text=$1
  local i=0 n=${#text} c=
  local -a buff=()
  for ((i=0;i<n;i++)); do
    ((i)) && ble/array#push buff '.*'
    ch=${text:i:1}
    if [[ $ch == [a-zA-Z] ]]; then
      if [[ $comp_type == *i* ]]; then
        ble/string#toggle-case "$ch"
        ch=[$ch$ret]
      fi
    else
      ble/string#escape-for-extended-regex "$ch"; ch=$ret
    fi
    ble/array#push buff "$ch"
  done
  IFS= eval 'ret="${buff[*]}"'
}

function ble-complete/.fignore/prepare {
  _fignore=()
  local i=0 leaf tmp
  ble/string#split tmp ':' "$FIGNORE"
  for leaf in "${tmp[@]}"; do
    [[ $leaf ]] && _fignore[i++]="$leaf"
  done
}
function ble-complete/.fignore/filter {
  local pat
  for pat in "${_fignore[@]}"; do
    [[ $1 == *"$pat" ]] && return 1
  done
}

## 関数 ble-complete/candidates/.pick-nearest-context
##   一番開始点に近い補完源の一覧を求めます。
##
##   @var[in] comp_index
##   @arr[in,out] remaining_contexts
##   @arr[out]    nearest_contexts
##   @var COMP1 COMP2
##     補完範囲
##   @var COMPS
##     補完範囲の (クオートが含まれうる) コマンド文字列
##   @var COMPV
##     補完範囲のコマンド文字列が意味する実際の文字列
##   @var comps_flags
function ble-complete/candidates/.pick-nearest-context {
  COMP1= COMP2=$comp_index
  nearest_contexts=()

  local -a unused_contexts=()
  local ctx actx
  for ctx in "${remaining_contexts[@]}"; do
    ble/string#split-words actx "$ctx"
    if ((COMP1<actx[1])); then
      COMP1=${actx[1]}
      ble/array#push unused_contexts "${nearest_contexts[@]}"
      nearest_contexts=("$ctx")
    elif ((COMP1==actx[1])); then
      ble/array#push nearest_contexts "$ctx"
    else
      ble/array#push unused_contexts "$ctx"
    fi
  done
  remaining_contexts=("${unused_contexts[@]}")

  COMPS=${comp_text:COMP1:COMP2-COMP1}
  comps_flags=

  if [[ ! $COMPS ]]; then
    comps_flags=${comps_flags}v COMPV=
  elif local ret close_type; ble-syntax:bash/simple-word/close-open-word "$COMPS"; then
    comps_flags=$comps_flags$close_type
    ble-syntax:bash/simple-word/eval "$ret"; comps_flags=${comps_flags}v COMPV=$ret
    [[ $COMPS =~ $_ble_complete_rex_rawparamx ]] && comps_flags=${comps_flags}p
  else
    COMPV=
  fi
}

## 関数 ble-complete/candidates/.filter-by-regex rex_filter
##   生成された候補 (cand_*) において指定した正規表現に一致する物だけを残します。
##   @param[in] rex_filter
##   @var[in,out] cand_count
##   @arr[in,out] cand_{prop,cand,word,show,data}
##   @exit
##     ユーザ入力によって中断された時に 148 を返します。
function ble-complete/candidates/.filter-by-regex {
  local rex_filter=$1
  # todo: 複数の配列に触る非効率な実装だが後で考える
  local i j=0
  local -a prop=() cand=() word=() show=() data=()
  for ((i=0;i<cand_count;i++)); do
    ((i%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148
    [[ ${cand_cand[i]} =~ $rex_filter ]] || continue
    cand[j]=${cand_cand[i]}
    word[j]=${cand_word[i]}
    data[j]=${cand_pack[i]}
    ((j++))
  done
  cand_count=$j
  cand_cand=("${cand[@]}")
  cand_word=("${word[@]}")
  cand_pack=("${data[@]}")
}

## 関数 ble-complete/candidates/get-contexts comp_text comp_index
## 関数 ble-complete/candidates/get-prefix-contexts comp_text comp_index
##   @param[in] comp_text
##   @param[in] comp_index
##   @var[out] contexts
function ble-complete/candidates/get-contexts {
  local comp_text=$1 comp_index=$2
  ble-syntax/import
  ble-edit/content/update-syntax
  ble-syntax/completion-context/generate "$comp_text" "$comp_index"
  ((${#contexts[@]}))
}
function ble-complete/candidates/get-prefix-contexts {
  local comp_text=$1 comp_index=$2
  ble-complete/candidates/get-contexts "$@" || return

  # 現在位置より前に始まる補完文脈だけを選択する
  local -a filtered_contexts=()
  local ctx actx
  for ctx in "${contexts[@]}"; do
    ble/string#split-words actx "$ctx"
    local comp1=${actx[1]}
    ((comp1<comp_index)) &&
      ble/array#push filtered_contexts "$ctx"
  done
  contexts=("${filtered_contexts[@]}")
  ((${#contexts[@]}))
}


## 関数 ble-complete/candidates/generate
##   @var[in] comp_text comp_index
##   @arr[in] contexts
##   @var[out] COMP1 COMP2 COMPS COMPV
##   @var[out] comp_type comps_flags
##   @var[out] cand_*
##   @var[out] rex_ambiguous_compv
function ble-complete/candidates/generate {
  local flag_force_fignore=
  local -a _fignore=()
  if [[ $FIGNORE ]]; then
    ble-complete/.fignore/prepare
    ((${#_fignore[@]})) && shopt -q force_fignore && flag_force_fignore=1
  fi

  ble/util/test-rl-variable completion-ignore-case &&
    comp_type=${comp_type}i

  cand_count=0
  cand_cand=() # 候補文字列
  cand_word=() # 挿入文字列 (～ エスケープされた候補文字列)
  cand_pack=() # 候補の詳細データ

  local -a remaining_contexts nearest_contexts
  remaining_contexts=("${contexts[@]}")
  while ((${#remaining_contexts[@]})); do
    # 次の開始点が近くにある候補源たち
    nearest_contexts=()
    comps_flags=
    ble-complete/candidates/.pick-nearest-context

    # 候補生成
    local ctx actx source
    for ctx in "${nearest_contexts[@]}"; do
      ble/string#split-words actx "$ctx"
      ble/string#split source : "${actx[0]}"

      local COMP_PREFIX= # 既定値 (yield-candidate で参照)
      ble-complete/source:"${source[@]}"
    done

    ble-complete/check-cancel && return 148
    ((cand_count)) && return 0
  done

  if [[ $bleopt_complete_ambiguous && $COMPV ]]; then
    comp_type=${comp_type}a
    remaining_contexts=("${contexts[@]}")
    while ((${#remaining_contexts[@]})); do
      nearest_contexts=()
      comps_flags=
      ble-complete/candidates/.pick-nearest-context

      for ctx in "${nearest_contexts[@]}"; do
        ble/string#split-words actx "$ctx"
        ble/string#split source : "${actx[0]}"

        local COMP_PREFIX= # 既定値 (yield-candidate で参照)
        ble-complete/source:"${source[@]}"
      done

      local ret; ble-complete/util/construct-ambiguous-regex "$COMPV"
      rex_ambiguous_compv=^$ret
      ble-complete/candidates/.filter-by-regex "$rex_ambiguous_compv"
      (($?==148)) && return 148
      ((cand_count)) && return 0
    done
    comp_type=${comp_type//a}
  fi

  return 0
}

## 関数 ble-complete/candidates/determine-common-prefix
##   cand_* を元に common prefix を算出します。
##   @var[in] cand_*
##   @var[in] rex_ambiguous_compv
##   @var[out] ret
function ble-complete/candidates/determine-common-prefix {
  # 共通部分
  local common=${cand_word[0]} clen=${#cand_word[0]}
  if ((cand_count>1)); then
    local word loop=0
    for word in "${cand_word[@]:1}"; do
      ((loop++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

      ((clen>${#word}&&(clen=${#word})))
      while [[ ${word::clen} != "${common::clen}" ]]; do
        ((clen--))
      done
      common=${common::clen}
    done
  fi

  if [[ $comp_type == *a* ]]; then
    # 曖昧一致に於いて複数の候補の共通部分が
    # 元の文字列に曖昧一致しない場合は補完しない。
    [[ $common =~ $rex_ambiguous_compv ]] || common=$COMPS
  elif ((cand_count!=1)) && [[ $common != "$COMPS"* ]]; then
    common=$COMPS
  fi

  ret=$common
}

#------------------------------------------------------------------------------
#
# 候補表示
#

_ble_complete_menu_beg=
_ble_complete_menu_end=
_ble_complete_menu_str=
_ble_complete_menu_active=
_ble_complete_menu_common_part=
_ble_complete_menu_items=()
_ble_complete_menu_pack=()
_ble_complete_menu_selected=-1
_ble_complete_menu_filter=

## 関数 ble-complete/menu/initialize
##   @var[out] menu_common_part
##   @var[out] cols lines
function ble-complete/menu/initialize {
  ble-edit/info/.initialize-size

  menu_common_part=$COMPV
  if [[ $comp_type != *a* ]]; then
    local ret close_type
    if ble-syntax:bash/simple-word/close-open-word "$insert"; then
      ble-syntax:bash/simple-word/eval "$ret"
      menu_common_part=$ret
    fi
  fi
}

## 関数 ble-complete/menu/construct-single-entry pack opts
##   @param[in] pack
##     cand_pack の要素と同様の形式の文字列です。
##   @param[in] opts
##     コロン区切りのオプションです。
##     selected
##       選択されている候補の描画シーケンスを生成します。
##     use_vars
##       引数の pack を展開する代わりに、
##       既に展開されているローカル変数を参照します。
##       この時、引数 pack は使用されません。
##   @var[in,out] x y
##   @var[out] ret
##   @var[in] cols lines menu_common_part
function ble-complete/menu/construct-single-entry {
  local opts=$2
  if [[ :$opts: != *:use_vars:* ]]; then
    local "${_ble_complete_cand_varnames[@]}"
    ble-complete/cand/unpack "$1"
  fi
  local show=${CAND:PREFIX_LEN}
  local g=0; ble/function#try ble-complete/action:"$ACTION"/getg
  [[ :$opts: == *:selected:* ]] && ((g|=_ble_color_gflags_Revert))
  if [[ $menu_common_part && $CAND == "$menu_common_part"* ]]; then
    local out= alen=$((${#menu_common_part}-PREFIX_LEN))
    local sgr0 sgr1
    if ((alen>0)); then
      ble-color-g2sgr -v sgr0 $((g|_ble_color_gflags_Bold))
      ble-color-g2sgr -v sgr1 $((g|_ble_color_gflags_Bold|_ble_color_gflags_Revert))
      ble-edit/info/.construct-text "${show::alen}"
      out=$out$sgr0$ret
    fi
    if ((alen<${#show})); then
      ble-color-g2sgr -v sgr0 $((g))
      ble-color-g2sgr -v sgr1 $((g|_ble_color_gflags_Revert))
      ble-edit/info/.construct-text "${show:alen}"
      out=$out$sgr0$ret
    fi
    ret=$out$_ble_term_sgr0
  else
    local sgr0 sgr1
    ble-color-g2sgr -v sgr0 $((g))
    ble-color-g2sgr -v sgr1 $((g|_ble_color_gflags_Revert))
    ble-edit/info/.construct-text "$show"
    ret=$sgr0$ret$_ble_term_sgr0
  fi
}

## 関数 ble-complete/menu/style:$menu_style/construct
##   候補一覧メニューの表示・配置を計算します。
##
##   @var[out] x y esc
##   @arr[out] menu_items
##   @var[in] manu_style
##   @arr[in] cand_pack
##   @var[in] cols lines menu_common_part
##

## 関数 ble-complete/menu/style:align/construct
##   complete_menu_style=align{,-nowrap} に対して候補を配置します。
function ble-complete/menu/style:align/construct {
  local ret iloop=0

  # 初めに各候補の幅を計算する
  local measure; measure=()
  local max_wcell=$bleopt_complete_menu_align max_width=1
  ((max_wcell<=0?(max_wcell=20):(max_wcell<2&&(max_wcell=2))))
  local pack w esc1 nchar_max=$((cols*lines)) nchar=0
  for pack in "${cand_pack[@]}"; do
    ((iloop++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

    x=0 y=0; ble-complete/menu/construct-single-entry "$pack"; esc1=$ret
    ((w=y*cols+x))

    ble/array#push measure "$w:${#pack}:$pack$esc1"

    if ((w++,max_width<w)); then
      ((max_width<max_wcell)) &&
        ((nchar+=(iloop-1)*((max_wcell<w?max_wcell:w)-max_width)))
      ((w>max_wcell)) && 
        ((w=(w+max_wcell-1)/max_wcell*max_wcell))
      ((max_width=w))
    fi

    # 画面に入る可能性がある所までで止める
    (((nchar+=w)>=nchar_max)) && break
  done

  local wcell=$((max_width<max_wcell?max_width:max_wcell))
  ((wcell=cols/(cols/wcell)))
  local ncell=$((cols/wcell))

  x=0 y=0 esc=
  menu_items=()
  local i=0 N=${#measure[@]}
  local entry index w s pack esc1
  local x0 y0
  local icell pad
  for entry in "${measure[@]}"; do
    ((iloop++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

    w=${entry%%:*} entry=${entry#*:}
    s=${entry%%:*} entry=${entry#*:}
    pack=${entry::s} esc1=${entry:s}

    ((x0=x,y0=y))
    if ((x==0||x+w<cols)); then
      ((x+=w%cols,y+=w/cols))
      ((y>=lines&&(x=x0,y=y0,1))) && break
    else
      if [[ $menu_style == align-nowrap ]]; then
        esc=$esc$'\n'
        ((x0=x=0,y0=++y,y>=lines)) && break
        ((x=w%cols,y+=w/cols))
        ((y>=lines&&(x=x0,y=y0,1))) && break
      else
        ble-complete/menu/construct-single-entry "$pack"; esc1=$ret
        ((y>=lines&&(x=x0,y=y0,1))) && break
      fi
    fi

    ble/array#push menu_items "$x0,$y0,$x,$y,${#pack},${#esc1}:$pack$esc1"
    esc=$esc$esc1

    # 候補と候補の間の空白
    if ((++i<N)); then
      ((icell=x==0?0:(x+wcell)/wcell))
      if ((icell<ncell)); then
        # 次の升目
        ble/string#reserve-prototype $((pad=icell*wcell-x))
        esc=$esc${_ble_string_prototype::pad}
        ((x=icell*wcell))
      else
        # 次の行
        esc=$esc$'\n'
        ((x=0,++y>=lines)) && break
      fi
    fi
  done
}
function ble-complete/menu/style:align-nowrap/construct {
  ble-complete/menu/style:align/construct
}

## 関数 ble-complete/menu/style:dense/construct
##   complete_menu_style=align{,-nowrap} に対して候補を配置します。
function ble-complete/menu/style:dense/construct {
  local ret iloop=0

  x=0 y=0 esc= menu_items=()

  local pack i=0 N=${#cand_pack[@]}
  for pack in "${cand_pack[@]}"; do
    ((iloop++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

    local x0=$x y0=$y esc1
    ble-complete/menu/construct-single-entry "$pack"; esc1=$ret
    ((y>=lines&&(x=x0,y=y0,1))) && return

    if [[ $menu_style == dense-nowrap ]]; then
      if ((y>y0&&x>0)); then
        ((y=++y0,x=x0=0))
        esc=$esc$'\n'
        ble-complete/menu/construct-single-entry "$pack"; esc1=$ret
        ((y>=lines&&(x=x0,y=y0,1))) && return
      fi
    fi

    ble/array#push menu_items "$x0,$y0,$x,$y,${#pack},${#esc1}:$pack$esc1"
    esc=$esc$esc1

    # 候補と候補の間の空白
    if ((++i<N)); then
      if [[ $menu_style == nowrap ]] && ((x==0)); then
        : skip
      elif ((x+1<cols)); then
        esc=$esc' '
        ((x++))
      else
        esc=$esc$'\n'
        ((x=0,++y>=lines)) && break
      fi
    fi
  done
}
function ble-complete/menu/style:dense-nowrap/construct {
  ble-complete/menu/style:dense/construct
}

function bleopt/check:complete_menu_style {
  if ! ble/is-function "ble-complete/menu/style:$value/construct"; then
    echo "bleopt: Invalid value complete_menu_style='$value'. A function 'ble-complete/menu/style:$value/construct' is not defined." >&2
    return 1
  fi
}

function ble-complete/menu/clear {
  if [[ $_ble_complete_menu_active ]]; then
    _ble_complete_menu_active=
    ble-edit/info/immediate-clear
  fi
}

## 関数 ble-complete/menu/show opts
##   @param[in] opts
##   @arr[in] cand_pack
##
##   @var[in] COMPV
##     入力済み部分を着色するのに使用します。
##   @var[in] comp_type
##     曖昧一致候補かどうかを確認するのに使用します。
function ble-complete/menu/show {
  local opts=$1

  # settings
  local menu_style=$bleopt_complete_menu_style
  local cols lines menu_common_part
  ble-complete/menu/initialize

  if ((${#cand_pack[@]})); then
    local x y esc menu_items
    ble/function#try ble-complete/menu/style:"$menu_style"/construct; local ext=$?
    ((ext)) && return "$ext"

    info_data=(store "$x" "$y" "$esc")
  else
    menu_items=()
    info_data=(raw $'\e[38;5;242m(no candidates)\e[m')
  fi

  ble-edit/info/immediate-show "${info_data[@]}"
  _ble_complete_menu_info_data=("${info_data[@]}")
  _ble_complete_menu_items=("${menu_items[@]}")
  if [[ :$opts: != *:filter:* ]]; then
    _ble_complete_menu_beg=$COMP1
    _ble_complete_menu_end=$_ble_edit_ind
    _ble_complete_menu_str=$_ble_edit_str
    _ble_complete_menu_selected=-1
    _ble_complete_menu_active=1
    _ble_complete_menu_common_part=$menu_common_part
    _ble_complete_menu_pack=("${cand_pack[@]}")
    _ble_complete_menu_filter=
  fi
}

function ble-complete/menu/redraw {
  if [[ $_ble_complete_menu_active ]]; then
    ble-edit/info/immediate-show "${_ble_complete_menu_info_data[@]}"
  fi
}

## ble-complete/menu/get-active-range [str [ind]]
##   @param[in,opt] str ind
##   @var[out] beg end
function ble-complete/menu/get-active-range {
  [[ $_ble_complete_menu_active ]] || return 1

  local str=${1-$_ble_edit_str} ind=${2-$_ble_edit_ind}
  local mbeg=$_ble_complete_menu_beg
  local mend=$_ble_complete_menu_end
  local left=${_ble_complete_menu_str::mend}
  local right=${_ble_complete_menu_str:mend}
  if [[ ${str::_ble_edit_ind} == "$left"* && ${str:_ble_edit_ind} == *"$right" ]]; then
    ((beg=mbeg,end=${#str}-${#right}))
    return 0
  else
    ble-complete/menu/clear
    return 1
  fi
}

#------------------------------------------------------------------------------
# 補完

## 関数 ble-complete/insert insert_beg insert_end insert suffix
function ble-complete/insert {
  local insert_beg=$1 insert_end=$2
  local insert=$3 suffix=$4
  local original_text=${_ble_edit_str:insert_beg:insert_end-insert_beg}

  # 編集範囲の最小化
  local insert_replace=
  if [[ $insert == "$original_text"* ]]; then
    # 既存部分の置換がない場合
    insert=${insert:insert_end-insert_beg}
    ((insert_beg=insert_end))
  else
    # 既存部分の置換がある場合
    local ret; ble/string#common-prefix "$insert" "$original_text"
    if [[ $ret ]]; then
      insert=${insert:${#ret}}
      ((insert_beg+=${#ret}))
    fi
  fi

  if ble/util/test-rl-variable skip-completed-text; then
    # カーソルの右のテキストの吸収
    if [[ $insert ]]; then
      local right_text=${_ble_edit_str:insert_end}
      right_text=${right_text%%[$IFS]*}
      if ble/string#common-prefix "$insert" "$right_text"; [[ $ret ]]; then
        # カーソルの右に先頭一致する場合に吸収
        ((insert_end+=${#ret}))
      elif ble-complete/string#common-suffix-prefix "$insert" "$right_text"; [[ $ret ]]; then
        # カーソルの右に末尾一致する場合に吸収
        ((insert_end+=${#ret}))
      fi
    fi

    # suffix の吸収
    if [[ $suffix ]]; then
      local right_text=${_ble_edit_str:insert_end}
      if ble/string#common-prefix "$suffix" "$right_text"; [[ $ret ]]; then
        ((insert_end+=${#ret}))
      elif ble-complete/string#common-suffix-prefix "$suffix" "$right_text"; [[ $ret ]]; then
        ((insert_end+=${#ret}))
      fi
    fi
  fi

  local ins=$insert$suffix
  ble/widget/.replace-range "$insert_beg" "$insert_end" "$ins" 1
  ((_ble_edit_ind=insert_beg+${#ins},
    _ble_edit_ind>${#_ble_edit_str}&&
      (_ble_edit_ind=${#_ble_edit_str})))
}

function ble/widget/complete {
  local opts=$1
  ble-edit/content/clear-arg

  if [[ :$opts: == *:enter_menu:* ]]; then
    [[ $_ble_complete_menu_active ]] &&
      ble-complete/menu-complete/enter && return
  elif [[ $bleopt_complete_menu_complete ]]; then
    [[ $_ble_complete_menu_active && $_ble_edit_str == "$_ble_complete_menu_str" ]] &&
      ble-complete/menu-complete/enter && return
    [[ $WIDGET == "$LASTWIDGET" ]] && opts=$opts:enter_menu
  fi

  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  local contexts
  ble-complete/candidates/get-contexts "$comp_text" "$comp_index" || return 1

  local COMP1 COMP2 COMPS COMPV comp_type=
  local comps_flags
  local rex_ambiguous_compv
  local cand_count
  local -a cand_cand cand_word cand_pack
  ble-complete/candidates/generate; local ext=$?
  if ((ext==148)); then
    return 148
  elif ((ext!=0)); then
    ble/widget/.bell
    ble-edit/info/clear
    return 1
  fi

  local ret
  ble-complete/candidates/determine-common-prefix; local insert=$ret suffix=
  local insert_beg=$COMP1 insert_end=$COMP2
  local insert_flags=
  [[ $insert == "$COMPS"* ]] || insert_flags=r

  if [[ :$opts: == *:enter_menu:* ]]; then
    ble-complete/menu/show
    (($?==148)) && return 148
    ble-complete/menu-complete/enter; local ext=$?
    ((ext==148)) && return 148
    ((ext)) && ble/widget/.bell
    return
  elif [[ :$opts: == *:show_menu:* ]]; then
    ble-complete/menu/show
    (($?==148)) && return 148
    return
  fi

  if ((cand_count==1)); then
    # 一意確定の時
    local ACTION=${cand_pack[0]%%:*}
    if ble/is-function ble-complete/action:"$ACTION"/complete; then
      local "${_ble_complete_cand_varnames[@]}"
      ble-complete/cand/unpack "${cand_pack[0]}"
      ble-complete/action:"$ACTION"/complete
      (($?==148)) && return 148
    fi
  else
    # 候補が複数ある時
    insert_flags=${insert_flags}m
  fi

  ble/util/invoke-hook _ble_complete_insert_hook
  ble-complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"

  if [[ $insert_flags == *m* ]]; then
    ble-complete/menu/show
    (($?==148)) && return 148
  elif [[ $insert_flags == *n* ]]; then
    ble/widget/complete show_menu
  else
    ble-complete/menu/clear
  fi
}

function ble/widget/complete-insert {
  local original=$1 insert=$2 suffix=$3
  [[ ${_ble_edit_str::_ble_edit_ind} == *"$original" ]] || return 1

  local insert_beg=$((_ble_edit_ind-${#original}))
  local insert_end=$_ble_edit_ind
  ble-complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
}

function ble/widget/menu-complete {
  ble/widget/complete enter_menu
}

#------------------------------------------------------------------------------
# menu-filter

function ble-complete/menu/filter-incrementally {
  if [[ $_ble_decode_keymap == emacs || $_ble_decode_keymap == vi_imap ]]; then
    local str=$_ble_edit_str
  elif [[ $_ble_decode_keymap == auto_complete ]]; then
    local str=${_ble_edit_str::_ble_edit_ind}${_ble_edit_str:_ble_edit_mark}
  elif [[ $_ble_decode_keymap == menu_complete ]]; then
    return 0
  else
    return 1
  fi

  local beg end; ble-complete/menu/get-active-range "$str" "$_ble_edit_ind" || return 1
  local input=${str:beg:end-beg}
  [[ $input == "$_ble_complete_menu_filter" ]] && return 0

  local ret close_type
  ble-syntax:bash/simple-word/close-open-word "$input" || return 1
  ble-syntax:bash/simple-word/eval "$ret"
  local COMPV=$ret

  local iloop=0 interval=$bleopt_complete_stdin_frequency

  local comp_type=
  local -a cand_pack; cand_pack=()
  local pack "${_ble_complete_cand_varnames[@]}"
  for pack in "${_ble_complete_menu_pack[@]}"; do
    ((iloop++%interval==0)) && ble-complete/check-cancel && return 148
    ble-complete/cand/unpack "$pack"
    [[ $CAND == "$COMPV"* ]] &&
      ble/array#push cand_pack "$pack"
  done

  if ((${#cand_pack[@]}==0)); then
    # 曖昧一致
    local ret; ble-complete/util/construct-ambiguous-regex "$COMPV"; local rex=^$ret
    for pack in "${_ble_complete_menu_pack[@]}"; do
      ((iloop++%interval==0)) && ble-complete/check-cancel && return 148
      ble-complete/cand/unpack "$pack"
      [[ $CAND =~ $rex ]] &&
        ble/array#push cand_pack "$pack"
    done
    ((${#cand_pack[@]})) && comp_type=${comp_type}a
  fi

  ble-complete/menu/show filter
  (($?==148)) && return 148
  _ble_complete_menu_filter=$input
  return 0
}

function ble-complete/menu-filter.idle {
  ble/util/idle.wait-user-input
  [[ $_ble_complete_menu_active ]] || return
  ble-complete/menu/filter-incrementally; local ext=$?
  ((ext==148)) && return 148
  ((ext)) && ble-complete/menu/clear
}

ble/function#try ble/util/idle.push-background ble-complete/menu-filter.idle

#------------------------------------------------------------------------------
#
# menu-complete
#

## メニュー補完では以下の変数を参照する
##
##   @var[in] _ble_complete_menu_beg
##   @var[in] _ble_complete_menu_end
##   @var[in] _ble_complete_menu_original
##   @var[in] _ble_complete_menu_selected
##   @var[in] _ble_complete_menu_common_part
##   @arr[in] _ble_complete_menu_items
##
## 更に以下の変数を使用する
##
##   @var[in,out] _ble_complete_menu_original=

_ble_complete_menu_original=

ble-color-defface menu_complete fg=12,bg=252
function ble-highlight-layer:region/mark:menu_complete/get-sgr {
  ble-color-face2sgr menu_complete
}

function ble-complete/menu-complete/select {
  local osel=$_ble_complete_menu_selected nsel=$1
  ((osel==nsel)) && return

  local infox infoy
  ble-form/panel#get-origin 1 --prefix=info

  local -a DRAW_BUFF=()
  local x0=$_ble_line_x y0=$_ble_line_y
  if ((osel>=0)); then
    # 消去
    local entry=${_ble_complete_menu_items[osel]}
    local fields text=${entry#*:}
    ble/string#split fields , "${entry%%:*}"

    ble-form/panel#goto.draw 1 "${fields[@]::2}"
    ble-edit/draw/put "${text:fields[4]}"
    _ble_line_x=${fields[2]} _ble_line_y=$((infoy+fields[3]))
  fi

  local value=
  if ((nsel>=0)); then
    local entry=${_ble_complete_menu_items[nsel]}
    local fields text=${entry#*:}
    ble/string#split fields , "${entry%%:*}"

    local x=${fields[0]} y=${fields[1]}
    ble-form/panel#goto.draw 1 "$x" "$y"

    local "${_ble_complete_cand_varnames[@]}"
    ble-complete/cand/unpack "${text::fields[4]}"
    value=$INSERT

    # construct reverted candidate
    local ret cols lines menu_common_part
    ble-edit/info/.initialize-size
    menu_common_part=$_ble_complete_menu_common_part
    ble-complete/menu/construct-single-entry - selected:use_vars
    ble-edit/draw/put "$ret"
    _ble_line_x=$x _ble_line_y=$((infoy+y))

    _ble_complete_menu_selected=$nsel
  else
    _ble_complete_menu_selected=-1
    value=$_ble_complete_menu_original
  fi
  ble-form/goto.draw "$x0" "$y0"
  ble-edit/draw/bflush

  ble-edit/content/replace "$_ble_edit_mark" "$_ble_edit_ind" "$value"
  ((_ble_edit_ind=_ble_edit_mark+${#value}))
}

#ToDo:mark_active menu_complete の着色の定義
function ble-complete/menu-complete/enter {
  [[ ${#_ble_complete_menu_items[@]} -ge 1 ]] || return 1

  local beg end; ble-complete/menu/get-active-range || return 1
  _ble_edit_mark=$beg
  _ble_edit_ind=$end
  _ble_complete_menu_original=${_ble_edit_str:beg:end-beg}
  ble-complete/menu/redraw
  ble-complete/menu-complete/select 0

  _ble_edit_mark_active=menu_complete
  ble-decode/keymap/push menu_complete
}

function ble/widget/menu_complete/forward {
  local opts=$1
  local nsel=$((_ble_complete_menu_selected+1))
  local ncand=${#_ble_complete_menu_items[@]}
  if ((nsel>=ncand)); then
    if [[ :$opts: == *:cyclic:* ]] && ((ncand>=2)); then
      nsel=0
    else
      ble/widget/.bell "menu-complete: no more candidates"
      return 1
    fi
  fi
  ble-complete/menu-complete/select "$nsel"
}
function ble/widget/menu_complete/backward {
  local opts=$1
  local nsel=$((_ble_complete_menu_selected-1))
  if ((nsel<0)); then
    local ncand=${#_ble_complete_menu_items[@]}
    if [[ :$opts: == *:cyclic:* ]] && ((ncand>=2)); then
      ((nsel=ncand-1))
    else
      ble/widget/.bell "menu-complete: no more candidates"
      return 1
    fi
  fi
  ble-complete/menu-complete/select "$nsel"
}
function ble/widget/menu_complete/forward-line {
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return
  local entry=${_ble_complete_menu_items[osel]}
  local fields; ble/string#split fields , "${entry%%:*}"
  local ox=${fields[0]} oy=${fields[1]}
  local i=$osel nsel=-1
  for entry in "${_ble_complete_menu_items[@]:osel+1}"; do
    ble/string#split fields , "${entry%%:*}"
    local x=${fields[0]} y=${fields[1]}
    ((y<=oy||y==oy+1&&x<=ox||nsel<0)) || break
    ((++i,y>oy&&(nsel=i)))
  done

  if ((nsel>=0)); then
    ble-complete/menu-complete/select "$nsel"
  else
    ble/widget/.bell 'menu-complete: no more candidates'
    return 1
  fi
}
function ble/widget/menu_complete/backward-line {
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return
  local entry=${_ble_complete_menu_items[osel]}
  local fields; ble/string#split fields , "${entry%%:*}"
  local ox=${fields[0]} oy=${fields[1]}
  local i=-1 nsel=-1
  for entry in "${_ble_complete_menu_items[@]::osel}"; do
    ble/string#split fields , "${entry%%:*}"
    local x=${fields[0]} y=${fields[1]}
    ((y<oy-1||y==oy-1&&x<=ox||y<oy&&nsel<0)) || break
    ((++i,nsel=i))
  done

  if ((nsel>=0)); then
    ble-complete/menu-complete/select "$nsel"
  else
    ble/widget/.bell 'menu-complete: no more candidates'
    return 1
  fi
}

function ble/widget/menu_complete/accept {
  ble-decode/keymap/pop
  ble-complete/menu/clear
  _ble_edit_mark_active=
}
function ble/widget/menu_complete/cancel {
  ble-decode/keymap/pop
  ble-complete/menu-complete/select -1
  _ble_edit_mark_active=
}
function ble/widget/menu_complete/exit-default {
  ble/widget/menu_complete/accept
  ble-decode-key "${KEYS[@]}"
}

function ble-decode/keymap:menu_complete/define {
  local ble_bind_keymap=menu_complete

  # ble-bind -f __defchar__ menu_complete/self-insert
  ble-bind -f __default__ 'menu_complete/exit-default'
  ble-bind -f C-m         'menu_complete/accept'
  ble-bind -f RET         'menu_complete/accept'
  ble-bind -f C-g         'menu_complete/cancel'
  ble-bind -f C-f         'menu_complete/forward'
  ble-bind -f right       'menu_complete/forward'
  ble-bind -f C-i         'menu_complete/forward cyclic'
  ble-bind -f TAB         'menu_complete/forward cyclic'
  ble-bind -f C-b         'menu_complete/backward'
  ble-bind -f left        'menu_complete/backward'
  ble-bind -f C-S-i       'menu_complete/backward cyclic'
  ble-bind -f S-TAB       'menu_complete/backward cyclic'
  ble-bind -f C-n         'menu_complete/forward-line'
  ble-bind -f down        'menu_complete/forward-line'
  ble-bind -f C-p         'menu_complete/backward-line'
  ble-bind -f up          'menu_complete/backward-line'
}

#------------------------------------------------------------------------------
#
# auto-complete
#

function ble-complete/auto-complete/initialize {
  ble-color-defface auto_complete fg=247

  local ret
  ble-decode-kbd/generate-keycode auto_complete_enter
  _ble_complete_KCODE_ENTER=$ret
}
ble-complete/auto-complete/initialize

function ble-highlight-layer:region/mark:auto_complete/get-sgr {
  ble-color-face2sgr auto_complete
}

_ble_complete_ac_type=
_ble_complete_ac_comp1=
_ble_complete_ac_cand=
_ble_complete_ac_word=
_ble_complete_ac_insert=
_ble_complete_ac_suffix=
## 関数 ble-complete/auto-complete.impl opts
##   @param[in] opts
#      コロン区切りのオプションのリストです。
##     sync   ユーザ入力があっても処理を中断しない事を指定します。
function ble-complete/auto-complete.impl {
  local opts=$1
  local comp_type=
  [[ :$opts: == *:sync:* ]] && comp_type=${comp_type}s

  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  [[ $comp_text ]] || return 0

  local contexts
  ble-complete/candidates/get-prefix-contexts "$comp_text" "$comp_index" || return 0

  # ble-complete/candidates/generate 設定
  local bleopt_complete_contract_function_names=
  ((bleopt_complete_stdin_frequency>25)) &&
    local bleopt_complete_stdin_frequency=25
  local COMP1 COMP2 COMPS COMPV
  local comps_flags
  local rex_ambiguous_compv
  local cand_count
  local -a cand_cand cand_word cand_pack
  ble-complete/candidates/generate
  [[ $COMPV ]] || return 0
  ((ext)) && return "$ext"

  ((cand_count)) || return

  _ble_complete_ac_comp1=$COMP1
  _ble_complete_ac_cand=${cand_cand[0]}
  _ble_complete_ac_word=${cand_word[0]}
  [[ $_ble_complete_ac_word == "$COMPS" ]] && return

  # addtail 等の修飾
  local insert=$_ble_complete_ac_word suffix=
  local ACTION=${cand_pack[0]%%:*}
  if ble/is-function ble-complete/action:"$ACTION"/complete; then
    local "${_ble_complete_cand_varnames[@]}"
    ble-complete/cand/unpack "${cand_pack[0]}"
    ble-complete/action:"$ACTION"/complete
  fi
  _ble_complete_ac_insert=$insert
  _ble_complete_ac_suffix=$suffix

  if [[ $_ble_complete_ac_word == "$COMPS"* ]]; then
    # 入力候補が既に続きに入力されている時は提示しない
    [[ ${comp_text:COMP1} == "$_ble_complete_ac_word"* ]] && return

    _ble_complete_ac_type=c
    local ins=${insert:${#COMPS}}
    ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
    ((_ble_edit_mark=_ble_edit_ind+${#ins}))
  else
    if [[ $comp_type == *a* ]]; then
      _ble_complete_ac_type=a
    else
      _ble_complete_ac_type=r
    fi
    ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" " [$insert] "
    ((_ble_edit_mark=_ble_edit_ind+4+${#insert}))
  fi

  _ble_edit_mark_active=auto_complete
  ble-decode/keymap/push auto_complete
  ble-decode-key "$_ble_complete_KCODE_ENTER" # dummy key input to record keyboard macros
  return
}

## 背景関数 ble/widget/auto-complete.idle
function ble-complete/auto-complete.idle {
  # ※特に上書きしなければ常に wait-user-input で抜ける。
  ble/util/idle.wait-user-input

  [[ $_ble_decode_keymap == emacs || $_ble_decode_keymap == vi_imap ]] || return 0

  case $_ble_decode_widget_last in
  (ble/widget/self-insert) ;;
  (ble/widget/complete) ;;
  (ble/widget/vi_imap/complete) ;;
  (*) return 0 ;;
  esac

  [[ $_ble_edit_str ]] || return 0

  # bleopt_complete_auto_delay だけ経過してから処理
  local rest_delay=$((bleopt_complete_auto_delay-ble_util_idle_elapsed))
  if ((rest_delay>0)); then
    ble/util/idle.sleep "$rest_delay"
    return
  fi

  ble-complete/auto-complete.impl
}

ble/function#try ble/util/idle.push-background ble-complete/auto-complete.idle

## 編集関数 ble/widget/auto-complete-enter
##
##   Note:
##     キーボードマクロで自動補完を明示的に起動する時に用いる編集関数です。
##     auto-complete.idle に於いて ble-decode-key を用いて
##     キー auto_complete_enter を発生させ、
##     再生時にはこのキーを通して自動補完が起動されます。
##
function ble/widget/auto-complete-enter {
  ble-complete/auto-complete.impl sync
}
function ble/widget/auto_complete/cancel {
  ble-decode/keymap/pop
  ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_mark" ''
  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
}
function ble/widget/auto_complete/accept {
  ble-decode/keymap/pop
  ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_mark" ''

  local comp_text=$_ble_edit_str
  local insert_beg=$_ble_complete_ac_comp1
  local insert_end=$_ble_edit_ind
  local insert=$_ble_complete_ac_insert
  local suffix=$_ble_complete_ac_suffix
  ble/util/invoke-hook _ble_complete_insert_hook
  ble-complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"

  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
  ble-complete/menu/clear
  ble-edit/content/clear-arg
}
function ble/widget/auto_complete/exit-default {
  ble/widget/auto_complete/cancel
  ble-decode-key "${KEYS[@]}"
}
function ble/widget/auto_complete/self-insert {
  local code=$((KEYS[0]&ble_decode_MaskChar))
  ((code==0)) && return

  local ret

  # もし挿入によって現在の候補が変わらないのであれば、
  # 候補を表示したまま挿入を実行する。
  ble/util/c2s "$code"; local ins=$ret
  local comps_cur=${_ble_edit_str:_ble_complete_ac_comp1:_ble_edit_ind-_ble_complete_ac_comp1}
  local comps_new=$comps_cur$ins
  if [[ $_ble_complete_ac_type == c ]]; then
    # c: 入力済み部分が補完結果の先頭に含まれる場合
    #   挿入した後でも補完結果の先頭に含まれる場合、その文字数だけ確定。
    if [[ $_ble_complete_ac_word == "$comps_new"* ]]; then
      ((_ble_edit_ind+=${#ins}))

      # Note: 途中で完全一致した場合は tail を挿入せずに終了する事にする
      [[ ! $_ble_complete_ac_word ]] && ble/widget/auto_complete/cancel
      return
    fi
  elif [[ $_ble_complete_ac_type == [ra] ]]; then
    if local ret close_type; ble-syntax:bash/simple-word/close-open-word "$comps_new"; then
      ble-syntax:bash/simple-word/eval "$ret"; local compv_new=$ret
      if [[ $_ble_complete_ac_type == r ]]; then
        # r: 遡って書き換わる時
        #   挿入しても展開後に一致する時、そのまま挿入。
        #   元から展開後に一致していない場合もあるが、その場合は一旦候補を消してやり直し。
        if [[ $_ble_complete_ac_cand == "$compv_new"* ]]; then
          ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
          ((_ble_edit_ind+=${#ins},_ble_edit_mark+=${#ins}))
          [[ $_ble_complete_ac_cand == "$compv_new" ]] &&
            ble/widget/auto_complete/cancel
          return
        fi
      elif [[ $_ble_complete_ac_type == a ]]; then
        # a: 曖昧一致の時
        #   文字を挿入後に展開してそれが曖昧一致する時、そのまま挿入。
        ble-complete/util/construct-ambiguous-regex "$compv_new"
        local rex_ambiguous_compv=^$ret
        if [[ $_ble_complete_ac_cand =~ $rex_ambiguous_compv ]]; then
          ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
          ((_ble_edit_ind+=${#ins},_ble_edit_mark+=${#ins}))
          return
        fi
      fi
    fi
  fi

  ble/widget/auto_complete/cancel
  ble-decode-key "${KEYS[@]}"
}
function ble-decode/keymap:auto_complete/define {
  local ble_bind_keymap=auto_complete

  ble-bind -f __defchar__ auto_complete/self-insert
  ble-bind -f __default__ auto_complete/exit-default
  ble-bind -f C-g         auto_complete/cancel
  ble-bind -f S-RET       auto_complete/accept
  ble-bind -f S-C-m       auto_complete/accept
  ble-bind -f auto_complete_enter nop
}

#------------------------------------------------------------------------------
# default cmdinfo/complete

function ble/cmdinfo/complete:cd/.impl {
  local type=$1
  [[ $comps_flags == *v* ]] || return 1

  if [[ $COMPV == -* ]]; then
    local action=word
    case $type in
    (pushd)
      if [[ $COMPV == - || $COMPV == -n ]]; then
        ble-complete/cand/yield "$action" -n
      fi ;;
    (*)
      COMP_PREFIX=$COMPV
      local -a list=()
      [[ $COMPV == -* ]] && ble-complete/cand/yield "$action" "${COMPV}"
      [[ $COMPV != *L* ]] && ble-complete/cand/yield "$action" "${COMPV}L"
      [[ $COMPV != *P* ]] && ble-complete/cand/yield "$action" "${COMPV}P"
      ((_ble_bash>=40200)) && [[ $COMPV != *e* ]] && ble-complete/cand/yield "$action" "${COMPV}e"
      ((_ble_bash>=40300)) && [[ $COMPV != *@* ]] && ble-complete/cand/yield "$action" "${COMPV}@" ;;
    esac
    return
  fi

  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  ble-complete/source:dir

  if [[ $CDPATH ]]; then
    local names; ble/string#split names : "$CDPATH"
    local name
    for name in "${names[@]}"; do
      [[ $name ]] || continue
      name=${name%/}/

      local ret cand
      ble-complete/source:file/.construct-pathname-pattern "$COMPV"
      ble-complete/util/eval-pathname-expansion "$name/$ret"
      for cand in "${ret[@]}"; do
        [[ $cand && -d $cand ]] || continue
        [[ $cand == / ]] || cand=${cand%/}
        cand=${cand#"$name"/}
        [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
        ble-complete/cand/yield file "$cand"
      done
    done
  fi
}
function ble/cmdinfo/complete:cd {
  ble/cmdinfo/complete:cd/.impl cd
}
function ble/cmdinfo/complete:pushd {
  ble/cmdinfo/complete:cd/.impl pushd
}

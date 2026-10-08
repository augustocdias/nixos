# Claude Code status line. Input: the statusLine JSON on stdin; $branch from
# the wrapper (git is not part of the payload).
def esc($c): "\u001b[\($c)m";
def paint($c; $s): esc($c) + $s + esc("0");
def dim($s): paint("2"; $s);
def level($p): if $p >= 90 then "31" elif $p >= 70 then "33" else "32" end;

def left($t):
  (($t - now) | floor) as $s
  | if $s <= 0 then "now"
    elif $s >= 86400 then "\($s / 86400 | floor)d\(($s % 86400) / 3600 | floor)h"
    elif $s >= 3600 then "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor)m"
    else "\(($s + 59) / 60 | floor)m"
    end;

def limit($label; $w):
  if $w.used_percentage == null then empty
  else paint(level($w.used_percentage); "\($label) \($w.used_percentage | round)%")
    + (if $w.resets_at then dim(" ↻\(left($w.resets_at))") else "" end)
  end;

[
  paint("1;35"; .model.display_name // "?")
    + (if .effort.level then dim(" \(.effort.level)") else "" end),

  (if .agent.name then paint("36"; "@\(.agent.name)") else empty end),

  paint("34"; (.workspace.current_dir // .cwd) | split("/") | last)
    + (if $branch != "" then paint("33"; " \($branch)") else "" end),

  (.context_window.used_percentage as $c
   | if $c == null then empty else paint(level($c); "ctx \($c | round)%") end),

  limit("5h"; .rate_limits.five_hour),
  limit("7d"; .rate_limits.seven_day),
  limit("$"; .rate_limits.spend_limit),

  (.cost as $k
   | if (($k.total_lines_added // 0) + ($k.total_lines_removed // 0)) == 0 then empty
     else paint("32"; "+\($k.total_lines_added)") + dim("/") + paint("31"; "-\($k.total_lines_removed)")
     end)
]
| join(dim(" · "))

#!/bin/sh
#
#------------------------------------------------------------------------
#
#    Copyright (C) 1985-2018  Georg Umgiesser
#
#    This file is part of SHYFEM.
#
#------------------------------------------------------------------------
#
# computes running time and estimates time to complete from log file
#
# revision log :
#
# 01.01.2017	ggu	started from scratch
# 05.03.2018	ggu	adapted to new write statement of shyfem
# 30.05.2018	ggu	more info to terminal (end date)
# 03.04.2020	ggu	use new time format
#
# still to do: command line options:
#
#	-running	show only running processes
#	-finished	show only finished processes
#
#----------------------------------------------------------------

debug=0
if [ "$1" = "-debug" ]; then
  debug=1
  shift
fi

if [ $# -eq 0 ]; then
  echo "Usage: $0 [-debug] log-file(s)"
  exit 1
fi

server=$( hostname )

#----------------------------------------------------------------

Convertsecs() 
{
    h=$(($1/3600))
    m=$((($1/60)%60))
    s=$(($1%60))
    printf "%02d:%02d:%02d" $h $m $s
}

ConvertToIso()
{
  local orig="$1"
  nohost=$( echo $orig | sed -e 's/ *- .*//' )
  clean=$( echo $nohost | sed -E 's/.*: +//' )
  echo "$clean"
}

ConvertToSecs()
{
  local orig="$1"
  clean=$( echo $orig | sed -E 's/::/ /' )
  secs=$( date -u -d "$clean" +"%s" )
  echo "$secs"
}

#----------------------------------------------------------------

GetStartTime()
{
  start_line=$( head -5 $1 | grep "simulation time:" )
  [ $? -eq 0 ] && return 0

  start_line=$( head -30 $1 | grep "simulation start:" )
  [ $? -eq 0 ] && return 0

  start_line=""
  return 1
}

GetEndTime()
{
  end_line=$( tail -5 $1 | grep "simulation end:" )
  [ $? -eq 0 ] && return 0

  end_line=$( tail -15 $1 | grep "simulation end:" )
  [ $? -eq 0 ] && return 0

  end_line=""
  return 1
}

GetRunningTime()
{
  file=$1

  local today=$( date +%Y-%m-%d )
  local time=$( date +%H:%M:%S )
  real_time="$today::$time"
}

GetIterations()
{
  file=$1

  #last_line=$( tail -5 $file | head -1 )
  last_line=$( tail -5 $file | head -1 | tr -s ' ' )

  perc=$( echo $last_line | sed -E 's/.*[0-9]\s+//' )	#look for % sign

  if [ "$perc" = "%" ]; then
    iter1=$( echo $last_line | sed -E 's/\s*\/.*\%//' | sed -E 's/.*\s//' )
    iter2=$( echo $last_line | sed -E 's/.*\/\s*//' | sed -E 's/\s.*//' )
    #echo "iter 1/2: $iter1 $iter2"
  else
    return 1
  fi

  return 0
}

#----------------------------------------------------------------

HandleSimulation()
{
  file=$1

  GetStartTime $file
  if [ $? -ne 0 ]; then
    echo "$file: *** error: not a log file"
    return 3
  fi

  GetEndTime $file
  if [ $? -eq 0 ]; then
    HandleFinishedSimulation
    return 0
  fi

  GetIterations $file
  if [ $? -eq 0 ]; then
    GetRunningTime $file
    HandleRunningSimulation $file
    return 0
  else
    echo "$file:  error determining iterations... run again"
    return 5
  fi
}

HandleFinishedSimulation()
{
  start_time=$( ConvertToIso "$start_line" )
  end_time=$( ConvertToIso "$end_line" )

  start_secs=$( ConvertToSecs "$start_time" )
  end_secs=$( ConvertToSecs "$end_time" )

  done_secs=$(( end_secs - start_secs ))

  WriteDebugInfo
  echo "$file:  total: $done_secs  finished at $end_time UTC"
}

HandleRunningSimulation()
{

  start_time=$( ConvertToIso "$start_line" )
  start_secs=$( ConvertToSecs "$start_time" )
  real_secs=$( ConvertToSecs "$real_time" )

  done_secs=$(( real_secs - start_secs ))

  est_secs=$(( $iter2 * $done_secs / $iter1 ))
  todo_secs=$(( $est_secs - $done_secs ))

  done=$( Convertsecs $done_secs )
  todo=$( Convertsecs $todo_secs )
  total=$( Convertsecs $est_secs )

  WriteDebugInfo
  echo "$file:  total: $total  done: $done  todo: $todo"
}

#----------------------------------------------------------------

WriteDebugInfo()
{
  [ $debug -eq 0 ] && return

  echo "--------------------------------------------"
  echo "debug info:"
  echo "--------------------------------------------"

  echo "start_line: $start_line"
  echo "end_line:   $end_line"
  echo "start_time: $start_time"
  echo "end_time:   $end_time"
  echo "real_time:  $real_time"
  echo "last:  $last_line"
  echo "perc:  $perc_line"
  echo "iterations: $iter1 - $iter2"

  echo "start secs: $start_secs"
  echo "end secs:   $end_secs"
  echo "real_secs:  $real_secs"
  echo "done secs:  $done_secs"
  echo "est secs:   $est_secs"
  echo "todo secs:  $todo_secs"

  echo "--------------------------------------------"
}

#----------------------------------------------------------------

files=$( ls $* 2> /dev/null )
if [ $? -ne 0 ]; then
  echo "no such files: $*"
  exit 1
fi

for file in $files
do
  #echo "estimating $file"
  HandleSimulation $file
done

#----------------------------------------------------------------


##############################################################################################
# Name    : nsi_lib_func.sh
# Author  : Naman Saraswat | Maninder Singh
# Purpose : Utility functions for JFR and Heap Dump
# Note:
#   This shell contains library functions which is copied from ns_check_monitor_func.sh
##############################################################################################


lib_normal_kill_process()
{
  pid=$1

  lib_trace_log "$CALLING_FUN_NAME" "lib_normal_kill_process(), Method called, pid = $pid"
  $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null
  if [ $? != 0 ]; then
    lib_trace_log "$CALLING_FUN_NAME" "Monitor process/child whose PID = $pid is already stopped"
    return
  fi

  kill $pid  2>/dev/null
}

lib_post_kill_process()
{
  pid=$1

  lib_trace_log "$CALLING_FUN_NAME" "lib_post_kill_process(), Method called, pid = $pid"
  name=`$LIB_PS_CMD_FOR_DATA -p $pid -o 'ppid stime args' | tail -1 2>&1`
  lib_trace_log "$CALLING_FUN_NAME" "Killed monitor whose PID = $pid and parent pid, start time and args = $name"
  $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null
  if [ $? = 0 ]; then
    lib_trace_log "$CALLING_FUN_NAME" "Monitor with PID = $pid and parent pid, start time and args = $name still Running. Attempting to Kill using -9 .... "
    kill -9 $pid 2>&1
    if [ $? = 0 ]; then
     lib_trace_log "$CALLING_FUN_NAME" "Killed monitor whose PID = $pid and parent pid, start time and args = $name killed successfully."
    fi
  else
    lib_trace_log "$CALLING_FUN_NAME" "PID = $pid killed successfully in normal kill. "
  fi
}


#This method get pid, check whether pid is running , if not then return else kill child and then process_id
lib_kill_ps_tree_by_pattern()
{
  CALLING_FUN_NAME=$1
  PID_LIST=`lib_get_ps_id_by_pattern "$@"`
  lib_trace_log "$CALLING_FUN_NAME" "PID_LIST=[$PID_LIST]"
  #echo "PID_LIST = $PID_LIST"  
  SELF_PID=$$
  PARENT_PID=$PPID
  if [ "X$PID_LIST" = "X" ];then
   return
  else
    for p_pid in `echo $PID_LIST`
    do
      if [ $p_pid = $SELF_PID ]; then
        lib_trace_log "$CALLING_FUN_NAME" "Self p_pid $p_pid , continue"
        continue
      fi
      if [ $p_pid = $PARENT_PID ]; then
        lib_trace_log "$CALLING_FUN_NAME" "Parent p_pid $p_pid , continue"
        continue
      fi
      ps -p $p_pid >/dev/null
      if [ $? -ne 0 ];then
        lib_trace_log  "$CALLING_FUN_NAME" "Process $p_pid is not running."
        #echo "Process $pid is not running."
        continue
      fi
      #echo "Killing childs of process $pid"
      lib_trace_log "$CALLING_FUN_NAME" "Killing childs of process $p_pid"
      lib_kill_process_using_one_pid `lib_get_proc_tree "$p_pid" "$CALLING_FUN_NAME"`

      #echo "Now killing parent pid $pid"
      lib_trace_log "$CALLING_FUN_NAME" "Now killing parent pid $p_pid."
      # Killing Parent (Till now all childs has been killed) 
      lib_kill_process "$p_pid"
    done
  fi
}

#Note: since this function will return pid list by pattern hence there is no echo in this method. 
#This method will store the differnt arguments for shell and store them in the array
lib_get_ps_id_by_pattern()
{
  search_count=0
  CALLING_FUN_NAME=$1

  shift
  CALLER_NAME=$1

  SEARCH_PATTERN_ARR=$@
  #while [ "XX$CALLER_NAME" != "XX" ];do
   #SEARCH_PATTERN_ARR[$search_count]=$CALLER_NAME
   #echo "array list ${SEARCH_PATTERN_ARR[$search_count]}"
   #search_count=`expr $search_count + 1`
   #shift
   #CALLER_NAME=$1
  #done
  #lib_set_command_for_search
  
  LOC_MULTIPLE_SEARCH_CMD=""
  lib_set_ps_cmd
  #debug_log "Calling method set_command_for_search()"

  LOC_MULTIPLE_SEARCH_CMD=""

  set -- $SEARCH_PATTERN_ARR

  for list in $@  
  do
   LOC_MULTIPLE_SEARCH_CMD=`echo "$LOC_MULTIPLE_SEARCH_CMD |$LIB_PS_GREP_CMD  $list "`
   #echo "*****$LOC_MULTIPLE_SEARCH_CMD*****"
   lib_trace_log "**[LOC_MULTIPLE_SEARCH_COMMAND] = $LOC_MULTIPLE_SEARCH_CMD]**"
   #i=`expr $i + 1`
  done

  #if nsu_server_admin is running on same server, then it is also killed, hence skipping it
  LOC_MULTIPLE_SEARCH_CMD="$LOC_MULTIPLE_SEARCH_CMD | $LIB_PS_GREP_CMD -v nsu_server_admin"
  LIB_PS_CMD_FOR_SEARCH="eval $LIB_PS_CMD_FOR_SEARCH $LOC_MULTIPLE_SEARCH_CMD"
  lib_trace_log "**[LIB_PS_CMD_FOR_SEARCH= $LIB_PS_CMD_FOR_SEARCH]**"

  #PID will be generated here
  echo `$LIB_PS_CMD_FOR_SEARCH | grep -v cmon_client_utils.jar | $LIB_AWK -F' ' '{printf $2" "}'`
}

lib_set_command_for_search()
{
  i=0
  LOC_MULTIPLE_SEARCH_CMD=""
  lib_set_ps_cmd
  debug_log "Calling method set_command_for_search()"

  LOC_MULTIPLE_SEARCH_CMD=""

  while [ $i -lt $search_count ]
  do
   LOC_MULTIPLE_SEARCH_CMD=`echo "$LOC_MULTIPLE_SEARCH_CMD |$LIB_PS_GREP_CMD  ${SEARCH_PATTERN_ARR[$i]} "`
   #echo "*****$LOC_MULTIPLE_SEARCH_CMD*****"
   lib_trace_log "**[LOC_MULTIPLE_SEARCH_COMMAND] = $LOC_MULTIPLE_SEARCH_CMD]**"
   i=`expr $i + 1`
  done

  #if nsu_server_admin is running on same server, then it is also killed, hence skipping it
  LOC_MULTIPLE_SEARCH_CMD="$LOC_MULTIPLE_SEARCH_CMD | $LIB_PS_GREP_CMD -v nsu_server_admin"
  LIB_PS_CMD_FOR_SEARCH="eval $LIB_PS_CMD_FOR_SEARCH $LOC_MULTIPLE_SEARCH_CMD"
  lib_trace_log "**[LIB_PS_CMD_FOR_SEARCH= $LIB_PS_CMD_FOR_SEARCH]**"
}

lib_trace_log()
{
  CALLING_FUN_NAME=$1
  MSG=$2

  if [ "X$MON_TEST_RUN" = "X" ];then
    MON_TEST_RUN="NA"
  fi

  if [ "X$CALLING_FUN_NAME" = "X" ];then
    CALLING_FUN_NAME="NA"
  fi

  DATE_TIME_FORMAT="`date +'%m/%d/%y %R'`|$MON_TEST_RUN|$CALLING_FUN_NAME"
  if [ $DEBUG -eq 1 ];then
    echo "$DATE_TIME_FORMAT|$MSG" >>$DEBUG_LOG_FILE
  fi
}

lib_set_ps_cmd()
{
  OS_NAME=`uname`
  if [ "X$OS_NAME" = "XSunOS" ]; then
    LIB_PS_CMD_FOR_DATA="/usr/bin/ps"
    if [ ! -f /usr/ucb/ps ];then
      echo "Error: ps command not found on path /usr/ucb/ps. Hence standard ps command will be used."
      LIB_PS_CMD_FOR_SEARCH="ps -ef" # Do not use ps -lef as need pid at filed 2
    else
      LIB_PS_CMD_FOR_SEARCH="/usr/ucb/ps -auxwww"
    fi
    if [ ! -f /usr/xpg4/bin/grep ];then
      echo "Error: grep command not found on path /usr/xpg4/bin/grep. Hence extended regular expression may not be supported."
      LIB_PS_GREP_CMD="/usr/bin/egrep -e"  #Search for a pattern_list(full regular expression that 
                                       #begins with a -).
   else
     LIB_PS_GREP_CMD="/usr/xpg4/bin/grep -E"
   fi
   LIB_AWK="nawk" #In SUN OS awk not support -v option
  else #Linux,AIX
    LIB_PS_CMD_FOR_DATA="ps"
    LIB_PS_CMD_FOR_SEARCH="ps -ef" # Do not use ps -lef as need pid at filed 2
    #PS_GREP_CMD="grep -e"
    LIB_PS_GREP_CMD="grep -E"      # Fixed bug: 4574
   LIB_AWK="awk"
  fi
}

#Flag to check if bc available or not
BC_AVAILABLE=1
check_bc_available()
{
  type -P bc 1>/dev/null 2>&1
  if [ $? -ne 0 ]; then
    BC_AVAILABLE=0
  fi
}

lib_kill_process_using_pid_list()
{
  CALLING_FUN_NAME=$1
  PIDS=$2

  if [ "XX$PIDS" == "XX" ];then
    lib_trace_log "$CALLING_FUN_NAME" "lib_kill_process_using_pid_list(): Provided pid list is empty, Hence returning..."
    return
  fi

  pid_idx=0
  for pid in `echo $PIDS`
  do
    pid_list[$pid_idx]=$pid
    pid_idx=`expr $pid_idx + 1`
  done

  lib_trace_log "$CALLING_FUN_NAME" "lib_kill_process_using_pid_list Method called, pid_list = [${pid_list[@]}]"

  lib_set_ps_cmd

  for KILL_PID in ${pid_list[@]}
  do
    is_good_pid $KILL_PID
    if [ "X$GOOD_PID" = "X0" ]; then
      lib_normal_kill_process "$KILL_PID"
    fi
  done

  lib_trace_log "$CALLING_FUN_NAME" "Sleeping for 2 sec....."
  sleep 2
  for KILL_PID in ${pid_list[@]}
  do
    is_good_pid $KILL_PID
    if [ "X$GOOD_PID" = "X0" ]; then
      lib_post_kill_process "$KILL_PID"
    fi
  done
}

lib_kill_process_using_one_pid()
{
  CALLING_FUN_NAME=$1
  pid_list=$2

  if [ "XX$pid_list" = "XX" ];then
    lib_trace_log "$CALLING_FUN_NAME" "lib_kill_process_using_pid_list(): Provided pid list is empty, Hence returning..."
    return
  fi

#  pid_idx=0

#  for pid in `echo $PIDS`
#  do
#    pid_list[$pid_idx]=$pid
#    pid_idx=`expr $pid_idx + 1`
#  done

  lib_trace_log "$CALLING_FUN_NAME" "lib_kill_process_using_pid_list Method called, pid_list = [${pid_list}]"

  lib_set_ps_cmd

  set -- $pid_list
  for KILL_PID in $@
  do
    is_good_pid $KILL_PID
    if [ "X$GOOD_PID" = "X0" ]; then
      lib_normal_kill_process "$KILL_PID"
    fi
  done

  lib_trace_log "$CALLING_FUN_NAME" "Sleeping for 2 sec....."
  lib_sleep 2
  for KILL_PID in $@
  do
    is_good_pid $KILL_PID
    if [ "X$GOOD_PID" = "X0" ]; then
      lib_post_kill_process "$KILL_PID"
    fi
  done
}

#This method is taking all PID's as argument and iterating each PID to extract it's children PID's
#To get all children PID's , lib_get_childs_pid function is called

lib_get_all_leaf_child(){
  data=$1
  set -- $data
  all_child="$all_child $@"

  debug_log "Calling method lib_get_all_leaf_child() with PID = [$data]"
  #echo "Data -- > $@"
  for item in $@; do
    lib_get_childs_pid $item
    #num_child
    num_childs=`echo $ps_tree | $LIB_AWK -F' ' '{print NF}'`
    #echo "Child --> $num_childs"
    #echo "Children --> $ps_tree"
    if [ $num_childs -ne 0 ]; then
      lib_get_all_leaf_child "$ps_tree"
    fi
  done
}

lib_get_proc_tree()
{
  proc_id=$1
  CALLING_FUN_NAME=$2
  psT_idx=0
  final_pid_list=""
  ignored_pid_list=""

  lib_trace_log "$CALLING_FUN_NAME" "Method lib_get_proc_tree() called., CALLING_FUN_NAME=[$CALLING_FUN_NAME], proc_id=[$proc_id], excp_list = [$3]"

  lib_set_ps_cmd

  if [ "X$proc_id" = "X" ];then
    lib_trace_log "$CALLING_FUN_NAME" "proc_id should not be empty."
    echo ""
    exit 1
  fi

  #check proc id must be integer
  echo $proc_id | grep '^[0-9]*$' 2>&1 >/dev/null
  if [ $? != 0 ];then
    lib_trace_log "$CALLING_FUN_NAME" "proc_id $proc_id must be a numeric number"
    echo ""
    exit 1
  fi

  kill_excp_pid_list=`echo $3 | $LIB_AWK -F',' '{ for ( i = 1; i <= NF; i++) printf $i" "}'`

  lib_get_childs_pid $proc_id

  lib_trace_log "$CALLING_FUN_NAME" "Before ignoring exception pids child of pid $proc_id is - $ps_tree"

  ps_idx=0

  # Remove all childs of root pid which are in exception list Hence re-arrange ps_tree for index 0 
  if [ "X$kill_excp_pid_list" != "X" ];then
    lib_trace_log "$CALLING_FUN_NAME" "Checking pids of exception list to ignore for killing"
    for root_child_pid in `echo $ps_tree`; do
      found=0
      for excp_pid in `echo $kill_excp_pid_list`; do
        if [ $root_child_pid == $excp_pid ]; then
          lib_trace_log "$CALLING_FUN_NAME" "Pid $excp_pid is in exception list hence ignoring this pid."
          found=1
          #final_pid_list=$final_pid_list" "$root_child_pid
        #else
        #  ignored_pid_list=$ignored_pid_list" "$root_child_pid
        fi
      done
      if [ $found -eq 0 ];then
        lib_trace_log "$CALLING_FUN_NAME" "Add pid $root_child_pid in final pid list"
        final_pid_list=$final_pid_list" "$root_child_pid
      else
        lib_trace_log "$CALLING_FUN_NAME" "Add pid $root_child_pid in ignore pid list"
        ignored_pid_list=$ignored_pid_list" "$root_child_pid
      fi
    done
    lib_trace_log "$CALLING_FUN_NAME" "final_pid_list = $final_pid_list, ignored_pid_list = $ignored_pid_list"
    ps_tree="$final_pid_list"
  fi

  lib_trace_log "$CALLING_FUN_NAME" "After ignoring exception pids child of pid $proc_id is - ${ps_tree}"

  #echo "PS TREE -----> $ps_tree"

  lib_get_all_leaf_child "$ps_tree"
  #echo "All child ----> $all_child"

  #Making child list
  #Remove multiple spaces from ps_tree
  child_pid_list=`echo $all_child | sed 's/[ ]/ /g'`
  num_childs=`echo $child_pid_list | $LIB_AWK -F' ' '{print NF}'`

  ############ Code for logging only ##########
  lib_trace_log "$CALLING_FUN_NAME" "***------------------------------ Process Tree Of Pid $proc_id ---------------------------------------***"
  lib_trace_log "$CALLING_FUN_NAME" "All childs of pid($proc_id) child_pid_list = [$child_pid_list]"
  lib_trace_log "$CALLING_FUN_NAME" " "
  #Since in Sun OS --forest is not applicable show we return from here 
  OS_NAME=`uname`
  lib_trace_log "$CALLING_FUN_NAME" "OS_NAME = [$OS_NAME]"
  if [ $DEBUG -eq 1 ];then 
    #Since in Sun OS --forest is not applicable show we return from here 
    if [ "X$OS_NAME" = "XSunOS" ]; then
      #space with -p option gives error 
      if [ "X$child_pid_list" = "X" ]; then
        $LIB_PS_CMD_FOR_DATA -p "$proc_id" -o 'pid ppid stime args' >>$DEBUG_LOG_FILE
      else
        $LIB_PS_CMD_FOR_DATA -p "$proc_id $child_pid_list" -o 'pid ppid stime args' >>$DEBUG_LOG_FILE
      fi
    else
      #space with -p option gives error 
      if [ "X$child_pid_list" = "X" ]; then
        $LIB_PS_CMD_FOR_DATA -p "$proc_id" -o 'pid ppid stime args' --forest >>$DEBUG_LOG_FILE
      else
        $LIB_PS_CMD_FOR_DATA -p "$proc_id $child_pid_list" -o 'pid ppid stime args' --forest >>$DEBUG_LOG_FILE
      fi
    fi
  fi
  lib_trace_log "$CALLING_FUN_NAME" "***------------------------------ xxxxxxxxxxxxxxxxxxxxxxxxxxxx ---------------------------------------***"
  ############ Code for logging complete ##########

  # If there is any ignored pid then check its is running or not if not then clean their respective file
  if [ "XX$ignored_pid_list" != "XX" ];then
    for ing_pid in `echo $ignored_pid_list`
    do
      $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null
      if [ $? != 0 ]; then
        lib_trace_log "$CALLING_FUN_NAME" "PID = $ing_pid is not running hence removing their repective pid file from dir log dir"
        rm -f $CAV_MON_HOME/logs/$EXCP_PID_DIR/$ing_pid
      fi
    done
  fi

  # Since we need kill process from leaf node so return child pids in reverse order
  #Manish: Note - this echo produce output so don't redirect it into any file
  echo $child_pid_list |  $LIB_AWK '{ for ( i = NF; i > 0; i--) printf $i" "}'
}

lib_kill_process()
{
  pid=$1
  if [ "X$pid" == "X" ];then
    return
  fi

  name=`$LIB_PS_CMD_FOR_DATA -p $pid -o 'ppid stime args' 2>&1 | tail -1 2>&1`

  $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null 2>&1
  if [ $? != 0 ]; then
    lib_trace_log "$CALLING_FUN_NAME" "Monitor process/child whose PID = $pid is already stopped"
    return
  fi

  kill $pid  2>/dev/null

  sleep 2
  lib_trace_log "$CALLING_FUN_NAME" "Killed monitor whose PID = $pid and parent pid, start time and args = $name"
  $LIB_PS_CMD_FOR_DATA -p $pid >/dev/null
  if [ $? = 0 ]; then
    lib_trace_log "$CALLING_FUN_NAME" "Monitor with PID = $pid and parent pid, start time and args = $name still Running. Attempting to Kill using -9 .... "
    kill -9 $pid 2>&1
    if [ $? = 0 ]; then
      lib_trace_log "$CALLING_FUN_NAME" "Killed monitor whose PID = $pid and parent pid, start time and args = $name killed successfully."
    fi
  else
    lib_trace_log "$CALLING_FUN_NAME" "PID = $pid killed successfully in normal kill."
  fi
}

lib_get_childs_pid()
{
  ppid=$1

  ps_tree=`$LIB_PS_CMD_FOR_DATA -ef | $LIB_PS_GREP_CMD -v kill_monitor | $LIB_PS_GREP_CMD -v grep | awk '$3 == '$ppid' {printf $2" "}'`
  #echo "$LIB_PS_CMD_FOR_DATA -ef | $LIB_PS_GREP_CMD -v kill_monitor | $LIB_PS_GREP_CMD -v grep | awk '$3 == '$ppid' {printf $2" "}"

}

lib_run_command_with_wait()
{
  LOC_RUN_CMD=$1
  LOC_CMD_OUT_FILE=$2
  LOC_WAIT_TIME=$3
  LOC_CHECK_TIME=$4

  debug_log "Running command $LOC_RUN_CMD. Output file = $LOC_CMD_OUT_FILE, Wait Time = $LOC_WAIT_TIME, Check Time = $LOC_CHECK_TIME"
  
  eval nohup $LOC_RUN_CMD 1>$LOC_CMD_OUT_FILE 2>&1 &
 
  #Save exit status
  EXIT_STATUS=$?
      
  #Get pid of the command
  CMD_PID=$!
            
  #Note - nohup exit status is baed on whether is was able to run the command or not. Command exit status is not returned
  if [ $EXIT_STATUS != 0 ]; then
    error_log_and_console "Error in running command $LOC_RUN_CMD. Exit status = $EXIT_STATUS"
    cat $LOC_CMD_OUT_FILE
    rm -f $LOC_CMD_OUT_FILE
    exit $EXIT_STATUS
  fi
                                                              
  LOC_TOTAL_TIME=0
  debug_log "Command started OK. Going to wait for the command to complete with wait time of $LOC_WAIT_TIME seconds"

  while [ $LOC_TOTAL_TIME -lt $LOC_WAIT_TIME ];
  do
    ps -p $CMD_PID >/dev/null 2>&1
    if [ $? != 0 ]; then
    # Wait is used to get the exit status of the command as nohup does not give this
      wait $CMD_PID
      EXIT_STATUS=$?
      if [ $EXIT_STATUS != 0 ]; then
        error_log_and_console "Error in running command $LOC_RUN_CMD. Exit status = $EXIT_STATUS"
        cat $LOC_CMD_OUT_FILE
        rm -f $LOC_CMD_OUT_FILE
        exit $EXIT_STATUS
      fi
      debug_log "Command is over with success status"
      break
     fi
     LOC_TOTAL_TIME=`expr $LOC_TOTAL_TIME + 1`
     debug_log "Command is still running with PID $CMD_PID. Sleeping for $LOC_CHECK_TIME seconds. Total wait time so far is $LOC_TOTAL_TIME"
     sleep $LOC_CHECK_TIME
   done

   if [ $LOC_TOTAL_TIME -ge $LOC_WAIT_TIME ]; then
        #Killing hanging command
      kill -9 $CMD_PID
      error_log_and_console_exit "Error in getting output of command in maximum wait time of $LOC_WAIT_TIME seconds"
   fi
   debug_log "Total time taken by command to execute = $LOC_TOTAL_TIME seconds."
} 

#If someone stop cmon forcefully then read fails and monitors stuck in read like infinite loop
#due to this CPU becomes busy 
#To avoid this we need to add timer on read
lib_sleep()
{
  sleep_time_in_secs=$1

  # In Sun OS date command is not run as used here so (for Market Live) currently we are using sleep insted of read
  # TODO: Find solution for sun os
  OS_NAME=`uname`
  if [ "XX$OS_NAME" = "XXSunOS" ];then
    sleep $sleep_time_in_secs
  else
    # %s     seconds since 1970-01-01 00:00:00 UTC
    before_read_time=`date +'%s'`
    read -t $sleep_time_in_secs >/dev/null 2>&1
    after_read_time=`date +'%s'`
    elap_time=`expr $after_read_time - $before_read_time`
    if [ $elap_time -lt $sleep_time_in_secs ];then
      left_freq=`expr $sleep_time_in_secs - $elap_time`
      sleep $left_freq
    fi
  fi
}


debug_log()
{
  if [ $DEBUG -eq 1 ];then
    echo "`date +'%F %X'`|$*" >>$DEBUG_LOG_FILE
  fi
}

error_log()
{
  ns_log_event "Major" "$*"
  echo "`date +'%F %X'`|$*" >>$ERROR_LOG_FILE
}

set_ps_cmd()
{
  debug_log "set_ps_cmd() Called"
  if [ "X$OS_NAME" = "XSunOS" ]; then
    PS_CMD_FOR_DATA="/usr/bin/ps"
  else #Linux,AIX,HP-UX
    PS_CMD_FOR_DATA="ps"
  fi
}


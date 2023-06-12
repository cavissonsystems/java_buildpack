#!/bin/bash

###########################################################################################################################
# Name    : ndagentlauncher.sh
# Author  : Prerana Singh
# Purpose : Script to monitor all the running containers and attach the dynamic agent to each container having java process
###########################################################################################################################

ndhome=$1
source_path=$2
tar_modified=$3
host=$4
port=$5
sleep_time=$6
declare -A array_current
declare -A array_previous
declare -A current_java_pids
declare -A previous_java_pids
count=0

#Delete a file if size of a file is greater than 5 MB
filename="/tmp/nd_scriptlogs.txt"
if [ -e filename ];then
 if [ $(($(stat -c %s $filename)/1024/1024)) -gt 5 ]  ; then
  rm $filename ;
 fi
else
 echo "Dynamic agent attach script logs" > /tmp/nd_scriptlogs.txt
fi
exec &> /tmp/nd_scriptlogs.txt

find_java_process()
{
   java_process=$(docker exec $1 ps -ef |grep java )
   status=$?
   if [ "$status" != "0" ]; then
    echo "[Error] exec command to find java process failed! with status: $status"
   fi
   #return $java_process

}

docker_exec_mkdir_comm()
{
   docker exec $1 sh -c "mkdir -p 777 $ndhome ; echo mkdir command executed with status $?; exit $?"
   status=$?
   if [ "$status" != "0" ]; then
    echo "[Error] Docker exec command failed! with status: $status"   
   fi
}

docker_exec_untar_comm()
{
   docker exec $1 sh -c "tar -xvzf $ndhome/${source_path##*/} -C $ndhome ;"
   status=$?
   if [ "$status" != "0" ]; then
    echo "[Error] Docker exec tar command failed! with status: $status"
   fi
   return $status
}
docker_exec_launcher_comm()
{
   docker exec $1 sh -c "java -jar $ndhome/lib/ndagentlauncher.jar $ndhome/lib/ndmain.jar ndHome=$ndhome,ndcHost=$host,ndcPort=$port, ; echo java -jar  command executed with status $?; exit $?"

   status=$?
   if [ "$status" != "0" ]; then
    echo "[Error] exec command to launch ndagentlauncher failed! with status: $status"
   fi

}

copy_tar()
{

   docker cp $1 $2
   status=$?
   if [ "$status" != "0" ]; then
    echo "[Error] Docker cp command failed! with status: $status"
   fi
}

check_ndhome()
{
   docker exec $1 sh -c "test -d $ndhome;"
   status=$?
   if [ "$status" != "0" ]; then
    echo "[Error] exec command to test ndhome directory failed! with status: $status"
   fi
   return $status

}

attach_agent()
{
  echo entered attach_agent function
  array_element=$1
  find_java_process $array_element
 # Check if running container has java process or not
 if [ ! -n "$java_process" ]
  then
   echo "no java process in $array_element"
 else
   echo "java processes:"
   echo $java_process
   if [ -n "$source_path" ];then
    if [[ "$source_path" == *".tar.gz" ]]; then
     echo "tar filename is " ${source_path##*/}
    fi
     # Check if ndhome is available , if yes then no need to make directory , else create directory 
     check_ndhome $array_element
     #if [[ $? -ne 0 ]] || [[ $tar_modified -eq 1]]; then
     if [ "$?" -ne 0 ]; then
      docker_exec_mkdir_comm $array_element
     fi
    
     #Check if tar is modified or not
     if  [ "$tar_modified" -eq 1 ]; then
      copy_tar $source_path $array_element:$ndhome
      docker_exec_untar_comm $array_element
     fi

   else
     echo source path not provided
    exit 1
  fi
    docker_exec_launcher_comm $array_element
  printf "\n"
 fi
}

while true
do
 # ndhome should be passed as an argument
 if [ ! -n "$ndhome" ]
  then
   echo ndhome is null
   exit 1; 
 else
if [ -n "$(docker ps -q)" ]; then 
 if [ $count -eq 0 ];then
  # List all the running continers and store in array
  container_list_current=$(docker ps -q)
  container_list_previous=$(docker ps -q)
  current_containers_list=(${container_list_current}) # Current array
  previous_containers_list=(${container_list_previous})     # Previous array

  # Find the length of the running containers list
  len=${#current_containers_list[@]}
   echo   ${#current_containers_list[@]}
  for (( counter=0; counter<$len; counter++ ))
   do
    array_current[${current_containers_list[$counter]}]=$(docker inspect --format='{{.State.StartedAt}}' ${current_containers_list[$counter]} | xargs date +%s -d)
     echo Container ID: ${current_containers_list[$counter]} timestamp: ${array_current[${current_containers_list[$counter]}]}
    cmd=$(docker exec ${current_containers_list[$counter]}  ps -ef |grep java)
    echo cmd is : $cmd
    if [[ "$cmd" == *"ndHome="* ]]; then
     echo "agent is already attached so no need to attach dynamically " 
    else
     attach_agent ${current_containers_list[$counter]}
    fi
   done

  for i in "${!array_current[@]}"; do
   array_previous[$i]+=${array_current[$i]}
  done

 else
  if [ ! -n "$sleep_time"]; then
   echo after "$sleep_time" seconds
  else
   echo after 10 seconds
  fi

  # Calculate the timestamp of current container list and store in timestamp_array_initial
  container_list_current=$(docker ps -q)
  current_containers_list=(${container_list_current})

  # To keep a track of all the restarted containers
  restarted_container=()

  # To keep a track of all the newly added containers
  added_container=()

  # Calculate the length of current and previous containers list
  array_current_len=${#array_current[@]}
  array_previous_len=${#array_previous[@]}

  len=${#current_containers_list[@]}
  for (( counter=0; counter<$len; counter++ ))
   do
    array_current[${current_containers_list[$counter]}]=$(docker inspect --format='{{.State.StartedAt}}' ${current_containers_list[$counter]} | xargs date +%s -d)
   done

   # Check if any new container is added in the current list
    for i in "${!array_current[@]}"
      do
      flag=0
       for j in "${!array_previous[@]}"
        do
          if [ "$i" == "$j" ];then
          flag=1
          break
         fi
        done
      if [ "$flag" -eq "0" ]; then
        cmd=$(docker exec $i  ps -ef |grep java)
         if [[ "$cmd" == *"ndHome="* ]]; then
          echo cmd is : $cmd
          echo added container : $i
          echo "But agent is already attached so no need to attach dynamically " 
         else
          echo added container : $i
          added_container+=( "$i" )
         fi
      fi
    done

 # Check if any running container is restarted , if yes then add it to restarted_container array
     if [ $array_current_len -eq $array_previous_len ];then
      for i in "${!array_current[@]}"
       do
        if [ ${array_current[$i]} -gt ${array_previous[$i]} ];then
         cmd=$(docker exec $i  ps -ef |grep java)
         if [[ "$cmd" == *"ndHome="* ]]; then
          echo cmd is : $cmd
          echo restarted container : $i
          echo "But agent is already attached so no need to attach dynamically " 
         else
          echo restarted container : $i
         restarted_container+=("$i")
         fi
        fi
       done
     fi

 # Copy the current list of running containers to previous list so as to have a track in the next run
 array_previous=()
 for i in "${!array_current[@]}"; 
  do
   array_previous[$i]+=${array_current[$i]}
  done

 # Calculate the added and restarted containers
 added_container_len=${#added_container[@]}
 restart_array_len=${#restarted_container[@]}

 # Run script for newly added containers
 if [ -n "$added_container" ];then
  for (( counter=0; counter<$added_container_len; counter++ ))
   do
    attach_agent ${added_container[$counter]}
   done
 fi

 #run script for restarted containers
 if [  -n "$restarted_container" ];then
  for (( counter=0; counter<$restart_array_len; counter++ ))
   do
    attach_agent ${restarted_container[$counter]}
   done
 fi

fi
    else  #if docker process is not running
    if [ $count -eq 0 ];then #script is running for the first time
     # List all the running continers and store in array
     current_java_process_ids=$(pgrep -f java)
     previous_java_process_ids=$(pgrep -f java)
     current_java_pids_array=(${current_java_process_ids// / }) # Current array
     previous_java_pids_array=(${previous_java_process_ids// / })     # Previous array

     # Find the length of the running java processes
     len=${#current_java_pids_array[@]}
      for (( counter=0; counter<$len; counter++ ))
       do
       elapse_time=$(ps -o etimes -p ${current_java_pids_array[$counter]})
       timestamp_array=($elapse_time)
       current_java_pids[${current_java_pids_array[$counter]}]=${timestamp_array[1]}
       echo java process ID: ${current_java_pids_array[$counter]} timestamp: ${timestamp_array[1]}
       cmd=$(ps -o cmd -p ${current_java_pids_array[$counter]})
      if [[ "$cmd" == *"ndHome="* ]]; then
       echo "agent is already attached to the running java process so no need to attach dynamically " 
      else
       java -jar $ndhome/lib/ndagentlauncher.jar  $ndhome/lib/ndmain.jar ndHome=$ndhome,ndcHost=$host,ndcPort=$port,
      fi
     done
     #Copy current java process id to previous java process id array to keep a track
     for i in "${!current_java_pids[@]}"; do
     previous_java_pids[$i]+=${current_java_pids[$i]}
     done
     
     else
     if [ ! -n "$sleep_time"]; then
      echo after "$sleep_time" seconds
     else
      echo after 10 seconds
     fi

     # Calculate the elapse time of current java processes and store in current_java_pids_array
     current_java_process_ids=$(pgrep -f java)
     current_java_pids_array=(${current_java_process_ids// / }) # Current array

     # To keep a track of all the newly added java process
     added_java_process=()
   
     # To keep a track of all the restarted java process
     restarted_java_pid=()

     
     len=${#current_java_pids_array[@]}
     for (( counter=0; counter<$len; counter++ ))
      do
       elapse_time=$(ps -o etimes -p ${current_java_pids_array[$counter]})
       timestamp_array=($elapse_time)
       current_java_pids[${current_java_pids_array[$counter]}]=${timestamp_array[1]}
      done

     # Calculate the length of current and previous containers list
     current_java_process_len=${#current_java_pids[@]}
     previous_java_process_len=${#previous_java_pids[@]}
     
     # Check if any new java process is added in the current list
     for i in "${!current_java_pids[@]}"
      do
      flag=0
       for j in "${!previous_java_pids[@]}"
        do
          if [ "$i" == "$j" ];then
          flag=1
          break
         fi
        done
      if [ "$flag" -eq "0" ]; then
       cmd=$(ps -o cmd -p $i)
        if [[ "$cmd" == *"ndHome="* ]]; then
         echo added java process : $i
         echo "But agent is already attached to the running java process so no need to attach dynamically " 
        else
         echo added java process : $i
         added_java_process+=( "$i" )
        fi
      fi
     done
  
     # Check if any running container is restarted , if yes then add it to restarted_container array
     if [ $current_java_process_len -eq $previous_java_process_len ];then
      for i in "${!current_java_pids[@]}"
       do
        if [ ${current_java_pids[$i]} -lt ${previous_java_pids[$i]} ];then
          cmd=$(ps -o cmd -p $i)
           if [[ "$cmd" == *"ndHome="* ]]; then
             echo restarted java process id : $i
             echo "But agent is already attached to the running java process so no need to attach dynamically " 
           else
              echo restarted java process id : $i
              restarted_java_pid+=("$i")
           fi
        fi
       done
     fi

     # Copy the current list of running containers to previous list so as to have a track in the next run
     previous_java_pids=()
     for i in "${!current_java_pids[@]}";
     do
      previous_java_pids[$i]+=${current_java_pids[$i]}
     done

     # Calculate the length of started java process
     added_java_process_len=${#added_java_process[@]}
     restart_java_process_len=${#restarted_java_pid[@]}

     # Run script for newly started java process
     if [ -n "$added_java_process" ];then
      echo added_java_process is not null
      for (( counter=0; counter<$added_java_process_len; counter++ ))
       do
         java -jar $ndhome/lib/ndagentlauncher.jar  $ndhome/lib/ndmain.jar ndHome=$ndhome,ndcHost=$host,ndcPort=$port,
       done
     fi

     #run script for restarted containers
     if [  -n "$restarted_container" ];then
      for (( counter=0; counter<$restart_java_process_len; counter++ ))
       do
         java -jar $ndhome/lib/ndagentlauncher.jar  $ndhome/lib/ndmain.jar ndHome=$ndhome,ndcHost=$host,ndcPort=$port,
       done
     fi


     fi
    fi
if [ -n "$sleep_time" ];then
 sleep $sleep_time
else
 sleep 10
fi
fi
count=1
done


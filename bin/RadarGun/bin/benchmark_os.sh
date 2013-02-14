#!/bin/bash

#source "/etc/openshift/node.conf"
#source ${CARTRIDGE_BASE_PATH}/abstract/info/lib/util
#CART_NS=$(get_cartridge_namespace_from_path)
#MASTER_PORT=$(eval echo $`echo "$(echo OPENSHIFT_${CART_NS}_MASTER_PORT)"`)

## Load includes
if [ "x$RADARGUN_HOME" = "x" ]; then DIRNAME=`dirname $0`; RADARGUN_HOME=`cd $DIRNAME/..; pwd` ; fi; export RADARGUN_HOME
. ${RADARGUN_HOME}/bin/includes.sh

#### parse plugins we want to test
VERBOSE=false

MASTER_PORT=2103
MASTER=$OPENSHIFT_INTERNAL_IP:$MASTER_PORT
TAILF=false

help_and_exit() {
  wrappedecho "Usage: "
  wrappedecho '  $ benchmark.sh [-u ssh_user] [-w WORKING DIRECTORY] [-m MASTER_IP[:PORT]] SLAVE...'
  wrappedecho ""
  wrappedecho "e.g."
  wrappedecho "  $ benchmark.sh"
  wrappedecho ""
  wrappedecho "   -u       SSH user to use when SSH'ing across to the slaves.  Defaults to '$SSH_USER'."
  wrappedecho ""
  wrappedecho "   -w       Working directory on the slave.  Defaults to '$WORKING_DIR'."
  wrappedecho ""
  wrappedecho "   -m       Connection to MASTER server.  Specified as host or host:port.  Defaults to '$MASTER'."
  wrappedecho ""
  wrappedecho "   -r       Command for remote command execution.  Defaults to '$REMOTE_CMD'."
  wrappedecho ""
  wrappedecho "   -t       After starting the benchmark it will run 'tail -f' on the master node's log file."
  wrappedecho ""
  wrappedecho "   -h       Displays this help screen"
  wrappedecho ""
  exit 0
}

### read in any command-line params
while ! [ -z $1 ]
do
  case "$1" in
    "-m")
      MASTER=$2
      shift
      ;;
    "-t")
      TAILF=true
      ;;      
    "-h")
      help_and_exit
      ;;
  esac
  shift
done

####### first start the master
. ${RADARGUN_HOME}/bin/master.sh -m ${MASTER}
PID_OF_MASTER_PROCESS=$RADARGUN_MASTER_PID
#### Sleep for a few seconds so master can open its port
sleep 5s

####### Spawning the right number of gears

INIT_GEARS=$(grep "maxSize" ${RADARGUN_HOME}/conf/benchmark.xml | cut -f 2 -d '=' | tr -d ' ' | tr -d '"' | sed 's/[^0-9]//g' )
if [ -z "$INIT_GEARS" ]; then
  echo "Problems parsing conf/benchmark.xml file"
  echo "Killing master process..."
  . ./${RADARGUN_HOME}/bin/master.sh -stop
  exit
fi

# Loading gears endpoints from conf
## 8a477de4375e44eaac38530bc196ae77@146.193.41.31:8a477de437;8a477de437-fabietto.fperfetti.it

gears_db=~/haproxy-1.4/conf/gear-registry.db

GEARS=$(sed "s/\:.*//" "$gears_db" | \
	tr "\n" " ")

GEARS_COUNT=0
for token in $GEARS; do 
	GEARS_COUNT=$((GEARS_COUNT+1)); 
done; 

echo "Active gears: $GEARS_COUNT"
CMD="haproxy_ctld -d"
for (( i=1; i<="$GEARS_COUNT"; i++ ))
do
  echo "$i - Tearing down gear [$CMD]"
  `$CMD`
done

echo "Needed gears: $INIT_GEARS"
CMD="haproxy_ctld -u"
for (( i=1; i<="$INIT_GEARS"; i++ ))
do
  echo "$i - Building up gear [$CMD]"
  `$CMD`
done

if [ $TAILF == "true" ]
then
  tail -f radargun.log
fi


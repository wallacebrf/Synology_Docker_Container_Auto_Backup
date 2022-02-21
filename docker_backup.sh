#!/bin/bash

#create a lock file in the ramdisk directory to prevent more than one instance of this script from executing  at once
if ! mkdir /volume1/web/logging/notifications/plex_docker_backup.lock; then
	echo "Failed to aquire lock.\n" >&2
	exit 1
fi
trap 'rm -rf /volume1/web/logging/notifications/plex_docker_backup.lock' EXIT #remove the lockdir on exit

#notes on exporting grafana dashboards: https://gist.github.com/crisidev/bd52bdcc7f029be2f295
#getting grafana API key: https://grafana.com/docs/grafana/latest/http_api/auth/

#automate fortigate configuration backups: https://kb.fortinet.com/kb/documentLink.do?externalID=FD39818       https://docs.fortinet.com/document/fortigate/6.2.3/cli-reference/64620/system-auto-script


log_file_location="/volume1/web/logging/notifications/plex_docker_backup.txt"

#scrutiny variables
scrutiny_container_name="analogj-scrutiny"
scrutiny_docker_folder_name="scrutiny"
scrutiny_backup_dir="/volume1/Backups/Docker/scrutiny"

#plex_gaps variables
plex_gaps_container_name="plex-gaps"
plex_gaps_docker_folder_name="gaps"
plex_gaps_backup_dir="/volume1/Backups/Docker/plex_gaps"


#sickchill variables
sickchill_IP='192.168.1.13'
sickchill_port='8081'
sickchill_backup_target_dir="/downloads/backup"
sickchill_container_name="sickchill"
sickchill_docker_folder_name="sickchill"
sickchill_backup_dir="/volume1/Backups/Docker/sickchill"

docker_directory="/volume1/docker"

#lidarr container variables
lidarr_container_name="linuxserver-lidarr"
lidarr_docker_folder_name="lidar"
lidarr_backup_dir="/volume1/Backups/Docker/lidar"

#grafana container variables
HOST="http://192.168.1.13:3001"
KEY="eyJrIjoibzFOMHE3UFJHRXd3NHM4U2tmd2R2Wk4xaFltaFZ6U1MiLCJuIjoiYmFja3VwIiwiaWQiOjF9"
grafana_container_name="grafana"
grafana_docker_folder_name="grafana"
grafana_backup_dir="/volume1/Backups/Docker/grafana"

#influxdb_1.8.3 container variables 
#influxdb_container_name="influxdb_1.8.3"
#influxdb_docker_folder_name="Influxdb"
#influxdb_backup_dir="/volume1/Backups/Docker/Influxdb"

#influxdb_2.x container variables 
influxdb_container_name="influxdb_2.0"
influxdb_docker_folder_name="Influxdb2"
influxdb_backup_dir="/volume1/Backups/Docker/Influxdb2"

#radarr container variables
radarr_container_name="linuxserver-radarr"
radarr_docker_folder_name="Radarr"
radarr_backup_dir="/volume1/Backups/Docker/radarr"

#portainer container variables
portainer_container_name="portainer_ce"
portainer_docker_folder_name="portainer"
portainer_backup_dir="/volume1/Backups/Docker/portainer"

#tautulli container variables
tautulli_container_name="tautulli"
tautulli_docker_folder_name="tautulli"
tautulli_backup_dir="/volume1/Backups/Docker/tautulli"

#synology config file backup variables
synology_config_backup_dir="/volume1/Backups/Server2_Config_Backup/config_files"

#Fortigateconfig file backup variables
fortigate_config_backup_dir="/volume1/Backups/Fortigate/config_files"

#setup log file
echo "Beginning backup of 
1.) Docker Container Working Directories, 
2.) Grafana Dashboards, 
3.) Synology System Configuration" |& tee $log_file_location


#####################################
#get current date
#####################################

DATE=$(date +%m-%d-%Y);

now=$(date +"%T")
echo "" |& tee -a $log_file_location
 
#####################################
#Backup Docker directories
#####################################
echo "" |& tee -a $log_file_location
now=$(date +"%T")
echo "$now - BACKING UP DOCKER CONTAINERS" |& tee -a $log_file_location
echo "" |& tee -a $log_file_location
cd $docker_directory

 #####################################
#Function to perform docker directory backups
#####################################
# Usage docker_container_backup container_name docker_dir backup_dir zip_file_name log_location DATE docker_folder_name
#container_name=$1
#docker_dir=$2
#backup_dir=$3
#zip_file_name=$4
#log_location=$5
#DATE=$6
#$docker_folder_name=$7
docker_container_backup(){
	now=$(date +"%T")
	echo "" |& tee -a $5
	echo "$now - Backing up Docker Container $1" |& tee -a $5
	if [ -f "$3/$4-$6.zip" ]; then
		echo "Backup file $3/$4-$6.zip already exists, skipping backup process of Docker Container $1" |& tee -a $5
	else
		if [ "$( docker container inspect -f '{{.State.Status}}' $1 )" == "running" ]; then
			echo "Stopping Docker Container $1" |& tee -a $5
			docker stop $1  |& tee -a $5
			sleep 1
		fi
		
		if [ "$( docker container inspect -f '{{.State.Status}}' $1 )" == "running" ]; then
			echo "Stopping Docker Container $1 Failed skipping backup process for Docker container $1" |& tee -a $5
		else
			echo "Docker Container $1 was successfully stopped" |& tee -a $5
			echo "Creating backup file $4-$6.zip" |& tee -a $5
			zip -r -q -0 $4-$6.zip $7  |& tee -a $5
			if [ -f "$2/$4-$6.zip" ]; then
				echo "$4-$6.zip created" |& tee -a $5
				echo "Moving $4-$6.zip to $3" |& tee -a $5
				mv $4-$6.zip $3/$4-$6.zip |& tee -a $5
				if [ -f "$3/$4-$6.zip" ]; then
					echo "Backup of $1 complete, starting container" |& tee -a $5
					docker start $1  |& tee -a $5
					if [ "$( docker container inspect -f '{{.State.Status}}' $1 )" == "running" ]; then
						echo "Docker Container $1 was successfully Started" |& tee -a $5
					else
						echo "Docker Container $1 could not be restarted" |& tee -a $5
					fi
					echo "" |& tee -a $5
					sleep 1
				else
					echo "Backup of $1 failed, backup file not in destination folder, starting container" |& tee -a $5
					docker start $1  |& tee -a $5
					echo "" |& tee -a $5
					sleep 1
				fi
			else
				echo "Backup of $1 failed, zip file not successfully created, starting container" |& tee -a $5
				docker start $1  |& tee -a $5
				echo "" |& tee -a $5
				sleep 1
			fi
		fi
	fi
}

#backing up plex_gaps container
#####################################
#current_dir=$(pwd)
#if [ "$current_dir" = "$docker_directory" ]; then
#	docker_container_backup $plex_gaps_container_name $docker_directory $plex_gaps_backup_dir plex-gaps $log_file_location $DATE $plex_gaps_docker_folder_name
#else
#	echo "Could not change directory to $docker_directory, canceling backup process of $scrutiny_container_name" |& tee -a $log_file_location
#fi


#backing up Lidarr container
#####################################
#current_dir=$(pwd)
#if [ "$current_dir" = "$docker_directory" ]; then
#	docker_container_backup $lidarr_container_name $docker_directory $lidarr_backup_dir lidarr $log_file_location $DATE $lidarr_docker_folder_name
#else
#	echo "Could not change directory to $docker_directory, canceling backup process of $lidarr_container_name" |& tee -a $log_file_location
#fi

#backing up grafana container
#####################################
cd $grafana_backup_dir
current_dir=$(pwd)
if [ "$current_dir" = "$grafana_backup_dir" ]; then
	now=$(date +"%T")
	echo "" |& tee -a $log_file_location
	echo "$now - Exporting Grafana dashboards" |& tee -a $log_file_location

	if [ ! -d $grafana_backup_dir/dashboards_$DATE ] ; then
		mkdir -p $grafana_backup_dir/dashboards_$DATE
		echo "Directory $grafana_backup_dir/dashboards_$DATE has been created"
	
		set -o errexit
		set -o pipefail

		[ -n "$KEY" ] || ( echo "No API key found. Get one from $HOST/org/apikeys and run 'KEY=<API key> $0'"; exit 1)

		set -o nounset
		dash_count=0
		echo "Exporting Grafana dashboards from $HOST" |& tee -a $log_file_location
		mkdir -p dashboards_$DATE  |& tee -a $log_file_location
		for dash in $(curl -sS -H "Authorization: Bearer $KEY" $HOST/api/search\?query\=\& | jq -r '.[] | select( .type | contains("dash-db")) | .uid'); do
			curl -s -H "Authorization: Bearer $KEY" "$HOST/api/dashboards/uid/$dash" | jq . -r > dashboards_$DATE/${dash}.json 
			slug=$(cat dashboards_$DATE/${dash}.json | jq -r '.meta.slug')
			mv dashboards_$DATE/${dash}.json dashboards_$DATE/${dash}-${slug}.json
			if [ -f "$grafana_backup_dir/dashboards_$DATE/${dash}-${slug}.json" ]; then
				echo "Dashboard ${dash}-${slug}.json Successfully Exported" |& tee -a $log_file_location
		
				#remove lines 2 through 24 as they are meta data that breaks the import process so we need to remove it		
				sed -i '2,24d' dashboards_$DATE/${dash}-${slug}.json
		
				#remove last line as it has the end bracket for th meta data which needs to be removed since the meta data was deleted above
				sed -i '$d' dashboards_$DATE/${dash}-${slug}.json
				
				let dash_count=dash_count+1
			else
				echo "Dashboard ${dash}-${slug}.json Export Failed" |& tee -a $log_file_location
			fi
		done
		
		if [ $dash_count -ne 0 ]; then
			echo "$dash_count dashboards have been exported" |& tee -a $log_file_location
		else
			echo "Either no dashboards were available to export or the export process failed" |& tee -a $log_file_location
		fi
		
		cd $docker_directory
		echo "" |& tee -a $log_file_location
		current_dir=$(pwd)
		if [ "$current_dir" = "$docker_directory" ]; then
			if [ ! -d $docker_directory/$grafana_docker_folder_name/_data ] ; then
				echo "grafana data directory already empty"
			else
				echo "removing grafana data from previous backup process"
				rm -r $docker_directory/$grafana_docker_folder_name/_data |& tee -a $log_file_location
			fi
			
			if [ "$( docker container inspect -f '{{.State.Status}}' $grafana_container_name )" == "running" ]; then
				echo "Stopping Docker Container $grafana_container_name" |& tee -a $log_file_location
				docker stop $grafana_container_name  |& tee -a $log_file_location
				sleep 1
			fi
			
			if [ "$( docker container inspect -f '{{.State.Status}}' $grafana_container_name )" == "running" ]; then
				echo "Stopping Docker Container $grafana_container_name Failed skipping backup process for Docker container $grafana_container_name" |& tee -a $log_file_location
			else
				echo "Docker Container $grafana_container_name was successfully stopped" |& tee -a $log_file_location
				echo "backing up grafana data directory from /volume1/@docker/volumes/grafana-storage/"
				cp -a /volume1/@docker/volumes/grafana-storage/. $docker_directory/$grafana_docker_folder_name/
				docker_container_backup $grafana_container_name $docker_directory $grafana_backup_dir grafana $log_file_location $DATE $grafana_docker_folder_name
			fi
		else
			echo "Could not change directory to $docker_directory, canceling backup process of $grafana_container_name" |& tee -a $log_file_location
		fi
	else
		echo "Directory $grafana_backup_dir/dashboards_$DATE Already Exists, Skipping Grafana Dashboard Export" |& tee -a $log_file_location
	fi
else
	echo "Could not change directory to $grafana_backup_dir, skipping Grafana Dashboard Export" |& tee -a $log_file_location
fi

cd $docker_directory
#backing up influxdb container
#####################################
current_dir=$(pwd)
if [ "$current_dir" = "$docker_directory" ]; then
	docker_container_backup $influxdb_container_name $docker_directory $influxdb_backup_dir influxdb $log_file_location $DATE $influxdb_docker_folder_name
else
	echo "Could not change directory to $docker_directory, canceling backup process of $influxdb_container_name" |& tee -a $log_file_location
fi
#backing up radarr container
#####################################
#current_dir=$(pwd)
#if [ "$current_dir" = "$docker_directory" ]; then
#docker_container_backup $radarr_container_name $docker_directory $radarr_backup_dir radarr $log_file_location $DATE $radarr_docker_folder_name
#else
#	echo "Could not change directory to $docker_directory, canceling backup process of $radarr_container_name" |& tee -a $log_file_location
#fi

#backing up sickchill container
#####################################
now=$(date +"%T")
echo "" |& tee -a $log_file_location
echo "$now - Creating backup file of sickchill container" |& tee -a $log_file_location
curl -k -u user:password https://$sickchill_IP:$sickchill_port/config/backuprestore/backup?backupDir=$sickchill_backup_target_dir  |& tee -a $log_file_location


cd $docker_directory/$sickchill_docker_folder_name$sickchill_backup_target_dir
current_dir=$(pwd)
if [ "$current_dir" = "$docker_directory/$sickchill_docker_folder_name$sickchill_backup_target_dir" ]; then
	echo "Cleaning up sickchill backup directory $docker_directory/$sickchill_docker_folder_name$sickchill_backup_target_dir" |& tee -a $log_file_location
	ls -1t | tail -n +4 | xargs rm -f
else
	echo "Could not change directory to $docker_directory/$sickchill_docker_folder_name$sickchill_backup_target_dir, canceling cleaning of sickchill backup directory $docker_directory/$sickchill_docker_folder_name$sickchill_backup_target_dir" |& tee -a $log_file_location
fi

sleep 1
cd $docker_directory
current_dir=$(pwd)
if [ "$current_dir" = "$docker_directory" ]; then
	docker_container_backup $sickchill_container_name $docker_directory $sickchill_backup_dir sickchill $log_file_location $DATE $sickchill_docker_folder_name
else
	echo "Could not change directory to $docker_directory, canceling backup process of $sickchill_container_name" |& tee -a $log_file_location
fi

#backing up portainer container
#####################################
current_dir=$(pwd)
if [ "$current_dir" = "$docker_directory" ]; then
	docker_container_backup $portainer_container_name $docker_directory $portainer_backup_dir portainer $log_file_location $DATE $portainer_docker_folder_name
else
	echo "Could not change directory to $docker_directory, canceling backup process of $portainer_container_name" |& tee -a $log_file_location
fi

#backing up tautulli container
#####################################
current_dir=$(pwd)
if [ "$current_dir" = "$docker_directory" ]; then
	docker_container_backup $tautulli_container_name $docker_directory $tautulli_backup_dir tautulli $log_file_location $DATE $tautulli_docker_folder_name
else
	echo "Could not change directory to $docker_directory, canceling backup process of $tautulli_container_name" |& tee -a $log_file_location
fi

#####################################
#backing up synology server2 configuration
#####################################
now=$(date +"%T")
echo "" |& tee -a $log_file_location
echo "$now - Backing up Server2 DSM Configuration" |& tee -a $log_file_location
if [ -f "$synology_config_backup_dir/server2_$DATE.dss" ]; then
	echo "Backup file $synology_config_backup_dir/server2_$DATE.dss already exists, skipping backup process" |& tee -a $log_file_location
else
	/usr/syno/bin/synoconfbkp export --filepath=$synology_config_backup_dir/server2_$DATE.dss
	if [ -f "$synology_config_backup_dir/server2_$DATE.dss" ]; then
		echo "Back up of Server2 DSM Configuration was successful" |& tee -a $log_file_location
	else
		echo "Back up of Server2 DSM Configuration failed, backup file not in destination folder" |& tee -a $log_file_location
	fi
fi

#####################################
#Cleanup activities
#####################################
#delete older un-needed backups. this will keep the last two backup files and delete all others 

cd $sickchill_backup_dir
current_dir=$(pwd)
if [ "$current_dir" = "$sickchill_backup_dir" ]; then
	echo "Cleaning up sickchill backup directory $sickchill_backup_dir" |& tee -a $log_file_location
	ls -1t | tail -n +4 | xargs rm -f
else
	echo "Could not change directory to $sickchill_backup_dir, canceling cleaning of sickchill backup directory $sickchill_backup_dir" |& tee -a $log_file_location
fi

#cd $lidarr_backup_dir
#current_dir=$(pwd)
#if [ "$current_dir" = "$lidarr_backup_dir" ]; then
#	echo "Cleaning up Lidarr backup directory $lidarr_backup_dir" |& tee -a $log_file_location
#	ls -1t | tail -n +4 | xargs rm -f
#else
#	echo "Could not change directory to $lidarr_backup_dir, canceling cleaning of Lidarr backup directory $lidarr_backup_dir" |& tee -a $log_file_location
#fi

cd $influxdb_backup_dir
current_dir=$(pwd)
if [ "$current_dir" = "$influxdb_backup_dir" ]; then
	echo "Cleaning up influxdb backup directory $influxdb_backup_dir" |& tee -a $log_file_location
	ls -1t | tail -n +4 | xargs rm -f
else
	echo "Could not change directory to $influxdb_backup_dir, canceling cleaning of influxdb backup directory $influxdb_backup_dir" |& tee -a $log_file_location
fi

#cd $radarr_backup_dir
#current_dir=$(pwd)
#if [ "$current_dir" = "$radarr_backup_dir" ]; then
#	echo "Cleaning up radarr backup directory $radarr_backup_dir" |& tee -a $log_file_location
#	ls -1t | tail -n +4 | xargs rm -f
#else
#	echo "Could not change directory to $radarr_backup_dir, canceling cleaning of radarr backup directory $radarr_backup_dir" |& tee -a $log_file_location
#fi

cd $portainer_backup_dir
current_dir=$(pwd)
if [ "$current_dir" = "$portainer_backup_dir" ]; then
	echo "Cleaning up portainer backup directory $portainer_backup_dir" |& tee -a $log_file_location
	ls -1t | tail -n +4 | xargs rm -f
else
	echo "Could not change directory to $portainer_backup_dir, canceling cleaning of portainer backup directory $portainer_backup_dir" |& tee -a $log_file_location
fi

cd $tautulli_backup_dir
current_dir=$(pwd)
if [ "$current_dir" = "$tautulli_backup_dir" ]; then
	echo "Cleaning up tautulli Config backup directory $tautulli_backup_dir" |& tee -a $log_file_location
	ls -1t | tail -n +4 | xargs rm -f
else
	echo "Could not change directory to $tautulli_backup_dir, canceling cleaning of tautulli Config backup directory $tautulli_backup_dir" |& tee -a $log_file_location
fi

#cd $plex_gaps_backup_dir
#current_dir=$(pwd)
#if [ "$current_dir" = "$plex_gaps_backup_dir" ]; then
#	echo "Cleaning up Plex-Gaps Config backup directory $plex_gaps_backup_dir" |& tee -a $log_file_location
#	ls -1t | tail -n +4 | xargs rm -f
#else
#	echo "Could not change directory to $plex_gaps_backup_dir, canceling cleaning of Plex-Gaps Config backup directory $plex_gaps_backup_dir" |& tee -a $log_file_location
#fi

cd $synology_config_backup_dir
current_dir=$(pwd)
if [ "$current_dir" = "$synology_config_backup_dir" ]; then
	echo "Cleaning up synology DSM Config backup directory $synology_config_backup_dir" |& tee -a $log_file_location
	ls -1t | tail -n +5 | xargs rm -f
else
	echo "Could not change directory to $synology_config_backup_dir, canceling cleaning of Synology Config backup directory $synology_config_backup_dir" |& tee -a $log_file_location
fi	

#cd $fortigate_config_backup_dir
#current_dir=$(pwd)
#if [ "$current_dir" = "$fortigate_config_backup_dir" ]; then
#	echo "Cleaning up Fortigate Config backup directory $fortigate_config_backup_dir" |& tee -a $log_file_location
#	ls -1t | tail -n +10 | xargs rm -f
#else
#	echo "Could not change directory to $fortigate_config_backup_dir, canceling cleaning of Fortigate Config backup directory $fortigate_config_backup_dir" |& tee -a $log_file_location
#fi

now=$(date +"%T")
echo "" |& tee -a $log_file_location
echo "" |& tee -a $log_file_location
echo "$now - Backup Process Complete" |& tee -a $log_file_location

exit


#cleanup command explanation
#ls : List directory contents.
#-1t : 1(Number one) indicates that the output of ls should be one file per line. t indicates sort contents by modification time, newest first.
#tail : Output the last part of files.
#-n +x : output the last x NUM lines, instead of the last 10; or use -n +NUM to output starting with line NUM
#xargs : Build and execute command lines from standard input.
#rm -f : Remove files or directories. f indicates ignore nonexistent files and arguments, never prompt. It means that this command won't display any error messages if there are less than 10 files.
#| - It is a pipeline. It is generally a sequence of one or more commands separated by one of the control operators | or |&.
#So, the above command will delete the oldest files if there are more than 10 files in the current working directory. To verify how many files are in the directory after deleting the oldest file(s), just run:

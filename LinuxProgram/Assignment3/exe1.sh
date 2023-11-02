#!/bin/bash
file=$1
if [ $# -gt 1 ]
then
	echo "ERROR: More Than One Paramen"
fi
if [ -e "$file" ]
then 
	if [ -d "$file" ]
	then
		if [ -e "$file.tar" ]
		then
			echo "$file.rar exists"
		else
			tar -cvf "$file.tar" "$file"/
		fi
	elif [ -f "$file" ]
	then
		if [[ $file =~ ".tar" ]]
		then
			if [ -e ${file%.tar} ]
			then
				echo "Floder ${file%.tar} exists"
			else
				tar -xvf "$file"
			fi
		else 
			cat $file
		fi
	fi
else
	echo "ERROR: Not Find $file"
fi


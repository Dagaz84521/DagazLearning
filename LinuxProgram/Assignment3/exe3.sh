#!/bin/bash
dir1=$1
dir2=$2
FILES=$(ls dir2)
date >> record
for FILE in $FILES
do
	if [ -e "./$dir1/$FILE" ]
	then
		echo "$FILE in $dir2 exists in $dir1"
		if [ "./$dir1/$FILE" -ot "./$dir2/$FILE" ]
		then
			cp "./$dir2/$FILE" "./$dir1"
			echo "Replace a file $FILE from $dir1 to $dir2" >> record
		fi
	else
		echo "$FILE in $dir2 does not exist in $dir1"
		cp "./$dir2/$FILE" "./$dir1"
		echo "Copy a file $FILE from $dir1 to $dir2" >> record
	fi
done

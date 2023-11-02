#! /bin/bash

examinateInput(){
	if [[ $1 =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
	then
		flag=true
	elif [[ $num = "end" ]]
	then
		flag=0
	else
		flag=false
	fi 
}

sum=0
while [[ $num != "end" ]]
do
    read -p "Input a numbejr or input end to exit: " num
    examinateInput $num
    if [ $flag == "true" ]
    then 
    	sum=`echo "scale=2;$sum+$num" | bc`
    elif [ $flag == "false" ]
    then
    	echo "ERROR: Wrong Input"
    fi
done

echo $sum



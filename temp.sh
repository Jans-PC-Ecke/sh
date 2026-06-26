#!/bin/bash

	echo "__   __   __   __"
  	echo "| J | P | C | E | "
   	echo " --    --     --     --"
 #df  ; 

echo 
sensors -A && hddtemp /dev/sda && hddtemp /dev/sdc && hddtemp /dev/sdd && hddtemp /dev/sde 



#!/bin/sh

file=$1
compilationTarget=$2

#exec  1> $"/usercode/logfile.txt"
#exec  2> $"/usercode/errors.txt"
exec  < /dev/null

chmod 777 /usercode/logfile.txt
chmod 777 /usercode/errors.txt

nim $compilationTarget --colors:on --NimblePath:/playground/nimble --nimcache:/usercode/nimcache /usercode/$file &> /usercode/errors.txt
if [ $? -eq 0 ];	then
    /usercode/${file/.nim/""} &> /usercode/logfile.txt
else
    echo "" &> /usercode/logfile.txt
fi

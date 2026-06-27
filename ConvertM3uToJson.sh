#!/bin/sh



echo "[" > output.json
echo "{" >> output.json
echo "    \"name\": \"Ronan\"," >>  output.json
echo "    \"samples\": [" >> output.json

while read -r line1; read -r line2
do
 echo "{" >> output.json
    name=`echo $line1 | awk -F, '{print $2}'`
    
    echo "\"name\": \"$name\"," >> output.json
    name2="$line2"
    echo "\"uri\": \"$name2\"" >> output.json

 echo "}," >> output.json
done < input.m3u


      echo "{" >> output.json
       echo " \"name\": \"RTE News Now\"," >> output.json
       echo " \"uri\": \"http://cdn.rasset.ie/hls-live/_definst_/newsnow/newsnow-576.m3u8\"" >> output.json
      echo "}" >> output.json

echo "]}]" >> output.json


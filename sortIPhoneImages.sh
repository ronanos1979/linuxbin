#!/bin/sh
# ronan
# whatever

echo "Renaming brackets to underscores"
#for file in `find . -type f -name "*(*"`; do NEWNAME=`echo $file | sed -e 's/(/_/g'`; mv -i $file $NEWNAME; echo $NEWNAME; done
for file in `find . -type f -name "*(*"`; do NEWNAME=`echo $file | sed -e 's/(/_/g'`; mv -i $file $NEWNAME; done
#for file in `find . -type f -name "*)*"`; do NEWNAME=`echo $file | sed -e 's/)/_/g'`; mv -i $file $NEWNAME; echo $NEWNAME; done
for file in `find . -type f -name "*)*"`; do NEWNAME=`echo $file | sed -e 's/)/_/g'`; mv -i $file $NEWNAME; done


echo "Moving uppercase extensions to lowercase"
for file in `find . -type f -name "*.JPG"`; do NEWFILE=`echo $file | sed -e 's/JPG/renamed.jpg/g'`; mv -i $file $NEWFILE; done
for file in `find . -type f -name "*.PNG"`; do NEWFILE=`echo $file | sed -e 's/PNG/renamed.png/g'`; mv -i $file $NEWFILE; done
echo "Renaming to EXIF Data Date"
for file in `find . -type f -name "*.jpg"`; do NAME=`mdls $file | grep kMDItemContentModificationDate |  awk '{print $3"_"$4}' | sed -e 's/-//g' | sed -e 's/://g'`; mv -n $file $NAME.jpg; done

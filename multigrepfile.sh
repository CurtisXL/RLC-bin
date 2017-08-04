FILNAM=$1
while read BASDIR
do
	echo "$BASDIR"
	grep "\"$BASDIR\/" out/path/abspath_lines.out
done

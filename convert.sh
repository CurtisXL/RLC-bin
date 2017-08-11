#!/bin/bash

#Compile RLC BBx/BBj Programs

while getopts ":jlrv" opt; do
  case $opt in
	j)	USEBBJ=-j
		;;
    l)	DOLIST=-l 
		;;
    r)	RECURSED=-r 
		;;
	v)	VERBOSE=-v 
		;;
    \?)
      echo "RLC Program Conversion Utility"
	  echo "Usage: $0 [options] [FILESPEC]"
	  echo "Options: j  Compile to (or list from) BBj"
	  echo "         l  List compiled programs"
	  echo "         v  Verbose Mode"
	  echo ""
	  exit 0
      ;;
  esac
done
shift $((OPTIND-1))

#Set Global Variables
CVTACT="Compiling"
CVTBAS=/u/basis/pro5
CVTDIR=BBX
CVTLST=pro5lst
CVTOPT='-m1024'
CVTPGM=pro5cpl
CVTTYP="Pro5"

if [[ $USEBBJ ]]; then
	CVTBAS=/u/basis/bbj/bin
	CVTDIR=BBJ
	CVTLST=bbjlst
	CVTOPT=''
	CVTPGM=bbjcpl
	CVTTYP="BBJ"
fi

if [[ $DOLIST ]]; then
		DEFDIR=$CVTDIR
		CVTDIR=LST
		CVTACT="Listing"
		CVTERR=out/errs/pro5lst.err
		CVTOPT=''
		CVTPGM=$CVTLST
fi

CVTERR=out/errs/$CVTPGM.err
CVTERS=${CVTERR}s

if  [[ ! $RECURSED ]]; then
	rm -f $CVTERS
fi

function process_files {
	PRCLST="$1"
	[[ $VERBOSE ]] && echo "Converting File(s) $PRCLST"
	$CVTBAS/$CVTPGM -d$CVTDIR -e$CVTERR $CVTOPT $PRCLST
	cat $CVTERR >> $CVTERS
}

function process_dir {
	PRCDIR=$1
	[[ $VERBOSE ]] && echo "Reading directory $PRCDIR"
	FILLST=""; #List of files in the directory
	for FILNAM in $(ls $1); do
		if [[ ${FILNAM:0:1} != '.' ]]; then
			FILSPC=$PRCDIR/$FILNAM
			if [[ -d $FILSPC ]]; then
				$0 $USEBBJ $DOLIST -r $VERBOSE "$FILSPC"
			else
				FILLST="$FILLST $FILSPC"
			fi
		fi
	done
	[[ $FILLST ]] && process_files "$FILLST"

}

if [[ "$1" == "" ]]; then
	if [[ "$DEFDIR" == "" ]]; then
		RLCDIR=RLC;
		for SUBDIR in Legacy VPro5; do
			process_dir "RLC/$SUBDIR"
		done
	else
		process_dir "$DEFDIR"
	fi
else
	if [[ -d $1 ]]; then
		process_dir "$1"
	else
		process_files "$1"
	fi
fi


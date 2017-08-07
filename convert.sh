#!/bin/bash

#Compile RLC BBx/BBj Programs

while getopts ":jlv" opt; do
  case $opt in
	j)	USEBBJ=-j
		;;
    l)	DOLIST=-l 
		;;
    v)	VERBOSE=-v 
		;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
	  exit 1
      ;;
  esac
done
shift $((OPTIND-1))

#Set Global Variables
CVTACT="Compiling"
CVTBAS=/u/basis/pro5
CVTDIR=BBX
CVTLST=pro5lst
CVTOPT='-k'
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

function process_file {
	PRCFIL=$1
	[[ $VERBOSE ]] && echo "$CVTACT $CVTTYP file $PRCFIL"
	$CVTBAS/$CVTPGM -d$CVTDIR -e$CVTERR $CVTOPT $PRCFIL
}

function process_dir {
	PRCDIR=$1
	[[ $VERBOSE ]] && echo "Processing directory $PRCDIR"
	for FILNAM in $(ls $1); do
		if [[ ${FILNAM:0:1} != '.' ]]; then
			FILSPC=$PRCDIR/$FILNAM
			if [[ -d $FILSPC ]]; then
				$0 $USEBBJ $DOLIST $VERBOSE "$FILSPC"
			else
				process_file $FILSPC
			fi
		fi
	done
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
		process_file "$1"
	fi
fi


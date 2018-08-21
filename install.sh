#!/usr/bin/env bash

MAX=50
TIME=0.02
TL=""
S="====="
TR=""

function run_command {
    command_name=$1;
    echo $command_name;
    shift;
    "$@"
    status=$?
    if [ $status -ne 0 ]; then
        echo "Error: $command_name";
        exit;
    fi
    echo "Passed: $command_name";
    return $status
}

function run {
    if ! [ -x "$(command -v perl)" ]; then
        echo 'Error: perl is not installed. Cannot install without perl!' >&2
        exit;
    fi
    if ! [ -x "$(command -v cpanm)" ]; then
        echo 'Error: cpanm is not installed. Installing...' >&2
        run_command "Install cpanm" eval "curl -L https://cpanmin.us | perl - --sudo App::cpanminus"
    fi
    run_command "Install modules" eval "cpanm -L . --installdeps . > /dev/null 2>&1"
    run_command "Create tmp dir" eval "mkdir tmp"
    run_command "TESTING get-gene-info.pl" eval "./get-gene-info.pl -type=ncbi -file=test.txt -column=hgnc_id -column=symbol -column=name -column=entrez_id > /dev/null 2>&1"
}

run &
PID=$!

while kill -0 $PID >/dev/null 2>&1; do
    R=0
    while [ $R -lt $MAX ]; do 
        RSP=$(($MAX - $R ))
        if [ $RSP -gt $MAX ]; then RSP=$MAX ; fi 
        LSP=$(($MAX - ${RSP}))
        echo -n "$TL"
        for l in $(seq 1 $LSP); do
            echo -n " "
        done
        echo -n $S
        for r in $(seq 1 $RSP); do
            echo -n " "
        done; echo -ne "$TR\r"
        sleep $TIME ; ((R++))
    done
    while [ $R -ne 0 ]; do
        RSP=$(($MAX - $R ))
        if [ $RSP -ge $MAX ]; then RSP=$MAX ; fi 
        LSP=$(($R + 0 )) 
        if [ $LSP -lt 0 ]; then LSP=0 ; fi 
        echo -n "$TL"
        for l in $(seq 1 $R); do
            echo -n " "
        done
        echo -n $S
        for r in $(seq 1 $RSP); do
            echo -n " "
        done; echo -ne "$TR\r"
        sleep $TIME; ((R--))
    done
done
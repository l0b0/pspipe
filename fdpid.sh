#!/usr/bin/env bash
#
# NAME
#        fdpid - Print the PID of the processes at the other end of a pipe
#
# SYNOPSIS
#        fdpid.sh [OPTIONS] FD PID
#
# DESCRIPTION
#        fdpid prints the PID of the processes (if any) at the "other end" of
#        the pipe.
#
# OPTIONS
#        -h, --help
#               Print this documentation.
#
#        -v, --verbose
#               Verbose output.
#
# EXAMPLES
#        cat /dev/zero | cat - > /dev/null &
#        fdpid.sh 0 $!
#               Prints the PID of the first `cat` process.
#        fdpid.sh 1 $(fdpid.sh 0 $!)
#               Prints the PID of the second `cat` process.
#
#        (yes a & yes b) | cat >/dev/null &
#        fdpid.sh 0 $!
#               Prints the PID of both `yes` processes and the enclosing `bash`
#               process, all of which are connected to `cat`'s standard input.
#
# BUGS
#        https://github.com/l0b0/pspipe/issues
#
# COPYRIGHT AND LICENSE
#        Copyright (C) 2013 Victor Engmark
#
#        This program is free software: you can redistribute it and/or modify
#        it under the terms of the GNU General Public License as published by
#        the Free Software Foundation, either version 3 of the License, or
#        (at your option) any later version.
#
#        This program is distributed in the hope that it will be useful,
#        but WITHOUT ANY WARRANTY; without even the implied warranty of
#        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#        GNU General Public License for more details.
#
#        You should have received a copy of the GNU General Public License
#        along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
################################################################################

set -o errexit -o noclobber -o nounset -o pipefail

includes="$(dirname -- "$0")"/shell-includes
. "$includes"/error.sh
. "$includes"/usage.sh
. "$includes"/variables.sh
. "$includes"/verbose_print_line.sh
unset includes

if [[ ${BASH_VERSINFO[0]} -lt 4 ]]
then
    echo "You need Bash 4 or newer to run this program" >&2
    exit $ex_unknown
fi

# Process parameters
params="$(getopt -o hv -l help,verbose --name "$0" -- "$@")" || usage $ex_usage

eval set -- "$params"
unset params

# Command line options
while true
do
    case $1 in
        -h|--help)
            usage
            ;;
        -v|--verbose)
            verbose='--verbose'
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            error "Not implemented: $1" $ex_software
            ;;
    esac
done

if [ $# -ne 2 ]
then
    # PID parameter missing or too many parameters
    usage $ex_usage
fi

target_fd="$1"
target_pid="$2"

target_pid_path="/proc/${target_pid}"
if [ ! -d "$target_pid_path" ]
then
    error "No such process ID: ${target_pid}"
fi

target_fd_path="${target_pid_path}/fd/${target_fd}"
if [ ! -L "$target_fd_path" ]
then
    error "No such file descriptor for process ID ${target_pid}: ${target_fd}"
fi

target_fd_pipe="$(readlink "$target_fd_path")"
if [[ ! $target_fd_pipe =~ ^pipe: ]]
then
    # This file descriptor is not a pipe
    exit
fi

for pid_path in /proc/[1-9]*
do
    for fd_path in "$pid_path"/fd/*
    do
        if [ ! -r "$fd_path" ]
        then
            # Inaccessible path
            continue 2
        fi
        fd_pipe="$(readlink "$fd_path")"
        if [ "$fd_pipe" = "$target_fd_pipe" ] && [ "$fd_path" != "$target_fd_path" ]
        then
            pid="${pid_path##*/}"
            verbose_print_line "Path: ${fd_path}"
            printf '%s\n' "$pid"
            continue 2 # Next PID
        fi
    done
done

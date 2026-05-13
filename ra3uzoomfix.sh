#!/bin/bash

PROCNAME="ra3ep1_1.0.game"
ADDR=""

echo "RA3ZoomFix running."
echo "Waiting for ${PROCNAME}."

while true; do
    pid=$(pgrep -f "${PROCNAME}")

    if [ -n "$pid" ]; then
        echo "Found PID: $pid. Looking for lock address."

        while [ -z "$ADDR" ]; do
            while read line; do
                if [[ $line =~ ^0x[0-9a-f]+$ ]]; then
                    ADDR="$line"
                    echo "Found lock address: $ADDR"
                    break
                fi
            done < <(
                (
                echo "set pagination off"
                echo "set print thread-events off"

                echo "break *0x5f8528"
                echo "commands"
                echo "silent"
                echo "printf \"0x%x\\n\", \$esi + 0x48"
                echo "detach"
                echo "quit"
                echo "end"

                echo "break *0x52b804"
                echo "commands"
                echo "silent"
                echo "printf \"0x%x\\n\", \$ecx + 0x48"
                echo "detach"
                echo "quit"
                echo "end"

                echo "continue"
                ) | gdb -p "$pid" 2>&1
            )

            sleep 1
        done

        while true; do
            if ! kill -0 "$pid" 2>/dev/null; then
                echo "Game closed. Waiting for new process."
                ADDR=""
                break
            fi

            val=$(sudo dd if=/proc/$pid/mem bs=4 skip=$((ADDR/4)) count=1 2>/dev/null | od -t u4 -An | tr -d ' ')

            if [ "$val" = "1" ]; then
                scanmem -p "$pid" -c "write I32 ${ADDR} 0; exit" >/dev/null 2>&1
                echo "Fix applied."
            fi

            sleep 5
        done
    fi

    sleep 2
done

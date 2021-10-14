# iostat-csv
Convert iostat output every second in one line and generates a csv file.

## Usage
Execute the script and it outputs a line to stdout in every seconds.
```
./iostat-csv.sh
```

If you want to save the result, do like this:
```
./iostat-csv.sh | tee -a iostat$(date +%Y%m%d%H%M).csv
```

Then you can process the csv file with other tools like awk, gnuplot, MSExcel, OpenOfficeCalc, etc.
This might be useful to investigate io-related problems. This script is tested in RHEL6/RHEL7.

## Output example

* iostat default output looks like:
```
root@localhost:~# iostat -t -x 1
Linux 3.16.0-57-generic (localhost)        03/13/16        _x86_64_        (2 CPU)

02/04/17 01:05:36
avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.05    0.00    0.03    0.00    0.00   99.91

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
vda               0.00     0.07    0.05    0.10     0.74     2.68    46.22     0.00    1.72    1.24    1.93   0.17   0.00
scd1              0.00     0.00    0.00    0.00     0.00     0.00     6.17     0.00    0.33    0.33    0.00   0.33   0.00
```

* When you start this script, it prints a header line like this:
```
Date,Time,%user,%nice,%system,%iowait,%steal,%idle,Device,rrqm/s,wrqm/s,r/s,w/s,rkB/s,wkB/s,avgrq-sz,avgqu-sz,await,r_await,w_await,svctm,%util,Device,rrqm/s,wrqm/s,r/s,w/s,rkB/s,wkB/s,avgrq-sz,avgqu-sz,await,r_await,w_await,svctm,%util
```

* In each second, it prints a line like this:
```
02/04/17,01:05:36,0.05,0.00,0.03,0.00,0.00,99.91,vda,0.00,0.07,0.05,0.10,0.74,2.68,46.22,0.00,1.72,1.24,1.93,0.17,0.00,scd1,0.00,0.00,0.00,0.00,0.00,0.00,6.17,0.00,0.33,0.33,0.00,0.33,0.00
```

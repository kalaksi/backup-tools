# General
This is a collection of simple scripts for backup purposes.  
These tools are meant to have very few dependencies so they should be very easy to deploy. They have been developed for Linux but I'm open to making them more portable.


# Details
## checksumfile-create & checksumfile-verify
These tools were inspired by `shatag` with 3 important differences:  
1. Written in bash (4.4) with usually no additional dependencies.
2. Data is stored using common files which makes it simpler and filesystem-agnostic if you don't mind the extra files ("SHA256SUMS"-file). Do note that this also means that the original checksums are kept even when copying files between filesystems. This provides protection against other software or user errors, but is mostly usable for data that doesn't change often.
3. Verification result and timestamp is stored in the checksum-file(s), so they are not lost.

Basically, these scripts form an extension for existing checksumming tools such as `sha256sum`.  
The main purpose is to make operating on directories simple and to provide functionality for periodic scrubbing/checking.
It's also possible add or delete files from the checksum file seamlessly.
  
The default settings are aimed for files that are divided into subdirectories (`-d 1`).  
Use `-h` to see the details of available configuration options.

### Examples
#### Default parameters, on a photo album

Create or update the checksum file:
```
$ ./checksumfile-create.sh -u Photos/
  Photos/2018:
    ./birthday/abc.jpg
    ./birthday/def.jpg
  Photos/2019:
    ./birthday/cake/abc.jpg
  Photos/2020:
    109 existing checksums available. Checking for new or deleted files... 
    Added ./summer/abc.jpg
    Added ./summer/def.jpg

Completed without errors.
```

Ignore txt-files:
```
$ ./checksumfile-create.sh -u -f '-not -name "*.txt"' Photos/
```

Create the file for the selected directory instead of immediate subdirectories:
```
./checksumfile-create.sh -d 0 Photos/
  Photos:
    ./2018/birthday/abc.jpg
    ./2018/birthday/def.jpg
```

Verify that they haven't changed:
```
$ ./checksumfile-verify.sh -p 2 Photos/

Processing directory Photos/ containing 3 available checksum files:
  Photos/2018:
    ./birthday/abc.jpg: OK
    ./birthday/def.jpg: OK
  Photos/2019:
    ./birthday/cake/abc.jpg

Reached target percentage 2% of checked checksums.
3/116 checksums checked. 0 errors found!
```

Only print errors when verifying (Useful for cron jobs. Checking the exit code can also help.):
```
$ ./checksumfile-verify.sh Photos/ >/dev/null
1 errors found!
```



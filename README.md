# General
This is a collection of simple scripts for backup purposes.  
These tools are meant to have very few dependencies so they should be very easy to deploy. They have been developed for Linux but I'm open to making them more portable.


# Details
## checksumfile-create & checksumfile-verify
These tools were inspired by `shatag` with 2 important differences:  
1. written in bash with usually no additional dependencies
2. data is stored using common files which makes it simpler and filesystem-agnostic if you don't mind the extra files ("SHA256SUMS"-file)

Technically speaking, these scripts form an extension for checksumming tools such as `sha256sum`.  
The main goal is to allow operating on directories simple and to provide functionality for periodic scrubbing/checking.
It's also possible add new or delete files from the checksum file seamlessly.
  
The default settings are aimed for directories containing media larger than 50k and divided into subdirectories.  
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


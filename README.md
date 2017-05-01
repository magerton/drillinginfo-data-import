# Overview

This repo contains code to verify the version of Drillinginfo's DI Desktop Raw PLUS flat files and import them to R and Stata formats (.Rdata and .dta) using R. Memory requirements are in excess of 32Gb for the code as run. See the [Requirements](#requirements) section for more on this.

There are three R scripts:

1. [Table-Schema-Definitions.R](R/Table-Schema-Definitions.R) contains a re-formatted version of the DI-provided document Oracle-database table schema and descriptions of each field. It saves this information as lists of named string vectors. Imported column names and types are based on this information
2. [R/01-import-DI-flat-files-and-save.R](R/01-import-DI-flat-files-and-save.R) Imports unzipped csv files, converts columns as needed, adds column labels, and saves as both `data.table` objects in .Rdata files and Stata .dta data files.
3. [R/02-open-saved-DI-flat-files.R](R/02-open-saved-DI-flat-files.R) Post-import script opens up each saved file (including import problems) and prints class of each column in each table. Not needed.

Workflow

1. Clone this repo to your machine
2. Download both zipfiles via web interface or command line using `lftp`, available on [Homebrew](https://brew.sh/) for OS X, Cygwin for Windows 7, and the Ubuntu package manager for the Windows 10 Subsystem for Linux.
    ```sh
    lftp -u "USERNAME,PASSWORD" ftp://fileshare.drillinginfo.com -e "mirror --parallel=3 . ."
    ```
3. Verify zipfile checksums against those in [checksums.md](checksums.md) to ensure complete download and verify the date of the DI flat files.
    a. Ubuntu `md5sum * > checksums.md5`
    b. Windows: there are a few 3rd party programs that compute hashes. One is [hashcheck](http://code.kliu.org/hashcheck/), which integrates with File Explorer and will generate md5 checksum files.
    c. OS X Terminal: `md5 * > checksums.md5`
3. Extract the zipfiles to [./tmp](./tmp) or some other directory,. One can use the shell command `unzip` in OS X or Ubuntu.
4. Set the appropriate parameters in [R/01-import-DI-flat-files-and-save.R](R/01-import-DI-flat-files-and-save.R) (these are in all caps at the beginning of the file) and run the script.


# Issues / Improvements

The are three known issues at this point. 

1. On Windows (but not Ubuntu), `readr::read_csv()` detects "Embedded nul" characters in several of the tables and throws associated warnings. These are all collected and saved in a separate .Rdata file. There are a couple of questions
    a. Are these characters supposed to be there? Why did DI include them?
    b. Why, when run on Windows, does `readr::read_csv` find embedded nulls, but when run on Ubuntu using EC2 instance, does it not?
2. The order that the DI documentation lists columns when the column type is specified is not exactly the same as when the description is specified. I am assuming that the order of the column type information is correct.
3. There is no table schema information for the file UIC.txt
4. Can we get a longer history of md5 checksums for the DI Desktop Raw Data PLUS flat files? See [checksums.md](checksums.md)

There are also a few improvements that could be made:

1. Lower the memory requirements. This code was run on an Amazon EC2 instance with 61 Gb RAM. See [amazon-ec2-directions.md](amazon-ec2-directions.md) for discussion of this
2. Lower the hard disk requirements. This code was run on an Amazon EC2 instance with 200Gb of hard drive space and the repo with uncompressed .txt files plus all compressed .Rdata and .dta files was 46Gb. (This high requirement could be helped by unzipping, importing, and saving files one-by-one. Files could also be saved in one format only.)
3. Accelerate saving .Rdata files. One of the bottlenecks is saving the compressed .Rdata files. This could be sped up using the command-line parallel zip program `pigz` or using a different compression scheme like `xz`. For example [R documentation](https://stat.ethz.ch/R-manual/R-devel/library/base/html/save.html) for `base::save()` provides this example:
    ```R
    con <- pipe("pigz -p8 > fname.gz", "wb")
    save(myObj, file = con); close(con)
    ```

# Requirements

This repo is written in R. The required packages can be installed with `install.packages(c("haven", "lubridate", "readr", "R.utils", "data.table"))`. If writing data to Stata's .dta format, one can optionally gzip the .dta files and save considerable hard drive space. Zipping can be accelerated by optionally using the parallelized gzip command-line program `pigz` instead of `R.utils::gzip()`. `pigz` is optionally invoked from R using `system2()` if it is on the system path.

The DI flat-files are fairly large and have the corresponding RAM requirements to load in memory. While every effort has been made to be efficient with memory by using R's `data.table` package and fast CSV readers `data.table::fread()` and `readr::read_csv()`, the code as run requires in excess than 32Gb of RAM. If this hardware is not immediately available, there are two easy fixes detailed below.

First, since the biggest memory requirement is involved in converting dates from the `character` to the `Date` class in the PDEN_PROD table, one can skip this conversion, save the production data with string date information, and subset the production data later. Second, one can rent a r4.2xlarge Amazon EC2 spot instance for a couple of dollars at most. Some notes on doing this are in [amazon-ec2-directions.md](amazon-ec2-directions.md)

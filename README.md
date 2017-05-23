# Overview

This repo contains code to verify the version of Drillinginfo's DI Desktop Raw PLUS flat files and import them to R and Stata formats (.Rdata and .dta) using R. Memory requirements are 16Gb for the code to run, and 32Gb if dates are converted from `character` to `Date`. See the [Requirements](#requirements) section for more on this.

# Requirements

This repo is written in R. The required packages can be installed with `install.packages(c("haven", "lubridate", "readr", "R.utils", "data.table"))`. If writing data to Stata's .dta format, one can optionally gzip the .dta files and save considerable hard drive space. Zipping can be accelerated by optionally using the parallelized gzip command-line program `pigz` instead of `R.utils::gzip()`. `pigz` is optionally invoked from R using `system2()` if it is on the system path.

The DI flat-files are fairly large and have the corresponding RAM requirements to load in memory. While every effort has been made to be efficient with memory by using R's `data.table` package and fast CSV readers `data.table::fread()` and `readr::read_csv()`, the code requires 16Gb of RAM to read in all tables, and 32Gb if dates in the production data table (PDEN_PROD) are to be converted from string to date. Whether this conversion is done or not is determined by the flag `CONVERT_PROD_CHARDATE_TO_DATE`.

# Using the scripts

1. Clone this repo to your machine
2. Download both zipfiles containing DI flat files via web interface or command line using `lftp`, available on [Homebrew](https://brew.sh/) for OS X, Cygwin for Windows 7, and the Ubuntu package manager for the Windows 10 Subsystem for Linux.
    ```sh
    lftp -u "USERNAME,PASSWORD" ftp://fileshare.drillinginfo.com -e "mirror --parallel=3 . ."
    ```
3. Verify zipfile checksums against those in [checksums.md](checksums.md) to ensure complete download and verify the date of the DI flat files.
    - Ubuntu `md5sum * > checksums.md5`
    - Windows: there are a few 3rd party programs that compute hashes. One is [hashcheck](http://code.kliu.org/hashcheck/), which integrates with File Explorer and will generate md5 checksum files.
    - OS X Terminal: `md5 * > checksums.md5`
3. Extract the zipfiles to [./tmp](./tmp) or some other directory,. One can use the shell command `unzip` in OS X or Ubuntu.
4. Set the appropriate parameters in [R/01-import-DI-flat-files-and-save.R](R/01-import-DI-flat-files-and-save.R) (these are in all caps at the beginning of the file) and run the script.

# R scripts

1. [Table-Schema-Definitions.R](R/Table-Schema-Definitions.R) contains a re-formatted version of the DI-provided document Oracle-database table schema and descriptions of each field. It saves this information as lists of named string vectors. Imported column names and types are based on this information
2. [R/01-import-DI-flat-files-and-save.R](R/01-import-DI-flat-files-and-save.R) Imports unzipped csv files, converts columns as needed, adds column labels, and saves as both `data.table` objects in .Rdata files and Stata .dta data files.
3. [R/02-open-saved-DI-flat-files.R](R/02-open-saved-DI-flat-files.R) Post-import script opens up each saved file (including import problems) and prints class of each column in each table. Not needed.

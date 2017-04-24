# Overview

This repo contains code to verify the version of Drillinginfo's DI Desktop Raw PLUS flat files and import them to R and Stata formats (.Rdata and .dta) using R.

There are three R scripts:

1. [Table Schema Definitions.R](R/Table-Schema-Definitions.R) contains a re-formatted version of the DI-provided document Oracle-database table schema and descriptions of each field. It saves this information as lists of named string vectors. Imported column names and types are based on this information
2. [R/01 import DI flat files and save.R](R/01 import DI flat files and save.R) Imports unzipped csv files, converts columns as needed, adds column labels, and saves as both `data.table` objects in .Rdata files and Stata .dta data files.
3. [R/02 open saved DI flat files.R](R/02 open saved DI flat files.R) Post-import script opens up each saved file (including import problems) and prints class of each column in each table. Not needed.
4. [new readme](R/README.md)

Workflow

1. Clone this repo to your machine
2. After downloading both zipfiles, verify their checksums against [those listed below](#checksums) to ensure complete download and verify the date of the DI flat files.
    a. On Ubuntu, use `md5sum`
    b. On Windows, the [hashcheck](http://code.kliu.org/hashcheck/) program integrates with File Explorer and will generate md5 checksum files.
    c. On OS X, use `md5` from teh command prompt
3. Extract the zipfiles to a temporary directory (a default one is provided in this repo)
4. Set the appropriate parameters in [01 import DI flat files and save.R](01 import DI flat files and save.R) (these are in all caps at the beginning of the file) and run

# Known issues

The are a few minor known issues at this point. 

1. On Windows (but not Ubuntu), `readr::read_csv()` detects "Embedded nul" characters in several of the tables and throws associated warnings. These are all collected and saved in a separate .Rdata file. There are a couple of questions
    a. Are these characters supposed to be there? Why did DI include them?
    b. Why, when run on Windows, does `readr::read_csv` find embedded nulls and save to file with import problems, but when run on Ubuntu using EC2 instance, it does not?
2. High memory requirements
3. The order that the DI documentation lists columns when the column type is specified is not exactly the same as when the description is specified. I am assuming that the order of the column type information is correct.
4. 

# Requirements

This repo is written in R. The required packages can be installed with `install.packages(c("haven", "lubridate", "readr", "R.utils", "data.table"))`. The datasets are fairly large and have corresponding RAM requirements. While every effort has been made to be efficient with memory by using R's `data.table` package and fast CSV readers from the `data.table` and `readr` packages, as run, the code requires in excess than 32Gb of RAM. If this hardware is not immediately available, there are two easy fixes detailed below.

First, since the biggest memory requirement is involved in converting dates from the `character` to the `Date` class in the PDEN_PROD table, one can skip this conversion, save the production data with string date information, and subset the production data later. Second, one can rent an 64Gb Amazon EC2 cluster spot instance for a couple of dollars at most.  

# Checksums

| Release Date | File                           | md5 checksum                     |
| ------------ | ------------------------------ | -------------------------------- |
| 2017-03-31   | *dihpdi_plus_prod_PRIMARY.zip  | 5cb933943fcd8676e79d40d56fa46037 |
| 2017-03-31   | *dihpdi_plus_other_PRIMARY.zip | ae52248a84b6f783d25c17582d0c626f |
| 2017-02-28   | *dihpdi_plus_prod_PRIMARY.zip  | 234cceb05b55494939ad5cee453d7c33 |
| 2017-02-28   | *dihpdi_plus_other_PRIMARY.zip | aa4879fe6f844528b504a259a28ec87f |

# Working with Amazon EC2 Clusters

1. Sign up for an Amazon EC2 account at <https://aws.amazon.com/ec2>
2. Save your Amazon ssh key on your computer so you can log in to EC2 and add it to your ssh agent.
3. RStudio Server is easy to set up by using one of the Amazon Machine Images (AMIs) provided at <http://www.louisaslett.com/RStudio_AMI/>
4. Open a 61+Gb memory-optimized EC2 spot instance. 
    - AMI > Select on your AMI > Under "Actions," select "Spot Request" > Request a big instance, and set the MAX price you are willing to pay per hour (This appears to be a uniform price auction, and the market price is usually much lower than this. I have found that a $1/hr maximum price is usually sufficient.)
    - Make sure to enable SSH and HTTP security protocols
4. Start the EC2 instance
5. SSH into the instance as root (right click on the instance in "Running Instances" & hit "connect" to get the terminal command. It should be something like `ssh ubuntu@99.99.99.99.99`). Make your project directory.
6. Transfer DI files and code over SSH. You can either set up your ssh key for the `rstudio` user, or move project files to the root user via ssh and then transfer them to the `rstudio` home directory.
    - The first way can be accomplished with
    ```sh
    tar cvz LOCAL_PROJECT_DIRECTORY/ | ssh ubunbtu@99.99.99.99.99 "cd [REMOTE_PROJECT_DIRECTORY] && tar xvz"
    mv ~/REMOTE_PROJECT_DIRECTORY ../rstudio/REMOTE_PROJECT_DIRECTORY
    sudo chown rstudio - R ../rstudio/REMOTE_PROJECT_DIRECTORY
    ```
    - See <http://unix.stackexchange.com/questions/10026/how-can-i-best-copy-large-numbers-of-small-files-over-scp>
7. Point your web browser to your EC2 IP address and login as user rstudio with password rstudio (I believe)
8. Run the import scripts
9. To move files from the remote EC2 instance to your local machine
    a. it's probably best to use `rsync` to ensure files completely transferred:
        ```sh
        rsync -chavzP -f '- /*/*/' --stats rstudio@99.99.99.99:REMOTE_PROJECT_DIRECTORY/intermediate_data LOCAL_PROJECT_DIRECTORY/
        ```
    b. Can also use `tar` and `ssh` again: <http://meinit.nl/using-tar-and-ssh-to-efficiently-copy-files-preserving-permissions>






# Working with Amazon EC2 Clusters

1. Sign up for an Amazon EC2 account at <https://aws.amazon.com/ec2>
2. Save your Amazon ssh key on your computer so you can log in to EC2 and add it to your ssh agent.
3. RStudio Server is easy to set up by using one of the Amazon Machine Images (AMIs) provided at <http://www.louisaslett.com/RStudio_AMI/>
4. Open a 61+Gb memory-optimized EC2 spot instance like "r4.2xlarge" and make sure it has plenty of hard drive space. (Alternatively, one could open up a smaller instance, configure it, and save as a personalized AMI for use again in the future. Then one would relaunch it as a larger AMI.)
    - AMI > Select on your AMI > Under "Actions," select "Spot Request" > Request a big instance, and set the MAX price you are willing to pay per hour (This appears to be a uniform price auction, and the market price is usually much lower than this. I have found that a $1/hr maximum price is usually sufficient.)
    - Make sure to enable SSH and HTTP security protocols
4. Start the EC2 instance
5. SSH into the instance as the admin user "ubuntu" (right click on the instance in "Running Instances" & hit "connect" to get the terminal command. It should be something like `ssh ubuntu@99.99.99.99.99`). Make your project directory.
6. Transfer DI files and code over SSH. You can either set up your ssh key for the rstudio user and ssh in as rstudio, or move project files to the admin user ubuntu via ssh and then transfer them to the rstudio home directory.
    - The second way can be accomplished with
    ```sh
    tar cvz LOCAL_PROJECT_DIRECTORY/ | ssh ubunbtu@99.99.99.99.99 "cd REMOTE_PROJECT_DIRECTORY && tar xvz"
    mv ~/REMOTE_PROJECT_DIRECTORY ../rstudio/REMOTE_PROJECT_DIRECTORY
    sudo chown rstudio - R ../rstudio/REMOTE_PROJECT_DIRECTORY
    ```
    - See <http://unix.stackexchange.com/questions/10026/how-can-i-best-copy-large-numbers-of-small-files-over-scp>
7. Point your web browser to your EC2 IP address and login as user rstudio with password rstudio (I believe)
8. Run the import scripts
9. To move files from the remote EC2 instance to your local machine
    a. it's probably best to use `rsync` which computes hashes of transferred files to check they are completely transferred. For example, if ssh is set up for user rstudio, one can run
    ```sh
    rsync -chavzP -f '- /*/*/' --stats rstudio@99.99.99.99:REMOTE_PROJECT_DIRECTORY/intermediate_data LOCAL_PROJECT_DIRECTORY/intermediate_data
    rsync -chavzP -f '- /*/*/' --stats rstudio@99.99.99.99:REMOTE_PROJECT_DIRECTORY/intermediate_data/dta LOCAL_PROJECT_DIRECTORY/intermediate_data/dta
    ```
    If ssh is not set up for the rstudio user, one can also move these files to the user ubuntu and then run the command.

    b. Can also use `tar` and `ssh` again: <http://meinit.nl/using-tar-and-ssh-to-efficiently-copy-files-preserving-permissions>
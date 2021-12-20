---
name: Report a bug with the install script
about: Create a report to help us improve
title: ''
labels: ''
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is. For issues with Agent DVR itself please use the [Reddit Forum](https://www.reddit.com/r/ispyconnect/) - This repo is for issues with installing and starting Agent DVR.

**Information**
- OS name
- OS version
- 32 bit or 64 bit

**Console output from installer**
Please paste the output from the installer showing the error messages

**If the install script completed successfully but Agent doesn't start and complains about a file not found**
Change to the Agent DVR directory in terminal and run:

    ldd libcvextern.so (or whatever library is causing issues). 

The output should tell you which dependencies need to be installed.  Try installing these dependencies using (replace xxxx with the missing dependency name):

    sudo apt-get install xxxx

.. and update this report with the missing libraries.

**Additional context**
Add any other context about the problem here.

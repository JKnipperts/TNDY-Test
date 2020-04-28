# TNDY-Test
Test utility for the TNDY and TNDLPT Tandy sound boards

Small program to test the Tandy 3-voice sound chip on different ports including parallel ports for use with TNDLPT 

28/04/2020 - Release of Version 0.6 
- Some bugfixes
- Better support of the TNDLPT
- Added support of the new TNDLPT plug
- Added MDA/HERCULES support
- Added better support of slow cpus and removed 286 instructions
- Added advanced test sequence for a quick function test
- Added option to play a melody using the different tone generators

A few command line parameters are also available:
/TEST <Port> will only execute the test sequence using the specified port. For example TESTTNDY.EXE /TEST LPT1 
/K forces keyboard control 
/MDA forces monochrome text mode
/COLOR forces colored text mode 
/? Lists the possible parameters



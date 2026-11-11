# pair-cmd.sh
<p>Quickly lookup ShadowImage and TrueCopy information on Hitachi VSP series arrays using CLI. This program does almost everything that Storage Navigator / Device Manager / Ops Center Protector does, but much faster within an ssh terminal. This was initially created to display an easier to read version of the pairdisplay command, but later evolved to perform other useful tasks, such as the commands listed below. The commands generated are intended to be saved and executed later using Cut&Paste.</p>
<div align="center">
  
Cmd | Operation | Description 
:--      | :--      | :--     
pd | Pair Status | Display pair status of the volumes with a device group.
pvc | Group Status | Display a status summary for the entire device group.
pc | Pair Create | Create new volume pairs, start P-VOL -> S-VOL synchronization.
ps | Pair Suspend | Split volume pairs, and allow R/W access to S-VOLs.
pr | Pair Resync | Resync S-VOL with new P-VOL data, then restart P-VOL -> S-VOL.
pcs | Pair Create + Suspend | Create and split pairs simultaneously. (SI only)
psd | Pair Delete | Delete pairs. A paircreate is required to restore paired state.
prr | Reverse Pair Resync | Perform reverse re-sync, ie. S-VOL -> P-VOL.
ht | Horcm Takeover | Split volume pairs, and sync in the opposite direction. (TC only)

</div>
<p>For safety, all commands generated within this script are commented to prevent an accidental execution should they be inadvertantly pasted in an active SSH terminal session. The purpose of the status command is to quickly show which TrueCopy and ShadowImage groups are active, along with the replication direction (source to target). Since ShadowImage groups replicate within the same array, their serial number pairs will always be identical.</p>

    $ pair-cmd.sh --help
    usage: pair-cmd.sh <serial_number> [ [status]|[device_group] ]

    $ pair-cmd.sh
    350101 - Data Center 1
    350102 - Data Center 2

    $ pair-cmd.sh 350101 status
    350101 - Data Center 1

    Type  Group                Replication
    ----  -------------------  --------------
    TC    Prod_App1            350101->350102
    TC    Prod_App2            350101->350102
    ----  -------------------  --------------
    SI    Dev_App3             350101->350101
    ----  -------------------  --------------

    $ pair-cmd.sh 350101
    This script is non-disruptive, ie. does not make changes to the current SAN environment.

    It can be used to determine current HORCM pair status, and/or generate commands for future
    pair operations. These commands are commented to inhibit accidental, non-intended execution.
    Command syntax is also provided, along with additional options, based on the replication
    type in use.

    For pair operations with new True Copy pairs configured but not yet established, the CTG ID
    (Consistency Group ID) is automatically generated, and is guaranteed to be unique from those
    currently in use.

    Main Menu:
    
      pd = Pair Status (pairdisplay)   pvc = Group Status (pairvolchk)

      pc = Pair Create (paircreate)    pcs = Pair Create + Suspend (paircreate)
      ps = Pair Suspend (pairsplit)    psd = Pair Delete (pairsplit)
      pr = Pair Resync (pairresync)    prr = Reverse Pair Resync (pairresync)
      
      ht = Reverse Pair Resync DR (horctakeover)

       ? = Additional Info
       q = quit

    [350101 - Data Center 1] pair-cmd> pd
    
    Device Groups:
    
       1. (TC) Prod_App1
       2. (TC) Prod_App2
       3. (SI) Dev_App3

    [350101 - Data Center 1] group> 3
    
    350101 - Data Center 1

    Group               PairVol    L/R  Port#    TID  LU  M  Seq#    LDEV#  P/S   Status  %  P-LDEV#  M  CTG  CM  EM  E-Seq#  E-LDEV#  DM  P
    ------------------  ---------  ---  -------  ---  --  -  ------  -----  ----  ------  -  -------  -  ---  --  --  ------  -------  --  -
    Dev_App3            10A0-20A0  L    CL5-A-1  0    1   0  350101  10a0   SMPL  -       -  -        -  -    -   -   -       -        -   -
    Dev_App3            10A1-20A1  L    CL5-A-1  0    1   0  350101  10a1   SMPL  -       -  -        -  -    -   -   -       -        -   -
    ...

    Main Menu:
    
      pd = Pair Status (pairdisplay)   pvc = Group Status (pairvolchk)

      pc = Pair Create (paircreate)    pcs = Pair Create + Suspend (paircreate)
      ps = Pair Suspend (pairsplit)    psd = Pair Delete (pairsplit)
      pr = Pair Resync (pairresync)    prr = Reverse Pair Resync (pairresync)
      
      ht = Reverse Pair Resync DR (horctakeover)

       ? = Additional Info
       q = quit

    [350101 - Data Center 1] pair-cmd> pc
    
    Device Groups:   
    
       1. (TC) Prod_App1
       2. (TC) Prod_App2
       3. (SI) Dev_App3

    [350101 - Data Center 1] group> 3
    
    Create new volume pairs from two unpaired volumes.
      # paircreate -g <group> [-d <pair Vol>] -vl [-c <size>] -ISI[#]

    Perform the operation for the entire group, or by individual pair.
      # paircreate -g Dev_App3 -vl -c 15 -ISI100

      # paircreate -g Dev_App3 -d 10A0-20A0 -vl -c 15 -ISI100
      # paircreate -g Dev_App3 -d 10A1-20A1 -vl -c 15 -ISI100
      ...

    [350101 Data Center 1] pair-cmd> q
    $

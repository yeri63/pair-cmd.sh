# pair-cmd.sh
<p>Quickly lookup ShadowImage and TrueCopy replication state, create, split, restore, and delete pair groups using CLI in a ssh terminal.
Quickly lookup ShadowImage and TrueCopy information on Hitachi VSP series arrays using CLI. This program does almost everything that Storage Navigator / Device Manager / Ops Center Protector does, but much faster using an ssh terminal. This was initially created to display an easier to read version of the pairdisplay command, but later evolved to perform other useful tasks, like displaying the pair status by group, generating paircreate, pairsplit, pairresync, paircreate with suspend, pairdelete, reverse pairresync, and horctakeover commands. These could then be used to Cut&Paste and execute at a later time within a change window.</p>
<p>For safety, all commands generated within this script are commented, to prevent an accidental execution should they be inadvertantly pasted in an active SSH terminal session prior to the date in the change ticket.</p>

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

    [350101 - Data Center 1] pair-cmd> 

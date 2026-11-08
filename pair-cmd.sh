#!/bin/bash

# Program: pair-cmd4.sh
#    Date: 30-Sep-2026
# Version: 2.2 

# Create a scripted method of performing common pair operations.

# Global Constants and Variables

filename="pair-cmd.sh"                           # Script name showin in messages.
program="pair-cmd"

serials="356727 356617 715130 745001"            # Preferred order of arrays.

array[356727]="Mercy Drive VSP G1500"            # Storage array names.
array[356617]="Sun Trust VSP G1500"
array[715130]="Mercy Drive VSP E1090"
array[745001]="Sun Trust VSP E1090"

model[356727]="g1500"                            # Storage array models.
model[356617]="g1500"
model[715130]="e1090"
model[745001]="e1090"

horcm[356727]="60 30"                            # HORCM TC and SI instances.
horcm[356617]="61 40"                            
horcm[715130]="62 32"                            
horcm[745001]="63 42"                            

server[356727]="lpr-hdsprb-ap01"                 # Probe servers. 
server[356617]="lpr-hdsprb-ap02"
server[715130]="lpr-hdsprb-ap01"                 
server[745001]="lpr-hdsprb-ap02"                 

user="saninfo"                                   # Username for ssh operations.

group=""

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_validate ()
{
    for serial in "${!array[@]}"; do             # Validate storage system serial.
        if [ $1 == $serial ]; then
            return 
        fi
    done

    param_error "non-existent array"             # Invalid array serial provided.
    list_arrays
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

list_arrays ()
{
    echo
    
    for serial in $serials; do
        printf "%6s - " $serial
        echo ${array[$serial]}
    done 

    echo
    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

read_HORCM_config ()

# Read the HORCM configuration files for the selected array to collect all of the Device Group and 
# Instance values.

{
    # n = Total number of Groups discovered.
    n=1 

    sn=$array_serial

    # For each HORCM config file, skip down to the HORCM_INST section to collect the Group names.
    # Ignore HORCM config files used for CMD-DEV and ShadowImage S-VOLs.

    for inst in ${horcm[$array_serial]}; do
        if [[ `ssh -q $user@${server[$sn]} "grep ShadowImage /etc/horcm$inst.conf"` ]]; then
            mode="ISI"
        else
            mode="ITC"
        fi

        for group in `ssh -q $user@${server[$sn]} "cat /etc/horcm$inst.conf" | awk '
            BEGIN { while (!match($0, "HORCM_INST")) getline;
                    getline }

            { if ((length($0) > 0) && (substr($1,1,1) != "#"))
                  print $1; }'`; do

            instance[n]=$mode$inst
            dev_group[n]=$group

            (( n++ ))
        done
    done

    group=""
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

function ctrlBreak_report ()
{
    array_header

    column -t | awk -v field=$1 '
        BEGIN { indent = "  "; hr = "";
                print; }

        { # Read report into an array and determine maximum line length.

          line[i++] = $0;

          # Record the max column length within column array.

          n = length($0);

          for (j=1; j<=n; j++)
              if (substr($0, j, 1) != " ")
                  col[j] = 1;

          if (n > max)
              max = n; }

        END { # Generate horizontal rule line for each column, where the column line length matches
              # the longest element within the column.

              for (j=1; j<=max; j++)
                  if (col[j] == 1)
                      hr = hr "-";
                  else
                      hr = hr " ";

              # Print the report.

              for (j=0; j<i; j++) {
                   # If the monitored field changes, issue a control break in the report.

                   split(line[j], a, " ");

                   if (( a[field] != last ) && ( j != 0 )) 
                       printf("%s%s\n", indent, hr);

                   last = a[field]; 
                   printf("%s%s\n", indent, line[j]); }

              printf("%s%s\n", indent, hr); }'
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

group_option ()

# Provide additional option to automatically show the pairdisplay of a group, if that group name is
# entered following the script name; or display all groups if status was requested.

{
 if [ $# -eq 0 ]; then
        return
    fi

    if [ "$1" == "status" ]; then
         { echo
           echo "Type Group Replication"

           for (( i=1; i<n; i++ )); do
               group=${dev_group[i]}
               group_inst=${instance[i]}
               echo ${instance[i]:1:2} ${dev_group[i]} $(pair_direction)
           done } | ctrlBreak_report 1

        echo
        exit
    fi

    count=0

    for (( i=1; i<n; i++ )); do
        if [[ "${dev_group[i]}" =~ "$1" ]]; then
            group=${dev_group[i]}
            group_inst=${instance[i]}
            (( count++ ))
            if [[ "${dev_group[i]}" == "$1" ]]; then       # Added to allow similar prefixes.
                count=1
                break
            fi
        fi
    done

    if [ $count -gt 1 ]; then
        echo "Multiple pair-groups found. Please be more specific."
        echo
        exit -1
    fi

    if [ $count -eq 1 ]; then
        pair_display
        echo
        exit
    fi

    echo "Non-existent pair-group."
    echo
    exit -1
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

function current_ctgid ()

# Determine the current Consistency Group ID.

# Since some pairs may be in SMPL mode, need to check each pair within the group until a valid 
# CTG is found. If none, return nothing.

{
    group=$1
    inst=$2

    echo "current_ctgid()" 
    echo "group = $group" 
    echo "inst = $inst" 

    for ctg in `pairdisplay -g $group -fcxe -CLI -$inst | column -t | sed '1d' | awk '{ print $15 }'`; do
        if [[ $ctg != "-" ]]; then

            echo "ctg = $ctg" 

            echo $ctg
            exit
        fi
    done
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

function next_ctgid ()

# Collect every Consistency Group ID (CTGID) to determine the next one available.

{
    ctgid=""
    sn=$array_serial

    echo "next_ctgid()" 
    echo "serial = $sn" 

    for filename in `ssh -q $user@${server[$sn]} "grep -l TrueCopy /etc/horcm*.conf"`; do
        inst="ITC"`echo $filename | tail -c +11 | head -c -6`

        for group in `ssh -q $user@${server[$sn]} "cat /etc/horcm${inst:3:2}.conf" | awk '/INST/  { getline; getline; i=1 } 
                                                                                             i == 1 && NF > 0 { print $1 }'`; do
            if [[ ${#group} != 0 ]]; then
                ctgids[$(current_ctgid $group $inst)]=1
            fi
        done
    done

    avail=0

    while [[ ${ctgids[avail]} == 1 ]]; do
        (( avail++ ))
    done

    echo $avail
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

function pair_state ()

# Determine status of Local volumes (P-VOLs or S-VOLS), which shows the replication direction.

{
    pair_display | awk '/ L / { print $9; exit; }'
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

function pair_direction ()

# Determine replication direction of the volume pairs.

# The number of fields and placement within pairdisplay output for ShadowImage and TrueCopy is different.

{
    sn=$array_serial

    pair_display | awk '      { if (NF > 21) {
                                    array = $7;
                                    volume = $9; }
                                else {
                                    array = $8;
                                    volume = $10; }}
                                    
                       / L / {  local_array = array;
                                if (volume == "P-VOL")
                                    direction = "->";
                                else if (volume == "S-VOL")
                                    direction = "<-"; 
                                else
                                    direction = "--" }

                       / R / { remote_array = array;
                               if (direction != "--")
                                   printf("%s%s%s\n", local_array, direction, remote_array);
                               else
                                   print " ";
                               exit }'
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

pair_vol_check ()

{
    # Check for errors prior to proceeding with report.

    pairvolchk -g ${dev_group[i]} -nomsg -${instance[i]} 

    if [ $? -eq 236 ]; then
        echo
        echo "Error - Unmatched volume status within the group."
        echo
        echo "Confirm status using the pairdisplay command. Make sure all volumes in the group"
        echo "have the same fence level and volume attributes."
        return 
    fi

    { echo "Type Group Volume Status"

      for vol in P-VOL S-VOL; do
          status=`pairvolchk -g ${dev_group[i]} -${instance[i]} | awk '{ print $7 }' | tr -d ']'`
          echo ${instance[i]:1:2} ${dev_group[i]} $vol $status
      done } | \

    ctrlBreak_report 1
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

choose_group ()

{
    group=""
    group_inst=""

    # Verify there are groups currently defined.

    if [ $n == 1 ]; then
        echo "No groups defined."
        return
    fi

    # Display list of groups (dev_group), with a numeric menu selection for each.

    echo
    echo "Device Groups:"
    echo

    prev_type=${instance[1]:1:2}                           # Pre-stage prior replication type.

    for (( i=1; i<n; i++ )); do
        if [ ${instance[i]:1:2} != $prev_type ]; then      # Separate SI and TC groups.
            prev_type=${instance[i]:1:2}                   # Record prior replication type.
            echo
        fi

        printf "  %2d. (%s) %s\n" $i ${instance[i]:1:2} ${dev_group[i]}
    done

    echo

    echo -n "[${array[$array_serial]}] group> "
    read selection

    (( i = $selection + 0 ))

    if [ $i -gt 0 ] && [ $i -lt $n ]; then
        group=${dev_group[i]}
        group_inst=${instance[i]}
    else
        echo "Invalid selection."
    fi
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

pair_display ()

{
    sn=$array_serial

    for (( i=1; i<n; i++ )); do
        if [ "$group" == ${dev_group[i]} ] && [ "$group_inst" == ${instance[i]} ] ; then
            pairdisplay -g ${dev_group[i]} -fcxe -CLI -${instance[i]} | sed 's/LU-M/LU M/g' | \
            ctrlBreak_report 2
            break
        fi
    done
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

pair_create ()

{
    printf "\nCreate new volume pairs from two unpaired volumes.\n"

    id=$(current_ctgid ${dev_group[i]} ${instance[i]})

    if [ ${#id} == 0 ] && [ ${instance[i]:0:3} == "ITC" ]; then
        id=$(next_ctgid)
    fi

    if [ $(pair_state) == "S-VOL" ]; then
        printf "\nPerforming this operation here will result in data loss by replicating data in the wrong direction."
        printf "\nPlease try again from the other array management console.\n"
        return
    fi

    if [ "${instance[i]:1:2}" == "TC" ] && [ $(pair_state) == "SMPL" ]; then
        echo
        read -p "Will the P-VOLs for this Group be located on this array? (y/n) " ans
        if [ $ans != "y" ]; then
            printf "Please try again from the other array management console.\n"
            return
        fi
        echo
    fi

    if [ "${instance[i]:1:2}" == "SI" ]; then
        printf "  # paircreate -g <group> [-d <pair Vol>] -vl [-c <size>] -ISI[#]\n\n"
        printf "Perform the operation for the entire group, or by individual pair.\n\n"
        printf "  # paircreate -g %s -vl -c 15 -%s\n\n" ${dev_group[i]} ${instance[i]}
    else
        printf "  # paircreate -g <group> [-d <pair Vol>] -vl [-c <size>] -fg never [CTGID] -ITC[#]\n\n"
        printf "Perform the operation for the entire group, or by individual pair.\n\n"
        printf "  # paircreate -g %s -vl -c 15 -fg never %s -%s\n\n" ${dev_group[i]} $id ${instance[i]}
    fi

    pairdisplay -g $group -CLI -${instance[i]} | awk -v inst="${instance[i]}" -v ctg="$id" -v n=0 '

        / L / { if ( substr(inst,2,2) == "SI")
                    printf("  # paircreate -g %s -d %s -vl -c 15 -%s\n", $1, $2, inst)
                else
                    printf("  # paircreate -g %s -d %s -vl -c 15 -fg never %s -%s\n", $1, $2, ctg, inst); }'
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

pair_create_split ()

{
    if [ "${instance[i]:1:2}" == "TC" ]; then
        printf "\nNot available for True Copy pairs.\n"
        return
    fi

    printf "\nCreate and split ShadowImage pairs simultaneously.\n"
    printf "  # paircreate -g <group> [-d <pair Vol>] -vl [-c <size>] [-split -fq quick] -ISI[#]\n\n"

    printf "Perform the operation for the entire group, or by individual pair.\n\n"
    printf "  # paircreate -g %s -vl -c 15 -split -fq quick -%s\n\n" ${dev_group[i]} ${instance[i]}

    pairdisplay -g $group -CLI -${instance[i]} | awk -v inst=${instance[i]} -v ctg=$id '

        / L / { if ( substr(inst,2,2) == "SI")
                    printf("  # paircreate -g %s -d %s -vl -c 15 -split -fq quick -%s\n", $1, $2, inst); }'
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

pair_split ()

{
    printf "\nSplit volume pairs. Allows R/W access to secondary volumes.\n"

    if [ "${instance[i]:1:2}" == "SI" ]; then
        printf "  # pairsplit -g <group> [-d <pair Vol>] -ISI[#]\n\n"
        printf "Perform the operation for the entire group, or by individual pair.\n\n"
        printf "  # pairsplit -g %s -%s\n\n" ${dev_group[i]} ${instance[i]} 
    else
        printf "  # pairsplit -g <group> [-d <pair Vol>] [-r | -rw] -ITC[#]\n\n"
        printf "Perform the operation for the entire group, or by individual pair.\n\n"
        printf "  # pairsplit -g %s -rw -%s\n\n" ${dev_group[i]} ${instance[i]} 
    fi

    pairdisplay -g $group -CLI -${instance[i]} | awk -v inst="${instance[i]}" -v ctg="$id" '

        / L / { if ( substr(inst,2,2) == "SI")
                    printf("  # pairsplit -g %s -d %s -%s\n", $1, $2, inst)
                else
                    printf("  # pairsplit -g %s -d %s -rw -%s\n", $1, $2, inst); 
        }'
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

pair_split_delete ()

{
    printf "\nDelete pairs. To re-establish, paircreate must be used.\n"

    if [ "${instance[i]:1:2}" == "SI" ]; then
        printf "  # pairsplit -g <group> [-d <pair Vol>] [-S] -ISI[#]\n\n"
    else
        printf "  # pairsplit -g <group> [-d <pair Vol>] [-r | -rw] [-S] -ITC[#]\n\n"
    fi

    printf "Perform the operation for the entire group, or by individual pair.\n\n"
    printf "  # pairsplit -g %s -S -%s\n\n" ${dev_group[i]} ${instance[i]}

    pairdisplay -g $group -CLI -${instance[i]} | awk -v inst=${instance[i]} -v ctg=$id '

        / L / { printf("  # pairsplit -g %s -d %s -S -%s\n", $1, $2, inst); }'
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

pair_resync ()

{
    printf "\nRe-establish pair volume, then restart updates to secondary volumes.\n"

    if [ "${instance[i]:1:2}" == "SI" ]; then
        printf "  # pairresync -g <group> [-d <pair Vol>] [-c <size>] -ISI[#]\n\n"
    else
        printf "  # pairresync -g <group> [-d <pair Vol>] [-c <size>] -ITC[#]\n\n"
    fi

    printf "Perform the operation for the entire group, or by individual pair.\n\n"
    printf "  # pairresync -g %s -c 15 -%s\n\n" ${dev_group[i]} ${instance[i]}

    pairdisplay -g $group -CLI -${instance[i]} | awk -v inst=${instance[i]} '

        / L / { printf("  # pairresync -g %s -d %s -c 15 -%s\n", $1, $2, inst); }'
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

pair_resync_restore ()

{
    printf "\nPerform reverse resync (from secondary to primary volumes).\n"

    if [ "${instance[i]:1:2}" == "SI" ]; then
        printf "  # pairresync -g <group> [-d <pair Vol>] [-c <size>] [-restore] [-fq quick] -ISI[#]\n\n"
        printf "Perform the operation for the entire group, or by individual pair.\n\n"
        printf "  # pairresync -g %s -c 15 -restore -fq quick -%s\n\n" ${dev_group[i]} ${instance[i]}
    else
        if [ $(pair_state) == "P-VOL" ]; then
            printf "  # pairresync -g <group> [-d <pair Vol>] [-c <size>] [-swapp] -ITC[#]\n\n"
            printf "Perform the operation for the entire group, or by individual pair.\n\n"
            printf "  # pairresync -g %s -c 15 -swapp -%s\n\n" ${dev_group[i]} ${instance[i]}
        else
            printf "  # pairresync -g <group> [-d <pair Vol>] [-c <size>] [-swaps] -ITC[#]\n\n"
            printf "Perform the operation for the entire group, or by individual pair.\n\n"
            printf "  # pairresync -g %s -c 15 -swaps -%s\n\n" ${dev_group[i]} ${instance[i]}
        fi
    fi

    pairdisplay -g $group -CLI -${instance[i]} | awk -v inst=${instance[i]} -v state=$(pair_state) '

        / L / { if (substr(inst,2,2) == "SI")
                    printf("  # pairresync -g %s -d %s -c 15 -restore -fq quick -%s\n", $1, $2, inst);
                else 
                    if (state == "P-VOL")
                       printf("  # pairresync -g %s -d %s -c 15 -swapp -%s\n", $1, $2, inst); 
                    else
                        printf("  # pairresync -g %s -d %s -c 15 -swaps -%s\n", $1, $2, inst); }'
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

horc_takeover ()

{
    if [ "${instance[i]:1:2}" == "SI" ]; then
        printf "\nNot available for Shadow Image pairs.\n"
        return
    fi

    if [ $(pair_state) == "P-VOL" ]; then
        printf "\nThis operation is not possible from this array."
        printf "\nPlease try again from the other array management console.\n"
        return
    fi

    printf "\nSwap update direction of primary and secondary volumes.\n"
    printf "  # horctakeover -g <group> [-d <pair Vol>] | -S | -l | -t <timeout> -ITC[#]\n\n"

    # Verify where the acting P-VOLs are currently located to provide the correct HORCM Instance.

    inst=`echo ${instance[i]} | sed 's/ITC//g'`
    local_vol=`pairdisplay -g ${dev_group[i]} -CLI -${instance[i]} | awk '
    
        BEGIN { getline; getline; print $9 }'`

    if [ "$local_vol" == "P-VOL" ]; then
        (( inst++ ))
    fi

    printf "  # horctakeover -g %s -t 300 -ITC$inst\n" ${dev_group[i]}

#    printf "Note: Execute from the management host where the new TrueCopy P-VOLs will be managed,\n"
#    printf "      ie., from the host where the HORCM instance shown in the command is running.\n"
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_header ()

{
    echo
    echo "  $array_serial - ${array[$array_serial]}"
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

preamble ()

{
    clear

    echo
    echo "This script is non-disruptive, ie. does not make changes to the current SAN environment."
    echo
    echo "It can be used to determine current HORCM pair status, and/or generate commands for future"
    echo "pair operations. These commands are commented to inhibit accidental, non-intended execution."
    echo "Command syntax is also provided, along with additional options, based on the replication"
    echo "type in use."
    echo 
    echo "For pair operations with new True Copy pairs configured but not yet established, the CTG ID"
    echo "(Consistency Group ID) is automatically generated, and is guaranteed to be unique from those"
    echo "currently in use."
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

display_menu ()

{
    echo
    echo "Main Menu:"
    echo
    echo "  pd = Pair Status (pairdisplay)    pvc = Group Status (pairvolchk)"
    echo 
    echo "  pc = Pair Create (paircreate)     pcs = Pair Create + Suspend (paircreate)"
    echo "  ps = Pair Suspend (pairsplit)     psd = Pair Delete (pairsplit)"
    echo "  pr = Pair Resync (pairresync)     prr = Reverse Pair Resync (pairresync)"
    echo
    echo "  ht = Reverse Pair Resync DR (horctakeover)"
    echo
    echo "   ? = Additional Info"
    echo "   q = quit"
    echo
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

additional_info ()

{
echo 
echo "Additional Info:"
echo
echo "  Pair Status (pd) ............. Display pair status of the volumes within a dev_group."
echo "  Group Status (pvc) ........... Display a status summary for the entire dev_group."
echo  
echo "  Pair Create (pc) ............. Create new volume pairs, start P-VOL -> S-VOL synchronization."
echo "  Pair Suspend (ps) ............ Split volume pairs, and allow R/W access to S-VOLs."
echo "  Pair Resync (pr) ............. Resync S-VOL with new P-VOL data, then restart P-VOL -> S-VOL."
echo
echo "  Pair Create + Suspend (pcs) .. Create and split pairs simultaneously. (SI only)"
echo "  Pair Delete (psd) ............ Delete pairs. A paircreate is required to restore paired state."
echo "  Reverse Pair Resync (prr) .... Perform reverse resync, ie. S-VOL -> P-VOL."
echo
echo "  Horcm Takeover (ht) .......... Split volume pairs, and sync in the opposite direction. (TC only)"
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

param_error ()
{
    echo "error: "$1"."
    echo
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

help_syntax ()
{
    echo "usage: $filename <serial_number> [ [status]|[<device_group>] ]"
    echo
    exit 1
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

# Start main program execution here.

if [[ ( $1 == "--help" ) || ( $# > 2 ) ]]; then         # Show usage if required.
    help_syntax
fi

if [ $# == 0 ]; then
    list_arrays
fi

array_serial=$1
array_validate $array_serial                     # Validate array S/N.
read_HORCM_config                                # Read HORCM config for selected array.

group_option $2                                  # Display group or all group status if requested.

preamble                                         # Display information regarding script use.

while [ "$ans" != "q" ]; do
    display_menu
    ans=""

    while [ "$ans" == "" ]; do
        echo -n "[${array[$array_serial]}] $program> "
        read ans
    done

    case "$ans" in
        pd|pvc|pc|ps|pr|pvc|pcs|psd|prr|ht ) 
              choose_group
              if [ "$group" == "" ]; then
                  continue
              fi;;&

        ht  ) horc_takeover;;

        pc  ) pair_create;;

        pcs ) pair_create_split;;

        pd  ) pair_display;;

        ps  ) pair_split;;

        psd ) pair_split_delete;;

        pr  ) pair_resync;;

        prr ) pair_resync_restore;;

        pvc ) pair_vol_check;;

        q   ) ;;

        \?  ) additional_info;;

        *   ) echo "Invalid option.";;

    esac
done

echo


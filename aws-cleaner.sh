#!/bin/bash
# 
# File:   aws-cleaner.sh
# Author: dolguin
#
# Created on 07/07/2014, 10:25:04
#

## \fn getAmiId
## This function return the id of the AMIs on the requested ASG
## \param $1 AUTO SCALING GROUP NAME (string)
## \return AMI-ID
function getAmiId {
#    echo aws ec2 describe-images --filters "Name=tag-value,Values=$DEPRECATED_TAG" |grep -i ImageId|tr -d "\""|tr -d "[:blank:]"|tr -d ',' |awk -F: '{print $2}'
    LC_NAME=$1
    echo $(aws autoscaling describe-launch-configurations --launch-configuration-names $LC_NAME | grep ImageId |awk '{print $2}'|tr -d '\"'|tr -d '\,' ;)
} 

## \fn getSnapshotId
## This function return the id of the Snatpshot related with the requested AMI
## \param $1 AMI ID (string)
## \return SNAPSHOT-ID
function getSnapshotId {
    AMI=$1
    echo $(aws ec2 describe-images --image-id $AMI |grep SnapshotId |awk '{print $2}'|tr -d '\"'|tr -d '\,')
}

## \fn getDeprecatedLC
## This function return a list of names of the launch configs that mach with the parameters 
## \param $1 AUTO SCALING GROUP NAME (string)
## \param $2 INSTANCE TYPE (string)
## \param $3 DATE MASK (string)
## \return LC-NAMES
function getDeprecatedLC {
    ASG_NAME=$1
    INSTANCE_TYPE=$2 #m[1-3].{medium,small,large}
    DEPRECATE_MASK=$3 #2014[0-1][1-9]
    echo $(aws autoscaling describe-launch-configurations |grep LaunchConfigurationName |egrep "$ASG_NAME-$INSTANCE_TYPE-$DEPRECATE_MASK"|awk  '{print $2}'|tr -d "\""|tr -d "\,")
}

## \fn getLC
## This function return a list of names of the launch configs related with the AGS name
## \param $1 AUTO SCALING GROUP NAME (string)
## \return LC-NAMES
function getLC {
    ASG_NAME=$1
    echo "$(aws autoscaling describe-launch-configurations |grep LaunchConfigurationName |grep $ASG_NAME|awk  '{print $2}'|tr -d "\""|tr -d "\,")"
}

## \fn deprecateLC
## This function delete the launch configs id requestet
## \param $1 LC-ID (string)
## \return Operation Status (Json)
function deprecateLC {
    LC_NAME=$1
    echo $(aws autoscaling delete-launch-configuration --launch-configuration-name $1)
}

## \fn checkAmiStatus
## This function check the STATUS tag of the requested AMI
## \param $1 AMI-ID (string)
## \return exit status (0 / 1) 
function checkAmiStatus {
    AMI=$1
    if [ -z $(aws ec2 describe-images --filters "Name=tag-value,Values=DEPRECATED"|grep ImageId  |awk '{print $2}'|tr -d '\"'|tr -d '\,'|grep $AMI|tr -d "[:blank:]") ]; then
        return 1;
    else
        return 0;  
    fi
}   


## \fn deregisterAmi
## This function deregister the AMI id provided by parameter
## \param $1 AMI-ID (string)
## \return Operation Status (Json)
function deregisterAmi {
    AMI=$1
    checkAmiStatus $AMI && echo $(aws ec2 deregister-image --image-id $AMI) || return 1;
}


## \fn usage
## This function delete the Snapshot id provided by parameter
## \param $1 SNAPSHOT-ID (string)
## \return Operation Status (Json)
function deleteSnapshot {
    SNAPSHOT=$1
    echo $(aws ec2 delete-snapshot --snapshot-id $SNAPSHOT;)
}

## \fn usage
## This fuction shows the Usage
## \param none
## \return none
function usage {
            echo ""
            echo "$0 Usage:"
            echo ""
            echo "Listing:"
            echo "********"
            echo "--list-lc ASG_NAME                List Launch Configs of selected Autoscaling Group"
            echo "--list-ami ASG_NAME               List AMI related with the selected Autoscaling Group"
            echo "--list-snapshots AMI_ID           Snapshot ID related to the selected AMI"
            echo "--deprecate-ami AMI_ID            Deregister the AMI"
            echo "--deprecate-lc LC_NAME            Deprecate the selected ASG"
            echo ""    
}

[[ -z $1 ]] && usage 

while [ $# -ge 1 ]
do
    case $1 in
        '--list-lc')
            shift 1
            ASG_NAME=$1
            for LC in $(getLC $ASG_NAME); do
                echo $LC;
            done
            shift $#
        ;;
        '--list-ami')
            shift 1
            ASG_NAME=$1
            for LC in $(getLC $ASG_NAME);do
                    echo $(getAmiId $LC)
                done
            shift $#
        ;;
        '--list-snapshots')
            shift 1
            AMI=$1
            echo $(getSnapshotId $AMI;)
            shift $#
        ;;
        '--deprecate-ami')
            shift 1
            AMI=$1
            SNAPSHOT=$(getSnapshotId $AMI)
            echo $(deregisterAmi $AMI;)
            echo $(deleteSnapshot $SNAPSHOT;)
            shift $#
        ;;
        '--deprecate-lc')
            shift 1
            LC=$1
            AMI_ID=$(getAmiId $LC)
            echo "AMI Id: $AMI_ID"
            SNAPSHOT_ID=$(getSnapshotId $AMI_ID)
            echo "Snapshot Id: $SNAPSHOT_ID"
            echo "-----------------------------------"
            #deprecate ami            
            echo "Removing AMI"
            echo $(deregisterAmi $AMI_ID;)
            #delete snapshot
            echo "Removing Snapshot"
            echo $(deleteSnapshot $SNAPSHOT_ID;)
            #remove launch config
            echo "Removing Lauch Config"
            echo $(deprecateLC $LC)
            shift $#
        ;;
        '--help'|'*')
            usage;
            shift $#;
        ;;
    esac
done


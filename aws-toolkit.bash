#!/bin/bash
##  AWS Toolkit
##  ===========
## 
##  This script is designed to made more easy all release tasks
##  on Amazon AWS with Autoscaling.
#  @autor: DAMIAN ANTONIO GITTO OLGUIN
##  @date: 2014-02-21 - in a rainy Day!!!
##  @file: aws-toolkit.bash
source config.ini; ##<Load the ini configuration file


## \fn createAmi

## This function build an AMI based on a Instance ID and then apply the ASG name + build date as AMI name and also add the description parameter as TAG.
## \param $1 InstanceID (string)
## \param $2 AUTO SCALING GROUP NAME (string)
## \param $3 : Description (string)
## \return AMI-ID
function createAmi {
    ORIGIN=$1; ##< ORIGIN contain the first parameter
    GROUPNAME=$2;##< GROUPNAME contain the second parameter
    DESCRIPTION=$3;##< DESCRIPTION contain the Third parameter
    AMI_ID=$(aws ec2 create-image --instance-id $ORIGIN --name $GROUPNAME-$DATE --description "$DESCRIPTION" |grep ImageId |awk '{print $2}'|tr -d "[:blank:]"|tr -d "\"");
    echo $AMI_ID;
}

## \fn createLC

## This function build a Launch Config
## \param $1 : Ami ID (string)
## \param $2 : Group Name (string)
## \param $3 : Instance Type (string)
## \return LAUNCHCONFIG
function createLC {
    AMIID=$1;
    LAUNCHCONFIG=$2-$3-$DATE;
    aws autoscaling create-launch-configuration --launch-configuration-name $LAUNCHCONFIG --image-id $AMIID --instance-type $INSTANCETYPE --key-name $SSHKEY --security-group $SECGROUP;
    echo $LAUNCHCONFIG;
}

## \fn updateSG

## This function make an update on Launch config parameter of the Scaling Group
## \param $1 : Auto Scaling Group Name (string)
## \param $2 : Launch Config Name (string)
function updateSG {
    ASGNAME=$1;
    LAUNCHCONFIG=$2;
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $ASGNAME --launch-configuration-name $LAUNCHCONFIG;
}

## \fn setDesiredCapacitySG

## This function Set the deisred capacity of the selected Scaling group
## \param $1 : Auto Scaling Group Name (string)
## \param $2 : Desired Capacty 
function setDesiredCapacitySG {
    ASGNAME=$1;
    DESIRED_CAPACITY=$2;
    echo aws autoscaling update-auto-scaling-group --auto-scaling-group-name $ASGNAME --desired-capacity $DESIRED_CAPACITY;
}

## \fn setMinCapacitySG

## This function Set the minumun capacity of the selected Scaling group
## @param $1 : Auto Scaling Group Name (string)
## @param $2 : Minimal Capacty (int)
function setMinCapacitySG {

    ASGNAME=$1;
    MIN_CAPACITY=$2;
    echo aws autoscaling update-auto-scaling-group --auto-scaling-group-name $ASGNAME --min-size $MIN_CAPACITY;
}

## \fn setMaxCapacitySG

## Set the maximun capacity of the ASG
## \param $1 : Auto Scaling Group Name (string)
## \param $2 : Max Capacty (int)
function setMaxCapacitySG {
    ASGNAME=$1;
    MAX_CAPACITY=$2;
    echo aws autoscaling update-auto-scaling-group --auto-scaling-group-name $ASGNAME --max-size $MAX_CAPACITY;
}


## \fn discoverInstances

## Discover Instances into ASG
## \param $1 : Auto Scaling Group Name (string)
## \return: Instances-ID (string)
function discoverInstances {
    ASGNAME=$1;
    INSTANCEIDS=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASGNAME|grep InstanceId|tr -d "\""|tr -d "," |tr -d "[:blank:]"|awk -F:  '{print $2}');
    echo $INSTANCEIDS;
}

## \fn discoverIP
 
## Discover IP of an InstanceID
## \param $1 : Instance ID (string)
## \return  Instances-IP (string)
function discoverIP {
    INSTANCEID=$1;
    INSTANCEIP=$(aws ec2 describe-instances --instance-ids $INSTANCEID |grep PrivateIpAddress|head -n1|tr -d '[:blank:]'|tr -d '"' |tr -d ','|awk -F: '{print$2}');
    echo $INSTANCEIP;
}

## \fn showIpASG

## Discover and list the InstanceID and IP address of the instances into the ASG
## \param $1 : Auto Scaling Group Name (string)
function showIpASG {
    if [ -n $1 ]; then
        ASG=$1;
        INSTANCES=$(discoverInstances $ASG);
        for I in $INSTANCES;
        do 
            echo $(discoverIP $I);
        done
    fi
}

## \fn terminateInstances

## This function destroy and terminate the instance related with de InstancesID of the first parameter and return the Json with the result.
## \param $1 : Instances ID (string)
## \return: Resulset (Json)
function terminateInstances {
    INSTANCES_ID=$1;
    for $INSTANCE_ID in INSTANCES_ID; 
    do
        echo "aws ec2 terminate-instances --instance-ids $INSTANCE_ID";
    done;
}

## \fn terminateInstances

## Destroy and terminate all instances into the ASG, return a json with the reulset.
## 
## \param $1 : Auto Scaling Group Name (string)
## \return: Resulset (Json)
function terminateInstancesSG {
    ASG=$1;
    INSTANCES_ID=$(discoverInstances $ASG);
    terminateInstances $INSTANCES_ID;
}

## \fn infoSG

## Describe the ASG
## \param $1 : Auto Scaling Group Name (string)
## \return: Resulset (Json)
function infoSG {
    ASG=$1;
    aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $ASG;
}

## \fn infoLC

## Describe the Launch Config
## \param $1 : Launch Config Name (string)
## \return: Resulset (Json)
function infoLC {
    LC=$1;
    aws autoscaling describe-launch-configurations --launch-configuration-names $LC;
}

## \fn tagging

## Build a tag and attachit to the resource id 
## \param $1 : resource (string)
## \param $2 : Tag-Key (string)
## \param $3 : Tag-Value (string)
## \return true / false
function tagging {
RESOURCE=$1;
KEY=$2;
VALUE=$3;
    RESULT=$(aws ec2 create-tags --resources $RESOURCE --tags "Key=$KEY,Value=$VALUE");
    RESULT=$(echo $RESULT|grep return|tr -d "[:blank:]"|tr -d "\"" |tr -d "{" |tr -d "}"|awk -F: '{print $2}');
    echo $RESULT;
}

## \rn deprecateAMI

## Syntax: deprecateAMI TAG_Name
## \param $1 : TAG Name Value (string)
## \return True / False
function deprecateAMI {
TAG=$1;
KEY="STATUS";
VALUE="DEPRECATED";
## for
for RESOURCE in $(aws ec2 describe-images --filters "Name=tag-value,Values=$TAG"|grep ImageId|awk '{print $2}'|tr -d '[:blank:]'|tr -d ","|tr -d "\"");
do
    echo "Deprecating $RESOURCE: "$(tagging $RESOURCE $KEY $VALUE);
done

}


usage() {
    echo "";
    echo "";    
    echo "";
    echo "Usage: $0 --help";
    echo "";
    echo "Return the Instances on the scaling group";
    echo "";
    echo "      $0 --discovery AutoScalingGroup";
    echo "";
    echo "Return the IP of the Instances on the scaling group \n";
    echo "";
    echo "      $0 --ip AutoScalingGroup";
    echo "";
    echo "Return the IP of the Instance\n";
    echo "";
    echo "      $0 --ip-instance Instance-ID";
    echo "";
    echo "Return the Instances of the EB environment\n";
    echo "";
    echo "      $0 --discover-eb ENVIRONMENT";
    echo "";
    echo "Return the IPs of the Instances into EB environment\n";
    echo "";
    echo "      $0 --ip-eb ENVIRONMENT";
    echo "";
    echo "Return the ELB of the EB environment\n";
    echo "";
    echo "      $0 --elb-eb ENVIRONMENT";
    echo "";   
    echo "Make a deployment on the scaling group selected using the fist instance on it\n";
    echo "";
    echo "      $0 --deploy AutoScalingGroup InstacneType Description";
    echo "";    
    echo "Set de selected Max / Min / Desired Capacity to the scaling group.\n";
    echo "";
    echo "      $0 --setCapacity AutoScalingGroup Max Min Desired";
    echo "";
    exit 1;
}

[[ -z $1 ]] && usage 


#MAIN
while [ $# -ge 1 ]
do
    case $1 in
        '--discover'|'--discovery')
            shift;
            if [ -n $1 ]; 
            then
                ASG=$1;
                echo "Instances on $ASG: "$(discoverInstances $ASG);
            fi
            shift $#;
        ;;
        '--instance-ip'|'--ip-instance')
            shift;
            if [ -n $1 ]
            then
                INSTANCE=$1;
                echo $(discoverIP $INSTANCE);
            fi
            shift $#;
        ;;
        '--ip'|'--ips')
            shift;
            ASG=$1;
                showIpASG $ASG;
            shift $#;
        ;;
        '--elb-eb'|'--eb-elb')
            echo "Not Implemented yet"
            shift $#;
        ;;
        '--ip-eb'|'--eb-ip')
            echo "Not Implemented yet"
            shift $#;
        ;;
        '--discover-eb'|'--eb-discover')
            echo "Not Implemented yet"
            shift $#;
        ;;
        '--elb')
            echo "Not Implemented yet"
            shift $#;
        ;;
        '--deploy')
            shift
            if [ -n $1 ]; then
                ASG=$1;
                INSTANCETYPE=$2
                DESCRIPTION=$3;
                #Descubro las instancias en el SG
                INSTANCES=$(discoverInstances $ASG|awk '{print $1}');
                echo "Instances into the Group: $INSTANCES";
                echo "Creating AMI using $INSTANCES";
                #creo la Ami usando solo la primera instancia en el ASG
                AMI_ID=$(createAmi "$INSTANCES" "$ASG" "$DESCRIPTION"); 
                #AMI_ID="ami-e532328c"
                echo "AMI Created: $AMI_ID";
                #creo el nuevo launch configu usando la ami creada
                LC_NAME=$(createLC $AMI_ID $ASG $INSTANCETYPE );
                echo "Launch Config Created: $LC_NAME";
                echo "================================";
                #muestro la info de nuevo Launch Config traida de amazon
                infoLC $LC_NAME;
                # actualizo el scaling group usando la LC nuevaq
                echo "Whaiting for 60 sec..."; 
                for I in $(seq 0 10); do
                    sleep 10;
                    echo "|..........";
                done
                updateSG $ASG $LC_NAME;
                echo "Auto Scaling Group $ASG Updated:";
                echo "================================";
                #muestro la info de como queda el Autoscaling group traida de amazon
                infoSG $ASG;
                #tagging resources 
                echo "Deprecating Old AMI: "$(deprecateAMI $ASG);
                echo "Tagging AMI Status: IN USE: "$(tagging $AMI_ID "STATUS" "IN USE");
                echo "Tagging AMI Name: $ASG - "$(tagging $AMI_ID "Name" $ASG); 
                echo "";
                echo "Instances ID / IP";
                echo "=======================================";
                showIpASG $ASG;
            fi
            shift $#;
        ;;
        '--setCapacity')
            shift;
            if [ -n $1 ]; then 
              ASG=$1;
              MAX=$2;
              MIN=$3;
              DES=$4;
              #Descubro las instancias en el SG
              $(setMaxCapacitySG $ASG $MAX);
              $(setMinCapacitySG $ASG $MIN);
              $(setDesiredCapacitySG $ASG $DES);
              echo "";
              echo "Instances into the Group: $(discoverInstances $ASG)";
              echo "";              
            fi
            shift $#;
        ;;
        '--help'|'*')
            usage;
            shift $#;
        ;;
    esac
done

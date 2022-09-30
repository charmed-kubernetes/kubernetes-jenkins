#!/bin/bash
set -x

function purge::controllers
{
    if [ "$1" != "jaas" ]; then
        echo "$1"
        if ! timeout 2m juju destroy-controller -y --destroy-all-models --destroy-storage "$1"; then
            timeout 5m juju kill-controller -t 2m0s -y "$1" 2>&1
        fi
    fi
}
export -f purge::controllers

juju controllers --format json | jq -r '.controllers | keys[]' | parallel --ungroup purge::controllers

# for i in $(juju controllers --format json | jq -r '.controllers | keys[]'); do
#     if [ "$i" != "jaas" ]; then
#         echo "$i"
#         if ! timeout 2m juju destroy-controller -y --destroy-all-models --destroy-storage "$i"; then
#             timeout 2m juju kill-controller -y "$i" 2>&1
#         fi
#     fi
# done

sudo apt clean
sudo rm -rf /var/log/*
docker image prune -a --filter until=24h --force
docker container prune --filter until=24h --force
rm -rf /var/lib/jenkins/venvs
rm -rf /var/lib/jenkins/.tox
tmpreaper -t 5h /tmp

regions=(us-east-1 us-east-2 us-west-1)

for region in ${regions[@]}; do
    aws --region "$region" ec2 describe-instances | jq '.Reservations[].Instances[] | select(contains({Tags: [{Key: "owner"} ]}) | not)' | jq -r '.InstanceId' | parallel aws --region "$region" ec2 terminate-instances --instance-ids {}
    aws --region "$region" ec2 describe-instances | jq '.Reservations[].Instances[] | select(contains({Tags: [{Key: "owner", Value: "k8sci"} ]}))' | jq -r '.InstanceId' | parallel aws --region "$region" ec2 terminate-instances --instance-ids {}
    aws --region "$region" ec2 describe-subnets --query 'Subnets[].SubnetId' --output json | jq -r '.[]' | parallel aws --region "$region" ec2 delete-tags --resources {} --tags Value=owned
    aws --region "$region" ec2 describe-security-groups --filters Name=owner-id,Values=018302341396 --query "SecurityGroups[*].{Name:GroupId}" --output json | jq -r '.[].Name' | parallel aws --region "$region" ec2 delete-security-group --group-id "{}"
done


if [[ $(aws iam list-roles --query "length(Roles[?RoleName == 'KubernetesAdmin'])") = *1* ]]
then
    aws iam delete-role --role-name KubernetesAdmin
fi

if [[ $(aws iam list-policies --query "length(Policies[?PolicyName == 'mk8s-ec2-policy'])") = *1* ]]
then
    POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName == 'mk8s-ec2-policy'] | [0].Arn" | tr -d '"')
    if [[ $(aws iam list-roles --query "length(Roles[?RoleName == 'mk8s-ec2-role'])") = *1* ]]
    then
        aws iam detach-role-policy --role-name mk8s-ec2-role --policy-arn $POLICY_ARN
    fi
    aws iam delete-policy --policy-arn $POLICY_ARN
fi

if [[ $(aws iam list-instance-profiles --query "length(InstanceProfiles[?InstanceProfileName == 'mk8s-ec2-iprof'])") = *1* ]]
then
    if [[ $(aws iam list-roles --query "length(Roles[?RoleName == 'mk8s-ec2-role'])") = *1* ]]
    then
        aws iam remove-role-from-instance-profile --instance-profile-name mk8s-ec2-iprof --role-name mk8s-ec2-role
    fi
    aws iam delete-instance-profile --instance-profile-name mk8s-ec2-iprof
fi

if [[ $(aws iam list-roles --query "length(Roles[?RoleName == 'mk8s-ec2-role'])") = *1* ]]
then
    aws iam delete-role --role-name mk8s-ec2-role
fi

if [[ $(aws efs describe-file-systems --query "length(FileSystems[?Name == 'mk8s-efs'])") = *1* ]]
then
    EFS_ID=$(aws efs describe-file-systems --query "FileSystems[?Name == 'mk8s-efs'] | [0].FileSystemId" --output text)
    if [[ $(aws efs describe-mount-targets --file-system-id $EFS_ID --query "length(MountTargets)") = *1* ]]
    then
        MT_ID=$(aws efs describe-mount-targets --file-system-id $EFS_ID --query "MountTargets | [0].MountTargetId" --output text)
        aws efs delete-mount-target --mount-target-id $MT_ID
    fi
    until aws efs delete-file-system --file-system-id $EFS_ID
    do
        if [[ $(aws efs describe-mount-targets --file-system-id $EFS_ID --query "length(MountTargets)") = *1* ]]
        then
            echo "Waiting 60s for mount target deletion before efs deletion..."
            sleep 60
        else
            break
        fi
    done
fi

if [[ $(aws ec2 describe-security-groups --query "length(SecurityGroups[?GroupName == 'mk8s-efs-sg'])") = *1* ]]
then
    aws ec2 delete-security-group --group-name mk8s-efs-sg
fi

# aws --region us-east-2 ec2 describe-instances | jq '.Reservations[].Instances[] | select(contains({Tags: [{Key: "owner"} ]}) | not)' | jq -r '.InstanceId' | parallel aws --region us-east-2 ec2 terminate-instances --instance-ids {}
# aws --region us-east-2 ec2 describe-security-groups --filters Name=owner-id,Values=018302341396 --query "SecurityGroups[*].{Name:GroupId}" --output json | jq -r '.[].Name' | parallel aws --region us-east-1 ec2 delete-security-group --group-id "{}"

sudo lxc list --format json | jq -r ".[] | .name" | parallel sudo lxc delete --force {}
for cntr in $(sudo lxc profile list --format json | jq -r ".[] | .name"); do
    if [[ $cntr != "default" ]]; then
	    echo "Removing $cntr"
	    sudo lxc profile delete "$cntr"
    fi
done

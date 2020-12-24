#!/usr/bin/python
#Author: Kicky
#Description: Fetch the ec2 details in a region and group them using different tags
#Get details like private ip address, key pair and the username to connect to the instance

import boto3
import json
import os
import yaml

##Examples:-
inventory_for = "infra"    # Can be one among ['app-dev', 'app-ops', 'infra']
opsworks_user = 'karthiksampath'
opsworks_user_private_key = 'kicky.pem'  # Place it in the ~/.ssh folder
tag_key = "opsworks:stack"
tag_value = ['fc-staging-es-conversation']


region = 'us-east-1'
output_file = "./inventory-{}".format(inventory_for)


def write_to_inventory(contents):
    with open(output_file, 'w') as filehandle:
        #filehandle.write("[{}]\n".format(inventory_for))
        filehandle.writelines("%s\n" % line for line in contents)  

def process_stuff(private_ip, key_name, image_user, name_tag):
    return "{}\tansible_user={}\tansible_ssh_private_key_file=~/.ssh/{}\tnode_name='{}'".format(private_ip,image_user,opsworks_user_private_key if opsworks_user_private_key else key_name,name_tag)


def filter_hosts(ec2, tag_key,tag_value):
    my_filter = {'Name':'tag:'+tag_key, 'Values':tag_value}
    all_instances = ec2.instances.filter(Filters=[my_filter])
    content_list = []
    for item in all_instances:
        private_ip = item.private_ip_address
        key_name = item.key_name+".pem" if item.key_name else "id_rsa"
        image_id = item.image_id
        image_user = get_image_user(ec2,image_id)
        for tag in item.tags:
            if tag['Key'] == 'Name':
                name_tag = tag['Value']

        content_to_write = process_stuff(private_ip, key_name, image_user, name_tag)
        content_list.append(content_to_write)
    return content_list


def get_image_user(ec2,image_id):
    if opsworks_user:
        return opsworks_user
    else:
        user = "ec2-user"
        image = ec2.Image(image_id)
        if "ubuntu" in image.image_location:
            user = "ubuntu"
        return user

def main():
    ec2 = boto3.resource("ec2", region)
    contents = filter_hosts(ec2, tag_key, tag_value)
    print(contents)
    write_to_inventory(contents)


# Main logic
main()


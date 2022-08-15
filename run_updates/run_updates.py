import boto3
import os
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

client = boto3.client('workspaces')
ssm = boto3.client('ssm')

def checkState(workspace_id):
    """
    Check what running state the workspace is in
    :return: Workspaces running state
    """
    workspace = client.describe_workspaces(
        WorkspaceIds=[
            workspace_id,
        ]
    )
    return workspace['Workspaces'][0]['State']
    
    
    
    
    
    
    

def startWorkspace(workspace_id):
    """
    starts a stopped workspace
    :return: Workspaces running state
    """
    client.start_workspaces(
        StartWorkspaceRequests=[
            {
                'WorkspaceId': workspace_id
            },
        ]
    )

    workspace = client.describe_workspaces(
        WorkspaceIds=[
            workspace_id,
        ]
    )
    
    return workspace['Workspaces'][0]['State']
    
    
    
    
    
    

def runUpdates():
    response = ssm.send_command(
    Targets=[
        {
            'Key': 'resource-groups:Name',
            'Values': [
                'Workspace-Bundle-Updates',
            ]
        },
    ],
    DocumentName='AWS-InstallWindowsUpdates',
    DocumentVersion="1",
    TimeoutSeconds=7200,
    MaxConcurrency="10",
    MaxErrors="1",
    Parameters={
        "Action":["Install"],
        "AllowReboot":["True"],
        "IncludeKbs":[""],
        "ExcludeKbs":[""],
        "Categories":["CriticalUpdates,DefinitionUpdates,Microsoft,SecurityUpdates"],
        "SeverityLevels":[""],
        "PublishedDaysOld":[""],
        "PublishedDateAfter":[""],
        "PublishedDateBefore":[""]},
    )
    

    return response['Command']['CommandId']




def checkRunCommand(command_id):
    print(command_id)
    response = ssm.list_command_invocations(
        CommandId=command_id
    )
    return response['CommandInvocations'][0]['Status']
    
    
    
    
    


def createImage(workspace_id):
    """
    Creates a snapshot of the current workspace.
    Sets a new name (current name + current date)
    :return: snapshot image id
    """
    dateObj = datetime.today()
    dateStr = str(dateObj.day) + str(dateObj.month) + str(dateObj.year)
    workspace = client.describe_workspaces(
        WorkspaceIds=[
            workspace_id,
        ]
    )

    bundle_id = workspace['Workspaces'][0]['BundleId']

    bundle = client.describe_workspace_bundles(
        BundleIds=[
            bundle_id,
        ]
    )

    bundle_name = bundle['Bundles'][0]['Name']
    new_name = bundle_name + "-" + dateStr

    result = client.create_workspace_image(
        Name= new_name,
        Description='Latest Updates',
        WorkspaceId= workspace_id,
    )
        
    return result['ImageId']
    
    
    
    
    
    
def updateBundle(image_id,workspace_id):
    """
    Updates the current bundle with the new snapshot on completion
    :return: bundle id
    """
    workspace = client.describe_workspaces(
        WorkspaceIds=[
            workspace_id,
        ],
    )
    
    response = client.update_workspace_bundle(
        BundleId=workspace['Workspaces'][0]['BundleId'],
        ImageId=image_id
    )
    
    return workspace['Workspaces'][0]['BundleId']
    
    
    
    
    
    
def checkImageState(image_id):
    """
    checks the snapshot state
    :return: snapshot state
    """
    response = client.describe_workspace_images(
        ImageIds=[
            image_id,
        ]
    )
    
    return response['Images'][0]['State']
    
    
    
    
    


def lambda_handler(event, context):

    # Get the workspace Id's provided by the step function
    workspace_ids = event['workspace_ids']

    # set the retry counter to 0
    counter = 0

    # if not first run
    if event.get('Results'):
        pending = event.get('Results').get('Pending', [])
        waiting = event.get('Results').get('Waiting',[])
        success = event.get('Results').get('Success', [])
        started = event.get('Results').get('Started', [])
        run_command = event.get('Results').get('RunCommand',[])
        bundle_updated = event.get('Results').get('BundleUpdated',[])
        cycleCount = event.get('Results').get('CycleCount', 0)
        
        # success has a two arguments (workspace id and image id) these should be added after the image snapshot has been triggered
        # the workspace id and image id are required to ensure we are updating the correct bundle with the new snapshot id
        if success:
            bundle_updated
            for image_name in success:
                logger.info(" - workspace/s updated successfully - finding snapshot_id")
                found = False
                for workspace_id in workspace_ids:
                    if(workspace_id.lower() == image_name.lower()):
                        logger.info(image_name + ": Found")
                        found = True
                        #check if the new image is in an available state
                        state = checkImageState(success[workspace_id])
                        if(state == 'AVAILABLE'):
                            if(success[workspace_id]):
                                # update the bundle and remove image id, workspace id from the success list.
                                # doing this will let the step function know there is nothing left to do with this workspace id and image id
                                logger.info(image_name + ": Updating Bundle")
                                bundle_id = updateBundle(success[workspace_id], workspace_id)
                                bundle_updated = workspace_id
                                logger.info(image_name + ": Successfully updated into bundle - " + bundle_id)
                            else:
                                logger.info(workspace_id + ": Starting")
                        else:
                            logger.info(image_name + ": Image creation Still in progress - Waiting for image to succeed before updating bundle.")
                    else:
                        if(found == False):
                            logger.info(image_name + ": Searching")
                
            to_remove = None
            for workspace_id in success:
                if workspace_id in bundle_updated:
                    logger.info("removing - + " + workspace_id + ". From list after bundle update")
                    to_remove = workspace_id
            if to_remove:
                success.pop(to_remove)
            bundle_updated = []
                
                
        
        # if there are workspace id's in a waiting state
        # a workspace is added to the waiting state when they are all started and the updates have started
        if waiting:
            for workspace_id in waiting:

                #check the state of the run command and workspace
                workspace_state = checkState(workspace_id)
                command_state = checkRunCommand(run_command[0])
                logger.info("Workspace State = " + workspace_state)
                logger.info("command state = " + command_state)

                # if the command is successful, continue
                if(command_state.lower() == 'Success'.lower()):

                    # if the workspace is stopped, restart the workspace
                    if(workspace_state != 'AVAILABLE'):
                        logger.info(workspace_id + " - starting workspace")
                        startWorkspace(workspace_id)
                        
                    # if the workspace is started, start the snapshot creation
                    elif(workspace_state == 'AVAILABLE'):
                        logger.info(workspace_id + " - creating snapshot")
                        new_image_id = createImage(workspace_id)
                        waiting.remove(workspace_id)
                        temp = {workspace_id : new_image_id}
                        success.update(temp)
                elif(command_state.lower() == 'Failed'):
                    logger.error(run_command + ": Failed")
            # if a workspace id is added to the waiting list, then the retry counter is set to 0 as there has been progress
            cycleCount = 0


        # if there are workspace id's in a pending state   
        # A workspace is added to the pending list on the initial loop from the state machine 
        if pending:
            for workspace_id in pending:
                # if the workspace isn't started, start the workspace
                status = checkState(workspace_id)
                if status == 'AVAILABLE':
                    logger.info("Wait for all workspaes to start before sending update command.")
                    if workspace_id not in started:
                        logger.info(workspace_id + ": Started")
                        started.append(workspace_id)
                else:
                    logger.info(workspace_id + ": Starting")

            # As we are using a resource group, we should wait until all workspaces are started before triggering the update
            if(len(workspace_ids) == len(started)):
                logger.info("All workspaces started....")
                logger.info("Updating workspaces")
                command_id = runUpdates()
                run_command.append(command_id)
                for workspace_id in workspace_ids:
                    started.remove(workspace_id)
                    waiting.append(workspace_id)
                    pending.remove(workspace_id)
            elif(workspace_id not in started):
                logger.info(workspace_id + ": Starting")
            elif(status == 'ERROR'):
                logger.error(workspace_id + ": In ERROR state. Cannot start.")
            # cycle count increments as the pending state has looped
            cycleCount += 1
            


    # if first run
    else:
        # initialize variables
        logger.info("Starting Image Update process.")
        pending        = []
        waiting        = []
        started        = []
        success        = {}
        bundle_updated = []
        run_command = []
        cycleCount = 0
        for workspace_id in workspace_ids:  

            # check if the workspace is stopped      
            status = checkState(workspace_id)
            if(status == "STOPPED"):

                # start the workspace and add it to the pending list
                startWorkspace(workspace_id)
                pending.append(workspace_id)
                counter += 1
            else:

                # if the workspace is already started, add the workspace to the pending list
                pending.append(workspace_id)
                
    if not success and not waiting and not pending and not bundle_updated:
        return 0
    else:
        # return the current values to the state machine for the next loop.
        logger.info("Returning pending updates.")
        return {
            "Pending" : pending,
            "Waiting" : waiting,
            "Success": success,
            "CycleCount": cycleCount,
            "Started" : started,
            "RunCommand" : run_command,
            "BundleUpdated" : bundle_updated,
        }

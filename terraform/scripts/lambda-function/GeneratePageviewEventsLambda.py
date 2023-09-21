"""
This code generates random pageview events and sends them to a Kinesis Data Stream named your-kinesis-stream-name. 
The generatePageview function creates a JSON-encoded pageview event with a random user ID, a target ID, a page type, 
a channel, and a timestamp. The lambda_handler function sends the events to the Kinesis Data Stream by calling the 
put_record method of the Kinesis client. The PartitionKey parameter is set to the user ID to ensure that events 
are evenly distributed across the shards of the stream.
"""

import json
import random
import time
import boto3
import math
import os

# CONFIG
userSeedCount = 10000
itemSeedCount = 1000
purchaseGenEveryMS = 100
pageviewMultiplier = 75  # Translates to 75x purchases, currently 750/sec or 65M/day
channels = ["organic search", "paid search", "referral", "social", "display"]
categories = ["widgets", "gadgets", "doodads", "clearance"]

# Initialize Kinesis client and stream name
kinesis = boto3.client('kinesis')
kinesis_stream_name = os.environ['data_stream_name']


def generatePageview(viewer_id, target_id, page_type):
    return {
        "user_id": viewer_id,
        "url": f"/{page_type}/{target_id}",
        "channel": random.choice(channels),
        "received_at": int(time.time()),
    }


def lambda_handler(event, context):
    # Write random page views to products or profiles
    pageviewOscillator = int(pageviewMultiplier + (math.sin(time.time() / 1000) * 50))
    for i in range(pageviewOscillator):
        rand_user = random.randint(0, userSeedCount)
        rand_page_type = random.choice(["products", "profiles"])
        target_id_max_range = (
            itemSeedCount if rand_page_type == "products" else userSeedCount
        )
        pageview_event = generatePageview(rand_user, random.randint(0, target_id_max_range), rand_page_type)
        # Send JSON-encoded event to Kinesis Data Stream
        kinesis.put_record(StreamName=kinesis_stream_name, Data=json.dumps(pageview_event), PartitionKey=str(rand_user))
        # Pause for a moment before sending the next event
        # time.sleep((purchaseGenEveryMS / 1000))
        time.sleep(2)

    return {
        'statusCode': 200,
        'body': json.dumps('Pageview events sent to Kinesis Data Stream')
    }

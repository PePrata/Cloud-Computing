"""
DR failover controller.

Triggered by an SNS notification from the "primary unhealthy" CloudWatch
alarm (which watches the Route 53 health check). Promotes the standby
RDS read replica in the DR region to a standalone read/write primary,
then flips an SSM parameter that the standby app host's docker-compose
render depends on for its "warm-standby -> active" behaviour.

This is intentionally the ONLY step that requires code: DNS failover
itself is handled natively by the Route 53 failover record + health
check, with no Lambda involvement. This function only takes care of
the one thing Route 53 can't do on its own: promoting the database.
"""
import os
import boto3

DR_REGION = os.environ["DR_REGION"]
REPLICA_INSTANCE_ID = os.environ["REPLICA_INSTANCE_ID"]
STATUS_PARAMETER_NAME = os.environ["STATUS_PARAMETER_NAME"]


def handler(event, context):
    rds = boto3.client("rds", region_name=DR_REGION)
    ssm = boto3.client("ssm", region_name=DR_REGION)

    describe = rds.describe_db_instances(DBInstanceIdentifier=REPLICA_INSTANCE_ID)
    instance = describe["DBInstances"][0]
    status = instance["DBInstanceStatus"]

    # Idempotency: an alarm can re-fire (flapping) before the previous
    # promotion has finished, or after it has already completed.
    if instance.get("ReadReplicaSourceDBInstanceIdentifier") is None:
        result = "already-promoted"
    elif status != "available":
        result = f"skipped-instance-status-{status}"
    else:
        rds.promote_read_replica(DBInstanceIdentifier=REPLICA_INSTANCE_ID)
        result = "promotion-started"

    ssm.put_parameter(
        Name=STATUS_PARAMETER_NAME,
        Value="active",
        Type="String",
        Overwrite=True,
    )

    return {"result": result, "replica": REPLICA_INSTANCE_ID}

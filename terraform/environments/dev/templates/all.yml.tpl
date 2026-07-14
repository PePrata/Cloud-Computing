---
aws_region: "${aws_region}"
image_tag: "latest"

db_host: "${db_host}"
db_name: "${db_name}"
ssm_parameter_prefix: "${ssm_parameter_prefix}"
# Primary is always the active/writable side — there is no promotion
# step for it, so this is a fixed value rather than an SSM lookup.
ssm_status_parameter: ""
db_role: "primary"

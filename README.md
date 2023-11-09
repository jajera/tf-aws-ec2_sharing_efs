# tf-aws-ec2_sharing_efs

Sample implementation of two ec2 instances on different availability zone sharing one EFS.


aws-vault exec dev -- terraform apply --auto-approve

aws-vault exec dev -- terraform destroy --auto-approve

#!/bin/bash
# scripts/post-deploy.sh

set -e

VPC_ID=$(terraform -chdir=terraform/envs/dev output -raw vpc_id)
ACCOUNT_ID=380847574744

echo ">>> Configuring kubectl..."
aws eks update-kubeconfig --name bjj-eks --region us-east-1

echo ">>> Creating LB Controller IAM policy..."
curl -sO https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json 2>/dev/null || echo "Policy already exists, skipping."

echo ">>> Attaching policy to role..."
aws iam attach-role-policy \
  --role-name bjj-lb-controller-role \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy 2>/dev/null || echo "Already attached."

echo ">>> Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=bjj-eks \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::${ACCOUNT_ID}:role/bjj-lb-controller-role \
  --set vpcId=${VPC_ID} \
  --set region=us-east-1

echo ">>> Applying aws-auth configmap..."
kubectl apply -f ../bjj-app/k8s/aws-auth.yaml

echo ">>> Creating IngressClass..."
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: ingress.k8s.aws/alb
EOF

echo ">>> Done. Run 'kubectl get pods -n kube-system | grep aws-load-balancer' to verify."
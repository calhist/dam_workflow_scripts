PROFILE    := default
ACCOUNT_ID := $(shell aws --profile ${PROFILE} configure get account_id)
REGION     := $(shell aws --profile ${PROFILE} configure get region)
KEY_ID     := $(shell aws --profile ${PROFILE} configure get aws_access_key_id)
SECRET_KEY := $(shell aws --profile ${PROFILE} configure get aws_secret_access_key)
TAG        := create-bag

setup:
	aws s3 cp ~/github.com/calhist/test/Squirrels s3://${ACCOUNT_ID}-artifacts/Squirrels --recursive

build:
	docker build -t ${TAG} .

test:
	docker run --rm -it \
		-e AWS_ACCESS_KEY_ID=${KEY_ID} \
		-e AWS_SECRET_ACCESS_KEY=${SECRET_KEY} \
		-e AWS_DEFAULT_REGION=${REGION} \
		create-bag -i s3://${ACCOUNT_ID}-artifacts/PC_006/PC_006_01.jpg

#	$(aws --profile default ecr get-login --no-include-email --region ${REGION})

push:
	docker tag create-bag:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${TAG}:latest
	docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${TAG}:latest

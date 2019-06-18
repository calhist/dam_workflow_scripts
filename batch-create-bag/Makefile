PROFILE    := ladd
ACCOUNT_ID := $(shell aws --profile ${PROFILE} configure get account_id)
REGION     := $(shell aws --profile ${PROFILE} configure get region)
KEY_ID     := $(shell aws --profile ${PROFILE} configure get aws_access_key_id)
SECRET_KEY := $(shell aws --profile ${PROFILE} configure get aws_secret_access_key)
TAG        := create-bag

COLLECTION := Squirrels
ASSET      := Squirrel.jpg

# COLLECTION := DAG-9G_01
# ASSET      := DAG-9G_01_recto.tif

setup:
	aws --profile ${PROFILE} s3 rm s3://${ACCOUNT_ID}-input/${COLLECTION}.MODS --recursive
	aws --profile ${PROFILE} s3 rm s3://${ACCOUNT_ID}-input/${COLLECTION} --recursive
#	aws --profile ${PROFILE} s3 cp ~/github.com/calhist/test/${COLLECTION}.MODS s3://${ACCOUNT_ID}-input/${COLLECTION}.MODS --recursive
	aws --profile ${PROFILE} s3 cp ~/github.com/calhist/test/${COLLECTION}      s3://${ACCOUNT_ID}-input/${COLLECTION}      --recursive

build:
	docker build -t ${TAG} .

test:
	docker run --rm -it \
		-e AWS_ACCESS_KEY_ID=${KEY_ID} \
		-e AWS_SECRET_ACCESS_KEY=${SECRET_KEY} \
		-e AWS_DEFAULT_REGION=${REGION} \
		create-bag -i s3://${ACCOUNT_ID}-input/${COLLECTION}/${ASSET}

login:
	@echo Logging in ...
	$$(aws --profile ${PROFILE} ecr get-login --no-include-email --region ${REGION})

push:
	docker tag create-bag:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${TAG}:latest
	docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${TAG}:latest

job:
	aws --profile ${PROFILE} batch submit-job \
		--job-name TEST \
		--job-queue batch \
		--job-definition batch-create-bag \
		--container-overrides command="-i","s3://${ACCOUNT_ID}-input/${COLLECTION}/${ASSET}"

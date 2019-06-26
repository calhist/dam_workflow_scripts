PROFILE    := ladd
ACCOUNT_ID := $(shell aws --profile ${PROFILE} configure get account_id)
REGION     := $(shell aws --profile ${PROFILE} configure get region)
KEY_ID     := $(shell aws --profile ${PROFILE} configure get aws_access_key_id)
SECRET_KEY := $(shell aws --profile ${PROFILE} configure get aws_secret_access_key)
TAG        := create-bag

CREATE := arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:lambda-create-bag
REMOVE := arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:lambda-remove-bag

PREFIX      := Squirrels
OBJECT      := Squirrel01.jpg
OBJECT_BASE := Squirrel01
OBJECT_EXT  := .jpg
MODS        := Squirrel01.xml

# COLLECTION := DAG-9G_01
# ASSET      := DAG-9G_01_recto.tif
# MODS       := DAG-9G_01_recto.xml

get-triggers:
	aws --profile ${PROFILE} s3api get-bucket-notification-configuration --bucket ${ACCOUNT_ID}-input

# FAILS SOMETIMES (??)
set-triggers:
	@echo '{'                                        > /tmp/json
	@echo '  "LambdaFunctionConfigurations": ['     >> /tmp/json
	@echo '    {'                                   >> /tmp/json
	@echo '      "Id": "create-trigger",'           >> /tmp/json
	@echo '      "LambdaFunctionArn": "${CREATE}",' >> /tmp/json
	@echo '      "Events": ["s3:ObjectCreated:*"]'  >> /tmp/json
	@echo '    },'                                  >> /tmp/json
	@echo '    {'                                   >> /tmp/json
	@echo '      "Id": "remove-trigger",'           >> /tmp/json
	@echo '      "LambdaFunctionArn": "${REMOVE}",' >> /tmp/json
	@echo '      "Events": ["s3:ObjectRemoved:*"]'  >> /tmp/json
	@echo '    }'                                   >> /tmp/json
	@echo '  ]'                                     >> /tmp/json
	@echo '}'                                       >> /tmp/json
	aws --profile ${PROFILE} s3api put-bucket-notification-configuration --bucket ${ACCOUNT_ID}-input \
		--notification-configuration file:///tmp/json

clean:
	aws --profile ${PROFILE} s3 rm s3://${ACCOUNT_ID}-output/${PREFIX}.bags --recursive
	aws --profile ${PROFILE} s3 rm s3://${ACCOUNT_ID}-input/${PREFIX} --recursive
	aws --profile ${PROFILE} s3 rm s3://${ACCOUNT_ID}-input/${PREFIX}.MODS --recursive

init:
	aws --profile ${PROFILE} s3 cp test/${PREFIX}      s3://${ACCOUNT_ID}-input/${PREFIX}      --recursive
	aws --profile ${PROFILE} s3 cp test/${PREFIX}.MODS s3://${ACCOUNT_ID}-input/${PREFIX}.MODS --recursive

init-mods:
	aws --profile ${PROFILE} s3 cp test/${PREFIX}.MODS s3://${ACCOUNT_ID}-input/${PREFIX}.MODS --recursive

build:
	docker build -f Dockerfile.create-bag -t ${TAG} .

run:
	docker run --rm -it \
		-e AWS_ACCESS_KEY_ID=${KEY_ID} \
		-e AWS_SECRET_ACCESS_KEY=${SECRET_KEY} \
		-e AWS_DEFAULT_REGION=${REGION} \
		create-bag -i s3://${ACCOUNT_ID}-input/${PREFIX}/${OBJECT}

test1: clean init build run # ASSET ONLY
	aws --profile ${PROFILE} s3 cp s3://${ACCOUNT_ID}-output/${PREFIX}.bags/${OBJECT_BASE}/manifest-md5.txt /tmp/manifest-md5.txt
	cat /tmp/manifest-md5.txt
	@egrep "${OBJECT}$$" test/Squirrels.bags/Squirrel01/manifest-md5.txt > /tmp/a
	@egrep "${OBJECT}$$" /tmp/manifest-md5.txt > /tmp/b
	@diff /tmp/a /tmp/b && echo "SUCCESS"

test2: clean init-mods build run # MODS ONLY
	aws --profile ${PROFILE} s3 cp s3://${ACCOUNT_ID}-output/${PREFIX}.bags/${OBJECT_BASE}/manifest-md5.txt /tmp/manifest-md5.txt
	cat /tmp/manifest-md5.txt
	@egrep "MODS.xml$$" test/Squirrels.bags/Squirrel01/manifest-md5.txt > /tmp/a
	@egrep "MODS.xml$$" /tmp/manifest-md5.txt > /tmp/b
	@diff /tmp/a /tmp/b && echo "SUCCESS"

test3: clean init init-mods build run # ASSET AND MODS
	aws --profile ${PROFILE} s3 cp s3://${ACCOUNT_ID}-output/${PREFIX}.bags/${OBJECT_BASE}/manifest-md5.txt /tmp/manifest-md5.txt
	cat /tmp/manifest-md5.txt
	@egrep "${OBJECT}$$" test/Squirrels.bags/Squirrel01/manifest-md5.txt > /tmp/a
	@egrep "${OBJECT}$$" /tmp/manifest-md5.txt > /tmp/b
	@diff /tmp/a /tmp/b && echo "SUCCESS"
	@egrep "MODS.xml$$" test/Squirrels.bags/Squirrel01/manifest-md5.txt > /tmp/a
	@egrep "MODS.xml$$" /tmp/manifest-md5.txt > /tmp/b
	@diff /tmp/a /tmp/b && echo "SUCCESS"
	@awk '{print $$2}' test/Squirrels.bags/Squirrel01/manifest-md5.txt > /tmp/a
	@awk '{print $$2}' /tmp/manifest-md5.txt > /tmp/b
	@diff /tmp/a /tmp/b && echo "SUCCESS"

test4: clean build run # SHOULD FAIL
	aws --profile ${PROFILE} s3 cp s3://${ACCOUNT_ID}-output/${PREFIX}.bags/${OBJECT_BASE}/manifest-md5.txt /tmp/manifest-md5.txt
	cat /tmp/manifest-md5.txt

test5: clean build # SHOULD FAIL
	docker run --rm -it \
		-e AWS_ACCESS_KEY_ID=${KEY_ID} \
		-e AWS_SECRET_ACCESS_KEY=${SECRET_KEY} \
		-e AWS_DEFAULT_REGION=${REGION} \
		create-bag -i s3://${ACCOUNT_ID}-input/${PREFIX}/FOO

login:
	@echo Logging in ...
	$$(aws --profile ${PROFILE} ecr get-login --no-include-email --region ${REGION})

push:
	docker tag create-bag:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${TAG}:latest
	docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${TAG}:latest

job1: clean init build push # ASSET ONLY
	aws --profile ${PROFILE} batch submit-job \
		--job-name TEST \
		--job-queue batch \
		--job-definition batch-create-bag \
		--container-overrides command="-i","s3://${ACCOUNT_ID}-input/${PREFIX}/${OBJECT}"

job2: clean init-mods build push # MODS ONLY
	aws --profile ${PROFILE} batch submit-job \
		--job-name TEST \
		--job-queue batch \
		--job-definition batch-create-bag \
		--container-overrides command="-i","s3://${ACCOUNT_ID}-input/${PREFIX}/${OBJECT}"

job3: clean init init-mods build push # ASSET AND MODS
	aws --profile ${PROFILE} batch submit-job \
		--job-name TEST \
		--job-queue batch \
		--job-definition batch-create-bag \
		--container-overrides command="-i","s3://${ACCOUNT_ID}-input/${PREFIX}/${OBJECT}"

job4: clean build push # SHOULD FAIL
	aws --profile ${PROFILE} batch submit-job \
		--job-name TEST \
		--job-queue batch \
		--job-definition batch-create-bag \
		--container-overrides command="-i","s3://${ACCOUNT_ID}-input/${PREFIX}/${OBJECT}"


PROJECT_ROOT = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

DOCKER_IMAGE ?= lambci/lambda-base-2:build
TARGET ?=/opt/imagemagick

MOUNTS = -v $(PROJECT_ROOT):/var/task \
	-v $(PROJECT_ROOT)imagemagick:$(TARGET)

DOCKER = docker run -it --rm -w=/var/task/build
build result:
	mkdir $@

clean:
	rm -rf build result

list-formats:
	$(DOCKER) $(MOUNTS) --entrypoint /opt/bin/convert -t $(DOCKER_IMAGE) -list format

bash:
	$(DOCKER) $(MOUNTS) --entrypoint /bin/bash -t $(DOCKER_IMAGE)

all libs:
	$(DOCKER) $(MOUNTS) --entrypoint /usr/bin/make -t $(DOCKER_IMAGE) TARGET_DIR=$(TARGET) -f ../Makefile_ImageMagick $@


STACK_NAME ?= lambda-layer-imagemagick
SAM_PIPELINE_ARTIFACTS_BUCKET ?= pco-sam-pipeline-artifacts

result/bin/identify: all

prep-binaries:
	# imagemagick has a ton of symlinks, and just using the source dir in the template
	# would cause all these to get packaged as individual files.
	# (https://github.com/aws/aws-cli/issues/2900)

	zip --symlinks -r $(PROJECT_ROOT)build/layer.zip imagemagick

build/output.yaml: template.yaml
	aws cloudformation package --template $< --s3-bucket $(SAM_PIPELINE_ARTIFACTS_BUCKET) --output-template-file $@ --region us-east-1

deploy: prep-binaries build/output.yaml
	aws cloudformation deploy --template build/output.yaml --stack-name $(STACK_NAME) --region us-east-1
	aws cloudformation describe-stacks --stack-name $(STACK_NAME) --query Stacks[].Outputs --output table --region us-east-1

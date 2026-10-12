REPO := localhost:5001/sbx-couch-committee
NAME := sbx-couch-committee
TAG  := $(REPO):$(shell date +%Y%m%d-%H%M%S)

.PHONY: registry deploy clean

# Start the local registry if it isn't already running
registry:
	docker start registry 2>/dev/null || \
	    docker run -d -p 5001:5000 --restart=always --name registry registry:2

deploy: registry
	docker build -t $(TAG) --push .
	sbx create --template $(TAG) --name $(NAME) claude ..

# Remove all locally cached copies of this image
clean:
	docker images $(REPO) --format "{{.Tag}}" | xargs -I{} docker rmi $(REPO):{}

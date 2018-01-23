GENERATED_KNOWN_HOSTS := \
    content/github_hosts \
    content/gitlab_hosts
KNOWN_HOSTS_FILES := \
    $(GENERATED_KNOWN_HOSTS) \
    content/nvidia_hosts

OHMYGIT_FILES := oh-my-git/prompt.sh \
                 oh-my-git/base.sh

GENERATED_FILES := $(GENERATED_KNOWN_HOSTS) content/known_hosts docker-stamp

# such as files that should never enter the repo
IGNORED_FILES := gid

IMAGE_NAME := $(shell basename `pwd`)

# Key dependency
DOCKER_DEPS := Dockerfile
# If makefile changes, then that means the way of building the image might have changed.
DOCKER_DEPS += Makefile
# Files copied into the image.
DOCKER_DEPS += $(shell grep "^COPY" Dockerfile | cut -d " " -f 2)
# oh-my-git is ADDed as a directory
DOCKER_DEPS += $(OHMYGIT_FILES)

# Command to build docker image - in a variable since we have two rules to do this building.
# (One is a phony rule so always will run, the other uses the stamp file.)
DOCKER_BUILD_CMD := docker build -t $(IMAGE_NAME) . && touch docker-stamp

# Default target
.PHONY: all
all: .gitignore docker

# Build the docker image unconditionally
.PHONY: docker
docker: $(DOCKER_DEPS)
	$(DOCKER_BUILD_CMD)

# Build the docker image only if we think it has changed
docker-stamp: $(DOCKER_DEPS)
	$(DOCKER_BUILD_CMD)

# Clean generated files
.PHONY: clean
clean:
	-rm -rf $(GENERATED_FILES)

# Run the docker image - can pass src=/some/path to change which path becomes /opt/android
# Will only re-build docker image if we think it's changed
ifeq ($(strip $(src)),)
DOCKER_RUN_ENV :=
else
DOCKER_RUN_ENV := AOSP_VOL_AOSP=$(strip $(src))
endif

.PHONY: run
run: docker-stamp
	-$(DOCKER_RUN_ENV) ./android.sh

# Update the gitignore based on the generated files list in this makefile.
.gitignore: Makefile
	@echo "Regenerating $@: Ignoring $(GENERATED_FILES) $(IGNORED_FILES)"
	@echo $(GENERATED_FILES) $(IGNORED_FILES) | tr " " '\n' > $@

# Combine all the known hosts files.
content/known_hosts: $(KNOWN_HOSTS_FILES)
	cat $^ > $@

# static pattern rule to generate the easy known hosts files.
# depends on Makefile since that's what can change to make the output change.
$(GENERATED_KNOWN_HOSTS): content/%_hosts: Makefile
	ssh-keyscan -t rsa,dsa,ecdsa,ed25519 $*.com > $@ 2>&1

# Help text
.PHONY: help
help:
	@echo ""
	@echo "Useful targets:"
	@echo ""
	@echo "all          default target, builds targets docker and .gitignore"
	@echo ""
	@echo "docker       does a docker build even if we don't think any dependencies have changed."
	@echo ""
	@echo "run          launches the docker image appropriately (using android.sh)."
	@echo "             Can pass src=/opt/android/some-other-dir to change the directory mapped to the source tree location"
	@echo ""
	@echo "clean        deletes generated files in this directory."
	@echo ""
	@echo ".gitignore   regenerates the .gitignore file based on the Makefile-generated files."
	@echo ""

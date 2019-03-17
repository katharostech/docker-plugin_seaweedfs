PLUGIN_NAME = kadimasolutions/seaweedfs-volume-plugin
PLUGIN_TAG ?= latest

all: clean rootfs create

clean:
	@echo "### rm ./plugin"
	@rm -rf ./plugin

config:
	@echo "### copy config.json to ./plugin/"
	@mkdir -p ./plugin
	@cp config.json ./plugin/

rootfs: config
	@echo "### docker build: rootfs image with"
	@docker build -t ${PLUGIN_NAME}:rootfs --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} .
	@echo "### create rootfs directory in ./plugin/rootfs"
	@mkdir -p ./plugin/rootfs
	@docker create --name tmp ${PLUGIN_NAME}:rootfs
	@docker export tmp | tar -x -C ./plugin/rootfs
	@docker rm -vf tmp

create:
	@echo "### remove existing plugin ${PLUGIN_NAME}:${PLUGIN_TAG} if exists"
	@docker plugin rm -f ${PLUGIN_NAME}:${PLUGIN_TAG} || true
	@echo "### create new plugin ${PLUGIN_NAME}:${PLUGIN_TAG} from ./plugin"
	@docker plugin create ${PLUGIN_NAME}:${PLUGIN_TAG} ./plugin

enable:
	@echo "### enable plugin ${PLUGIN_NAME}:${PLUGIN_TAG}"
	@docker plugin enable ${PLUGIN_NAME}:${PLUGIN_TAG}

disable:
	@echo "### disable plugin ${PLUGIN_NAME}:${PLUGIN_TAG}"
	@docker plugin disable ${PLUGIN_NAME}:${PLUGIN_TAG}

push:  clean rootfs create enable
	@echo "### push plugin ${PLUGIN_NAME}:${PLUGIN_TAG}"
	@docker plugin push ${PLUGIN_NAME}:${PLUGIN_TAG}

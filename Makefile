.PHONY=update
update:
	mv images/protobuf-exporter/Dockerfile images.protobuf-exporter.Dockerfile && \
	rm -rf images/protobuf-exporter && \
	rm -rf images/controller/lua images/controller/patches && \
	DIR=$$(mktemp -d) && \
	git clone -n --depth=1 --filter=tree:0 https://github.com/deckhouse/deckhouse "$$DIR" && \
	git -C "$$DIR" sparse-checkout set --no-cone modules/402-ingress-nginx/images && \
	git -C "$$DIR" checkout && \
	cp -r $$DIR/modules/402-ingress-nginx/images/controller-*/rootfs/etc/nginx/lua ./images/controller/ && \
	mkdir -p images/controller/patches && \
	cp $$DIR/modules/402-ingress-nginx/images/controller-*/patches/003-nginx-tmpl.patch ./images/controller/patches/nginx-tmpl.patch && \
	mkdir images/protobuf-exporter && \
	cp -r $$DIR/modules/402-ingress-nginx/images/protobuf-exporter/src/* ./images/protobuf-exporter/ && \
	cp -r $$DIR/modules/402-ingress-nginx/images/protobuf-exporter/rootfs ./images/protobuf-exporter/ && \
	rm -rf "$$DIR" && \
	git checkout images/protobuf-exporter/rootfs/var/files/telemetry_config.yml && \
	mv images.protobuf-exporter.Dockerfile images/protobuf-exporter/Dockerfile && \
	sed -i -e '3 s/1.23/1.24/' images/controller/Dockerfile

image:
	docker build . -t ghcr.io/tradaware/secure-cdn:local

run:
	docker run --rm -it ghcr.io/tradaware/secure-cdn:local

release:
	bin/release.sh

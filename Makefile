VERSION=0.0.0

PREFIX=${CURDIR}/_

all:compile test

compile:
	gprbuild -p -P fore
	gprbuild -p -P fore-main
	gprbuild -p -P fore-tests

test:


clean:
	rm -rf .obj bin lib _ *~ *.tgz
	

install:
	gprinstall -p -P fore --prefix=${PREFIX}
	gprinstall -p -P fore-main --prefix=${PREFIX}

arch:
	${MAKE} clean
	tar -czf fore-${VERSION}-src.tgz *
	

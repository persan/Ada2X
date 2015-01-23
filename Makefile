VERSION=0.0.0

PREFIX=${CURDIR}/_
PROJ=ada2x

all:compile test

compile:
	gprbuild -p -P ${PROJ}
	gprbuild -p -P ${PROJ}-main

test:


clean:
	rm -rf .obj bin lib _ *~ *.tgz
	

install:
	gprinstall -p -P ${PROJ} --prefix=${PREFIX}
	gprinstall -p -P ${PROJ}-main --prefix=${PREFIX}

arch:
	${MAKE} clean
	rm -rf .temp ; mkdir .temp
	tar "--exclude=.git .temp" -czf .temp/${PROJ}-${VERSION}-src.tgz .
	mv .temp/${PROJ}-${VERSION}-src.tgz .
	rm -rf .temp

gps:
	gps -P ${PROJ}-main &


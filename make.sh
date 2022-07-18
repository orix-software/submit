SDK_PATH="../orix-sdk"
PROGNAME="$(basename `pwd`)"

make clean

START_ADDR=0x0800 DEBUG=yes make
mv build/bin/${PROGNAME} build/bin/${PROGNAME}-0800

START_ADDR=0x0900 DEBUG=yes make
mv build/bin/${PROGNAME} build/bin/${PROGNAME}-0900

python3 ${SDK_PATH}/bin/relocbin.py3 -o build/bin/${PROGNAME} build/bin/${PROGNAME}-0800 build/bin/${PROGNAME}-0900


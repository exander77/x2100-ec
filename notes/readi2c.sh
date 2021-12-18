QBASEADDR=0x$(grep TPS65987D_smbus_query $(dirname $0)/usbc-charge-negotiation.dump | cut -d' ' -f1)
SMBUS_ID_ADDR=$(($QBASEADDR + 2))
I2CADDR_ADDR=$(($QBASEADDR))
REG_ADDR=$(($QBASEADDR + 8))
OPCODE_ADDR=$(($QBASEADDR + 9))

# set up the jump target
printf %08x $((0x$(grep TPS65987D_call $(dirname $0)/usbc-charge-negotiation.dump | cut -d' ' -f1) / 2)) | \
	sed -e 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/' | \
	xxd -r -p | dd of=/sys/kernel/debug/ec/ec0/ram bs=1 seek=$[0x10c00] 2>/dev/null

read_i2c() {
	SMBUS=$(printf %02x $1)
	I2C=$(printf %02x $2)
	REG=$(printf %02x $3)
	echo -n "$SMBUS/$I2C[$REG]: "
	
	# patch the i2c query table
	echo $SMBUS | xxd -r -p | dd of=/sys/kernel/debug/ec/ec0/ram bs=1 seek=$SMBUS_ID_ADDR 2>/dev/null
	echo $I2C | xxd -r -p | dd of=/sys/kernel/debug/ec/ec0/ram bs=1 seek=$I2CADDR_ADDR 2>/dev/null
	echo $REG | xxd -r -p | dd of=/sys/kernel/debug/ec/ec0/ram bs=1 seek=$REG_ADDR 2>/dev/null
	echo 80 | xxd -r -p | dd of=/sys/kernel/debug/ec/ec0/ram bs=1 seek=$OPCODE_ADDR 2>/dev/null
	
	# zero the i2c result buffer
	echo -en '\x00' | dd of=/sys/kernel/debug/ec/ec0/ram bs=1 seek=$((0x10b12)) 2>/dev/null
	
	echo -en '\x00' > /sys/kernel/debug/ec/ec0/xop # do the jump that we set up before
	
	# poll until the EC decides to do something useful for us...
	for i in `seq 1 30`; do
		V=$(dd if=/sys/kernel/debug/ec/ec0/ram bs=1 skip=$((0x00010b12)) count=1 2>/dev/null | xxd -p)
		if [ "$V" != "00" ]; then break; fi
		sleep 0.1
	done
	echo $V
	
	dd if=/sys/kernel/debug/ec/ec0/ram bs=1 skip=$((0x00010b02)) count=16 2>/dev/null | xxd -p
}

read_i2c $1 $2 $3

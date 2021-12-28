do_hot_patch() {
	addr=$1
	shift
	echo "echo $* | xxd -r -p | dd of=/sys/kernel/debug/ec/ec0/ram bs=1 seek=$[$addr+0x20000] 2>/dev/null"
}

cat $* | (while read a; do do_hot_patch $a; done)

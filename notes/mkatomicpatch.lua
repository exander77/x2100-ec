-- usage: binutils/bin/cr16-unknown-elf-objdump -wD fastcharge2.oo | lua mkpatch.lua
buf = ""
bufaddr = 0

outbytes = 0
outbuf = ""
function flush()
	if buf == "" then return end
	b0,b1,b2,b3 = string.format("%08x", bufaddr):match("(..)(..)(..)(..)")
	outbuf = outbuf .. string.format("%s%s%s%s %02x %s  ", b3, b2, b1, b0, buf:len() / 2, buf)
	outbytes = outbytes + 4 + 1 + (buf:len() // 2)
	buf = ""
end

while true do
	line = io.read("*line")
	if not line then break end
	addr,bytes = line:match("   2(....):[%s]+([^\t]+)")
	if addr then
		addr = tonumber("0x2"..addr)
		if addr ~= (bufaddr + buf:len() / 2) or (buf:len()/2 + bytes:len()/2) > 240 then
			flush()
			bufaddr = addr
			buf=""
		end
		bytes = bytes:gsub(" ","")
		buf = buf .. bytes
	end
end
flush()
outbuf = outbuf .. "00000000 00"
outbytes = outbytes + 4 + 1

print(outbuf)
print("")
print("echo '"..outbuf.."' | xxd -r -p | dd of=/sys/kernel/debug/ec/ec0/ram bs=1 seek=$[0x2e000] 2>/dev/null; echo -en '\\x01' > /sys/kernel/debug/ec/ec0/xop")
print("")
print("# ".. outbytes .." bytes emitted")
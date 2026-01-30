local bitBuffer = BitBuffer()

bitBuffer:WriteString("Hello world!")
bitBuffer:WriteInt(1234567890)
bitBuffer:WriteByte(254)
bitBuffer:WriteBit(1)

bitBuffer:SetCurBit(0)
local str = bitBuffer:ReadString(256)
local int = bitBuffer:ReadInt(32)
local byte = bitBuffer:ReadByte()
local bit = bitBuffer:ReadBit()
print(str, int, byte, bit)

bitBuffer:Delete()

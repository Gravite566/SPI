#!/usr/bin/env python3

# Using this module....
#  - Open a Device class with tty path/name and speed
#        a = computer_IF.Device("/dev/ttyUSBxxx")
#
# most accessible syntax :
#
#  to Write data: 
#    single write : a[addr]       = integer
#    map write    : a[start:]     = integer_list
#                   a[start:stop] = integer
#    FIFO write   : a[addr]       = integer_list
#                   a[addr:len:0] = integer
#
#  to read data:
#    single read  : a[addr]
#    map read     : a[start:stop]
#    FIFO read    : a[addr:len]


import spidev

ACK_Nothing_To_Say      = 0x00
ACK_Address_Error       = 0x20
ACK_Null_Size           = 0x30
ACK_Invalid_Instruction = 0x40
ACK_Short               = 0x60
ACK_Single              = 0x80 # Followed by 1 16bit value
ACK_Timeout             = 0xA0
ACK_Stream_Start        = 0xC0 # Followed by known number of values
ACK_Stream_End          = 0xE0 # Followed by 16 bit number of samples

MASK_Resp_Code     = 0xF0
MASK_Timeout       = 0x04
MASK_Address_Error = 0x02
MASK_Fifo_err      = 0x01

OPCODE_NOP          = 0x00
OPCODE_READ_IFVER   = 0x10
OPCODE_READ_PROJID  = 0x20
OPCODE_ERRCLR       = 0x30
OPCODE_READ_SINGLE  = 0x40
OPCODE_READ_MAP     = 0x50
OPCODE_READ_FIFO    = 0x60
OPCODE_WRITE_SINGLE = 0x80
OPCODE_WRITE_MAP    = 0x90
OPCODE_WRITE_FIFO   = 0xA0
OPCODE_PCKT_EXC     = 0xC0
OPCODE_PCKT_READ    = 0xD0
OPCODE_PCKT_WRITE   = 0xE0
OPCODE_INVALID      = 0xF0

#il faut modifier tout ce qui fait appel à serial et remplacer par la librairie spidev
class Resp_msg:
    def __init__(self, device, expected):
        self.device      = device
        self.dataok      = 0
        r = self.device.serial.read(1)[0]
        self.expected    = expected #code ACK attendu
        self.received    = r        #code ACK réellement reçu
        self.ok          = (r & MASK_Resp_Code) == expected #True or False en fonction de si on reçoit ce que l'on veut
        self.address_err = (r & MASK_Resp_Code) == ACK_Address_Error
        self.timeout_err = (r & MASK_Resp_Code) == ACK_Timeout
        self.nullsize    = (r & MASK_Resp_Code) == ACK_Null_Size
        self.invalid_err = (r & MASK_Resp_Code) == ACK_Invalid_Instruction
        self.FIFO_err    = ((r & MASK_Fifo_err) != 0)
        if (r & MASK_Resp_Code) == ACK_Single:
            d = self.device.spidev.read(2)
            self.data = d[0]*256+d[1]
        else:
            self.data = None
            
    def __repr__(self):
        s = "Response_" + hex(self.received) + "/" + hex(self.received) + ":" 
        if self.ok          : s+="k"
        if self.address_err : s+="@"
        if self.timeout_err : s+="T"
        if self.nullsize    : s+="0"
        if self.invalid_err : s+="!"
        if self.FIFO_err    : s+="F"
        s += ":" + str(self.data)
        return s
        
    
    def end_of_stream(self):
        resp = self.device.serial.read(3)
        r = resp[0]
        assert((r & MASK_Resp_Code) == ACK_Stream_End)
        self.address_err = ((r & MASK_Address_Error) != 0)
        self.timeout_err = ((r & MASK_Timeout)       != 0)
        self.FIFO_err    = ((r & MASK_Fifo_err)      != 0)
        self.dataok      = resp[1]*256+resp[2]
        
        
    def exception(self):
        if self.timeout_err:
            return TimeoutError
        if self.nullsize:
            return ValueError
        if self.address_err:
            return KeyError
        if self.invalid_err:
            return NotImplementedError
        return None
    
class Device: 
    def __init__(self, dev, speed=1000000):
        self.spidev = spidev.Spidev()
        
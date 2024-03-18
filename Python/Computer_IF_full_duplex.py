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


    
    
class Resp_msg:
    def __init__(self, device, expected):
        self.device      = device
        self.dataok      = 0
        r = self.device.serial.readbytes(1)[0]
        self.expected    = expected #code ACK attendu
        self.received    = r        #code ACK réellement reçu
        self.ok          = (r & MASK_Resp_Code) == expected #True or False en fonction de si on reçoit ce que l'on veu
        self.address_err = (r & MASK_Resp_Code) == ACK_Address_Error
        self.timeout_err = (r & MASK_Resp_Code) == ACK_Timeout
        self.nullsize    = (r & MASK_Resp_Code) == ACK_Null_Size
        self.invalid_err = (r & MASK_Resp_Code) == ACK_Invalid_Instruction
        self.FIFO_err    = ((r & MASK_Fifo_err) != 0)
        if (r & MASK_Resp_Code) == ACK_Single:
            d = self.device.serial.readbytes(2)[0]
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
        resp = self.device.serial.readbytes(3)[0]
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
    def __init__(self, dev, speed=921600):
        self.serial = spidev.SpiDev()
        self.serial.open(0,0)
        self.serial.max_speed_hz=speed
        self.serial.writebytes([OPCODE_READ_IFVER])
        self.IFver = Resp_msg(self, ACK_Single).data
        self.serial.writebytes([OPCODE_READ_PROJID])
        self.ProjID = Resp_msg(self, ACK_Single).data

    def _write_single(self, data, addr):
        self.serial.writebytes([OPCODE_WRITE_SINGLE, (addr//256)%256, addr%256, (data//256)%256, data%256])
        return Resp_msg(self, ACK_Short)
        
    def _read_single(self, addr):
        self.serial.writebytes([OPCODE_READ_SINGLE, (addr//256)%256, addr%256])
        return Resp_msg(self, ACK_Single)

    def _read_map(self, addr, length):
        self.serial.writebytes([OPCODE_READ_MAP, (addr//256)%256, addr%256, (length//256)%256, length%256])
        r=Resp_msg(self,ACK_Stream_Start)
        if r.ok:
            dat = self.serial.readbytes(length*2)
            resp_data = [dat[i]*256+dat[i+1] for i in range(0, length*2, 2)]
            r.end_of_stream()
            resp_data = resp_data[:r.dataok]
            return resp_data
        return []

    def _read_FIFO(self, addr, length):
        self.serial.writebytes([OPCODE_READ_FIFO, (addr//256)%256, addr%256, (length//256)%256, length%256]) 
        r = Resp_msg(self, ACK_Stream_Start)
        if r.ok:
            dat = self.serial.readbytes(length*2)
            resp_data = [dat[i]*256+dat[i+1] for i in range(0, length*2, 2)]
            r.end_of_stream()
            resp_data = resp_data[:r.dataok]
            return resp_data
        return []

    def _write_map(self, addr, data): 
        length = len(data)
        self.serial.writebytes([OPCODE_WRITE_MAP, (addr//256)%256, addr%256, (length//256)%256, length%256, (data[0]//256)%256, data[0]%256])
        r = Resp_msg(self, ACK_Short)
        if r.ok:
            dat = [i.to_bytes(2, byteorder='big') for i in data[1:]]
            self.serial.writebytes([b''.join(dat)])
            r.end_of_stream()
        return r

    def _write_FIFO(self, addr, data):
        length = len(data)
        self.serial.writebytes([OPCODE_WRITE_FIFO, (addr//256)%256, addr%256, (length//256)%256, length%256, (data[0]//256)%256, data[0]%256])
        r = Resp_msg(self, ACK_Short)
        if r.ok:
            dat = [i.to_bytes(2, byteorder='big') for i in data[1:]]
            self.serial.writebytes([b''.join(dat)])
            r.end_of_stream()
        return r

    def _nop(self):
        self.serial.writebytes([OPCODE_NOP])
        return Resp_msg(self, ACK_Short)

    def __getitem__(self, addr):
        if isinstance(addr, slice):
            if addr.start is None :
                 raise Exception("Need the base address for read operation")
            if addr.step is None or addr.step == 1:
                if addr.stop is None:
                    raise Exception("Need a stop address (None provided)")
                return self._read_map(addr.start, addr.stop - addr.start)
            elif addr.step == 0:
                if addr.stop is None:
                    raise Exception("Need a number of elements as stop address (None provided)")
                return self._read_FIFO(addr.start, addr.stop)
            else:
                #collection of single read
                raise Exception("step values other than 0 or 1 not supported yet")
        r = self._read_single(addr)
        if r.ok:
            return r.data
        return r.exception()

    def __setitem__(self, addr, data):
        if isinstance(addr, slice):
            if addr.start is None:
                raise Exception("Need the base address for read operation")
            if isinstance(data, int):
                if addr.step is None or addr.step == 1:
                    if addr.stop is None:
                        raise Exception("Need a stop address in this context")
                    r = self._write_map(addr.start, [data]*(addr.stop - addr.start))
                    return
                elif addr.step == 0:
                    r = self._write_FIFO(addr.start, [data]*addr.stop)
                    return
            if not isinstance(data, list):
                raise TypeError
            if addr.step is None or addr.step == 1:
                if addr.stop is None or addr.stop == addr.start + len(data):
                    r = self._write_map(addr.start, data)
                    if r.ok:
                        return
                    raise r.exception()
                else:
                    raise Exception("Inconsistent data size and addresses")
            elif addr.step == 0:
                if not addr.stop is None and addr.stop != len(data):
                    raise Exception("Inconsistent data size and access len")
                r = self._write_FIFO(addr.start, data)
                if r.ok:
                    return
            else:
                raise Exception("step values other than 0 or 1 not supported yet")
                
        if isinstance(data, list):
            return self._write_FIFO(addr, data)

        return self._write_single(data, addr).exception()


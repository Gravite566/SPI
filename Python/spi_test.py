#!/usr/bin/python

from spi_only import*
import spidev
import serial
import sys


if len(sys.argv)==1:
    print(sys.argv)
    raise Exception("CACA")

# Open SPI bus
computer = Device(dev=None,speed=1000000)
valTX = int(sys.argv[1], base=16)
#computer.spi.writebytes([valTX])
#print(computer.spi.readbytes(1))
 
print([hex(i) for i in computer.spi.xfer([valTX])]) 
 
# End of script
print("End of script")


    

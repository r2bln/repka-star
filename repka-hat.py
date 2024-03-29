import os
import sys
import RepkaPi.GPIO as GPIO

cmd = sys.argv[1]

GPIO.setboard(GPIO.REPKAPI3)
print(GPIO.getboardmodel())
GPIO.setmode(GPIO.BCM)
GPIO.setup(20, GPIO.OUT)
GPIO.setup(21, GPIO.OUT)

if cmd == 'enter':
    print('enter bootloader mode')
    GPIO.output(20, 1)
    GPIO.output(21, -1)
    GPIO.output(21, 1)
elif cmd == 'exit':
    print('exit bootloader mode')
    GPIO.output(20, -1)
    GPIO.output(21, 1)
elif cmd == 'flash':
    os.system("rm -rf *.bin")
    os.system("wget https://github.com/juribeparada/MMDVM_HS/releases/download/v1.5.2/mmdvm_hs_hat_fw.bin")
    print('enter bootloader mode')
    GPIO.output(20, 1)
    GPIO.output(21, -1)
    GPIO.output(21, 1)
    os.system("stm32flash /dev/ttyS0")
    os.system("stm32flash -v -w mmdvm_hs_hat_fw.bin -g 0x0 /dev/ttyS0")
    print('exit bootloader mode')
    GPIO.output(20, -1)
    GPIO.output(21, 1)

GPIO.cleanup()
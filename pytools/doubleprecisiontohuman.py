import struct
import sys

def hex_to_double(hex_str):
    # Convert the hex string to an integer
    int_val = int(hex_str, 16)
    
    # Pack the integer as a binary string
    packed = struct.pack('>Q', int_val)
    
    # Unpack as a double (float)
    double_val = struct.unpack('>d', packed)[0]
    
    return double_val

## ozzy@ozzy-Inspiron-7537:~$ python3 ./doubleprecisiontohuman.py 40368F9F8DC00000
# The decimal representation is: 22.561028346419334


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python hex_to_double.py <hex_string>")
        sys.exit(1)
    
    hex_str = sys.argv[1]
    try:
        result = hex_to_double(hex_str)
        print(f"The decimal representation is: {result}")
    except ValueError:
        print("Invalid hexadecimal input.")
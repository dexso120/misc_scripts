import argparse
import sys

def main():

	parser = argparse.ArgumentParser()
	parser.add_argument('-f','--file', help='File to decrypt', required=True)
	args = parser.parse_args()

	outfile = "decrypted.bin"
	key = b'\xab'
	new_content = b''

	with open(args.file, "rb") as f:
		while (byte := f.read(1)):
			byte = bytes(a ^ b for a, b in zip(byte, key))
			new_content += byte

	with open(outfile, "wb") as o:
		o.write(bytes(new_content))



if __name__ == "__main__":
	main()
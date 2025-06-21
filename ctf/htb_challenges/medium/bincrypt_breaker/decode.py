import argparse
import sys

# Flag to decode
# RV{r15]_vcP3o]L_tazmfSTaa3s0

def transform1(list_text, num_byte):
	# Reversed array1
	array1 = [1, 9, 2, 7, 4, 0, 6, 10, 8, 12, 3, 11, 5, 13]
	array2 = [2, 4, 6, 8, 11, 13]
	
	# XOR with num_byte
	for i in array2:
		list_text[i] = bytes(a ^ b for a, b in zip(list_text[i].encode("utf-8"), num_byte)).decode("utf-8")

	# Reverse Transposition
	temp_text = [''] * len(array1)
	for i in range(len(array1)):
		temp_text[array1[i]] = list_text[i]

	print(f"After transform1: {temp_text}")

	return temp_text

def transform2(list_text):
	list_text[0], list_text[12] = list_text[12], list_text[0]
	list_text[14], list_text[26] = list_text[26], list_text[14]
	list_text[4], list_text[8] = list_text[8], list_text[4]
	list_text[20], list_text[23] = list_text[23], list_text[20]

	print(f"After transform2: {list_text}")

	return list_text

def main():

	parser = argparse.ArgumentParser()
	parser.add_argument('-s','--string', help='String to decode', required=True)
	args = parser.parse_args()

	# String: RV{r15]_vcP3o]L_tazmfSTaa3s0

	if (len(args.string) != 28):
		print("[-] String is not 28 in length.")
		sys.exit(1)

	# Split string
	string_first_half = list(args.string[:14])
	string_second_half = list(args.string[14:])

	# Perform XOR and transposition
	string_first_half = transform1(string_first_half, b"\x02")
	string_second_half = transform1(string_second_half, b"\x03")

	full_string = string_first_half + string_second_half

	full_string = transform2(full_string)

	print(f"Flag: {''.join(full_string)}")


if __name__ == "__main__":
	main()
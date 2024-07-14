little_endian = input("Enter hex value in little endian: ")

length = len(little_endian)

if(length % 2 > 0):
	print("Patching value with preceding 0")
	little_endian = '0' + little_endian
	length = len(little_endian)

big_endian = ''

for i in range(length - 1, 0, -2):
	big_endian += little_endian[i-1]
	big_endian += little_endian[i]

print("Big Endian hex value: " + big_endian)
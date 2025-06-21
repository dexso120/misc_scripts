a = "abcdefghijklmnopqrstuvwxyz12"

string_array = list(a[:14])
temp_array = [0] * 14
array1 = [9, 12, 2, 10, 4, 1, 6, 3, 8, 5, 7, 11, 0, 13]

for i in range(1, 9):
	for j in range(14):
		temp_array[j] = string_array[array1[j]]

	string_array = temp_array
	temp_array = [0] * 14

print(f"Transformed String: {''.join(string_array)}")

temp_array_2 = []

for i in string_array:
	temp_array_2.append(a.index(i))

print(f"Transform array: {temp_array_2}")
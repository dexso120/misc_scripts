#!/usr/bin/python3
import os
import subprocess
import argparse
import textwrap

# Service priority for sorting
# Based on my personal usage
set_priority_1 = {"ftp", "nfs", "smb"}
set_priority_2 = {"http", "http_proxy"}

def nmap_output_to_list(list):
	finalList = []
	ports = []
	for line in list:
		if line == '':
			break
		s = line.split()
		s[0] = s[0].split("/")[0]
		finalList.append(s)
		if(s[0] != "PORT"):
			ports.append(s[0])

	finalList.pop(0)
	return finalList, ports

def nmap_quick_scan(args):
	# Running quick nmap scan
	try:
		print("Nmap Quick scan on " + args.target + " ...")
		output = subprocess.check_output(['nmap', args.target, '-Pn', '-p-'])
	except subprocess.CalledProcessError as err:
		print(err)

	output = output.decode("utf-8").split('\n')

	# print(type(output))

	# Simplifying nmap result
	for s in list(output):
		if s.find('STATE SERVICE') < 0:
			output.pop(0)
		else:
			break
	# Quick scan output into file
	write_output("IP: " + args.target + "\n--- Nmap Quick Scan ---\n",args.output, "w")
	
	for line in output:
		if line == '':
			break
		write_output(line, args.output, "a")

	return output

def nmap_port_scan(port, args):
	try:
		print("Nmap Full Scan on port " + port + " ...")
		nmap_port_scan_output = subprocess.check_output(['nmap', args.target, '-Pn', '-A', '-p ' + port])
	except subprocess.CalledProcessError as err:
		print(err)

	nmap_port_scan_output = nmap_port_scan_output.decode("utf-8").split('\n')

	# Removing header and footer in nmap output
	for s in list(nmap_port_scan_output):
		if s.find('STATE SERVICE') < 0:
			nmap_port_scan_output.pop(0)
		else:
			break
	nmap_port_scan_output.pop(0)
	nmap_port_scan_output.pop(len(nmap_port_scan_output)-1)

	length = len(nmap_port_scan_output)-1

	for s in reversed(list(nmap_port_scan_output)):
		if s != '':
			nmap_port_scan_output.pop(length)
			length -= 1
		else:
			break

	write_output(list_to_string(nmap_port_scan_output), args.output, "a")

def write_output(output, filename, mode):
	f = open(filename, mode)
	f.write(output + "\n")
	f.close()

def service_condition(element):
	set_a = {element[2]}
	if (not set_a.isdisjoint(set_priority_1)):
		return 1
	elif (not set_a.isdisjoint(set_priority_2)):
		return 2
	else:
		return 999

def list_to_string(output_list):
	finalString = ""
	for line in output_list:
		finalString = "\n".join([finalString,str(line)])
	return finalString

def main():
	# Parsing Arguments
	parser = argparse.ArgumentParser()
	parser.add_argument('-t', '--target', help='Specify target to scan', required=True)
	parser.add_argument('-o', '--output', help='Output filename', required=True)
	args = parser.parse_args()

	output = nmap_quick_scan(args)

	write_output("\n\n---Nmap Full Scan---", args.output, "a")

	output,ports = nmap_output_to_list(output)
	output.sort(key=service_condition)
	for port in output:
		nmap_port_scan(port[0], args)

	print("All scans completed")

if __name__ == '__main__':
	main()
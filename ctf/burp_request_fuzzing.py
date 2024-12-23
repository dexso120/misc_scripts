import requests, argparse, base64
import xml.etree.ElementTree as ET

def convert_file_to_request(file_path, wordlist_path, keyword):
    file = open(file_path, "r")
#    print(file.read())
    tree = ET.parse(file_path)
    root = tree.getroot()

    # Get base64 request content and decode
    for request_item in root.iter('request'):
        #print(request_item.text)
        request_parsed = base64.b64decode(request_item.text)

    # Get all header attribute and put in array
    header_content = []
    request_body = []
    header = True
    for line in request_parsed.splitlines():
        if line == b'':
            header = False
        if header:
            header_content.append(line.decode('utf-8'))
        else:
            request_body.append(line.decode('utf-8'))

    # Craft http request header
    header_attribute = {}
    for item in header_content:
        if ":" in item:
            header_attribute[item.split(":")[0]] = item.split(":")[1].strip()
    path = "http://" + header_attribute['Host'] + header_content[0].split(" ")[1]

    # Craft request body
    body_content = ""
    for item in request_body:
        body_content += item + "\r\n"
    #print(body_content)

    # Fuzzing based on wordlist
    print("[+] Fuzzing...")

    wordlist = open(wordlist_path, "r")
    for word in wordlist:
        body_new = body_content.replace('FUZZ', word)
        r = requests.post(path, data = body_new, headers = header_attribute)
        if (keyword in r.text):
            print(f"Successful request with word: {word}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--file', help='Specify burp request file.', required=True)
    parser.add_argument('-w', '--wordlist', help="Specify wordlist", required=True)
    parser.add_argument('-k', '--keyword', help="Keyword for successful request", required=True)
    args = parser.parse_args()
    convert_file_to_request(args.file, args.wordlist, args.keyword)

if __name__ == '__main__':
    main()

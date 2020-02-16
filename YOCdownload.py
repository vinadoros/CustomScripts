#!/usr/bin/env python3
"""Download files from OCRemix"""

# Python includes.
import argparse
from html.parser import HTMLParser
import itertools
import urllib.request
import urllib.parse
import os
from multiprocessing import Pool
# pip3 install --user python-magic
# python-magic library: https://github.com/ahupp/python-magic
import magic

# Variables.
BASEOCURL = "http://ocremix.org/remix/OCR0"

# Get arguments
parser = argparse.ArgumentParser(description='Download a numeric range of mixes from ocremix.org.')
parser.add_argument('ocstart', type=int, help='the starting oc-remix number')
parser.add_argument('ocend', type=int, help='the ending oc-remix number')
parser.add_argument("-f", "--forcemirror", help='Force mirror number.', type=int, default=0)

# Save arguments.
args = parser.parse_args()
ocstart = args.ocstart
ocend = args.ocend
print("Start OCMix: " + format(ocstart) + ", End: " + format(ocend) + ", Total: " + format(ocend - ocstart + 1) + ", Downloading to " + os.getcwd())
print("Forced Mirror: {0}".format(args.forcemirror))
input("Press Enter to continue.")

### Global Variables ###
m = magic.open(magic.MAGIC_NONE)
m.load()

### Functions ###
# Parser documentation: https://docs.python.org/3/library/html.parser.html
# More info: http://stackoverflow.com/a/822341
class ImgSrcHTMLParser(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self)
        self.srcs = []

    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            self.srcs.append(dict(attrs).get('href'))


def ocremix_geturls(mixnumber, force_modulus: int = 0):
    """Store the OCRemix urls, number of mirrors, and modulus."""
    # global ocmp3_urls, ocmirror_number, ocmirror_modulus
    global threadnumber
    print("Processing URL for mix " + format(mixnumber))
    # Connect to a URL
    website = urllib.request.urlopen(BASEOCURL + str(mixnumber))
    # Read html code
    html = website.read()

    # Make empty array to store URLs.
    ocmp3_urls = []
    # Parse the html (see above stackoverflow answer for more info)
    parser = ImgSrcHTMLParser()
    parser.feed(str(html))
    for src in parser.srcs:
        if str(src).endswith('.mp3'):
            # Save the url to an array.
            ocmp3_urls.append(src)

    # Save length of array to variable.
    ocmirror_number = len(ocmp3_urls)
    # Save to thread number for threadcount.
    threadnumber = len(ocmp3_urls)
    if force_modulus == 0 or force_modulus > threadnumber:
        ocmirror_modulus = mixnumber % ocmirror_number
    else:
        # If forced, set the modulus manually, assuming it is not greater than the threadnumber.
        ocmirror_modulus = force_modulus - 1
    # Return the modulus url.
    return ocmp3_urls[ocmirror_modulus]


def ocremix_download(url):
    """Download the mix."""
    # Remove invalid characters from url
    url = url.replace("\\", "")

    # Get the filename from the URL.
    ocfileinfo = urllib.parse.urlparse(url)
    ocfilename = urllib.parse.unquote(os.path.basename(ocfileinfo.path))

    # Download the file.
    if not os.path.isfile(ocfilename):
        print("Downloading mix " + ocfilename + " from mirror " + url)
        urllib.request.urlretrieve(url, ocfilename)
        # Check mimetype
        mimetype = m.file(ocfilename)
        if "Audio" not in mimetype:
            print("ERROR: Downloaded file {0} is not audio. Deleting.".format(ocfilename))
            os.remove(ocfilename)
    else:
        print("WARNING: File {0} already exists. Skipping.".format(ocfilename))


### Begin Code ###

# Get the info of the first oc mix as a starting reference.
ocremix_geturls(ocstart, args.forcemirror)
# Create threads based on number of mirrors.
# http://chriskiehl.com/article/parallelism-in-one-line/
# https://stackoverflow.com/questions/2846653/how-to-use-threading-in-python#2846697
# Use Pool instead of ThreadPool to really use multiprocessing instead of multiprocessing.dummy.
pool = Pool(threadnumber)
# Loop through each mix, ending at ocend. Range is ocend+1 since range function needs to include ocend.
allurls = pool.starmap(ocremix_geturls, zip(range(ocstart, ocend + 1), itertools.repeat(args.forcemirror)))
# Pass the function and array of urls to the pool for downloading.
results = pool.map(ocremix_download, allurls)
# Close the queue (no more data will be added to the queue).
pool.close()
# Wait until the queue is done processing everything.
pool.join()

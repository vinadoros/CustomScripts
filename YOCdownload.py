#!/usr/bin/env python3

# Python includes.
import argparse
import urllib.request
from html.parser import HTMLParser
import urllib.parse
import os
from multiprocessing import Pool

# Variables.
BASEOCURL="http://ocremix.org/remix/OCR0"

# Get arguments
parser = argparse.ArgumentParser(description='Download a numeric range of mixes from ocremix.org.')
parser.add_argument('ocstart', type=int,
                    help='the starting oc-remix number')
parser.add_argument('ocend', type=int,
                    help='the ending oc-remix number')

# Save arguments.
args = parser.parse_args()
ocstart = args.ocstart
ocend = args.ocend
print("Start OCMix: " + format(ocstart) + ", End: " + format(ocend) + ", Total: " + format(ocend-ocstart+1) + ", Downloading to " + os.getcwd())
input("Press Enter to continue.")

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

# Store the OCRemix urls, number of mirrors, and modulus.
def ocremix_geturls(mixnumber):
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
    ocmirror_modulus = mixnumber % ocmirror_number
    # Return the modulus url.
    return ocmp3_urls[ocmirror_modulus];

# Download the mix.
def ocremix_download(url):

    # Get the filename from the URL.
    ocfileinfo = urllib.parse.urlparse(url)
    ocfilename = urllib.parse.unquote(os.path.basename(ocfileinfo.path))

    # Download the file.
    print("Downloading mix " + ocfilename + " from mirror " + url)
    urllib.request.urlretrieve(url, ocfilename)

    return;

### Begin Code ###

# Get the info of the first oc mix as a starting reference.
ocremix_geturls(ocstart)
# Create threads based on number of mirrors.
# http://chriskiehl.com/article/parallelism-in-one-line/
# https://stackoverflow.com/questions/2846653/how-to-use-threading-in-python#2846697
# Use Pool instead of ThreadPool to really use multiprocessing instead of multiprocessing.dummy.
pool = Pool(threadnumber)
# Loop through each mix, ending at ocend. Range is ocend+1 since range function needs to include ocend.
allurls = pool.map(ocremix_geturls, range(ocstart, ocend+1))
# Pass the function and array of urls to the pool for downloading.
results = pool.map(ocremix_download, allurls)
# Close the queue (no more data will be added to the queue).
pool.close()
# Wait until the queue is done processing everything.
pool.join()

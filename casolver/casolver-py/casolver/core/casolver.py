from __future__ import print_function
from casolver.core.events.Event import Event
from lsh import cache, minhash # https://github.com/mattilyra/lsh
import argparse
import errno
import json
import logging
import logging.config
import os
import sys
import pkg_resources
import numpy as np

# Configure logger
logging.config.fileConfig(pkg_resources.resource_filename('casolver', '../conf/logging.ini'))

def atoi(text): return int(text) if text.isdigit() else text

def parse_events_file(file):
	logging.info("Loading events from: %s " %(str(file)))

	global allEvents
	global dataList

	with open(file, 'r') as f:
		data=f.read()
	json_file_data = json.loads(data)

	allEvents = {}
	dataList = []

	for e in json_file_data:
		e_timestamp = e['timestamp']
		e_type = e['type']
		e_thread = e['thread']
		e_eventID = e['id']
		e_loc = e['loc']
		e_order = e['order']
		e_dependency = e['dependency']
		if 'dependencies' in e: e_dependencies = e['dependencies']
		else: e_dependencies = None
		if 'data' in e: e_data = e['data']
		else: e_data = None

		event = Event(e_timestamp, e_type, e_thread, e_eventID, e_loc, e_order, e_dependency, e_dependencies, e_data)

		if 'pid' in e: event.setPid(e['pid'])
		if 'socket' in e: event.setSocket(e['socket'])
		if 'socket_type' in e: event.setSocketType(e['socket_type'])
		if 'src' in e: event.setSrc(e['src'])
		if 'src_port' in e: event.setSrcPort(e['src_port'])
		if 'dst' in e: event.setDst(e['dst'])
		if 'dst_port' in e: event.setDstPort(e['dst_port'])
		if 'size' in e: event.setSize(e['size'])
		if 'returned_value' in e: event.setReturnedValue(e['returned_value'])
		if 'message' in e: event.setMessage(e['message'])
		if 'filename' in e: event.setFilename(e['filename'])
		if 'fd' in e: event.setFileDescriptor(e['fd'])
		if 'offset' in e: event.setOffset(e['offset'])


		allEvents[e_eventID] = event

		if (e_type == 'SND' or e_type == 'RCV' or e_type == 'WR' or e_type == 'RD'):
			if event._returned_value > 0:
				if hasattr(event, "_signature") or event._msg_len > 0:
					dataList.append(event)

	logging.info("Trace successfully loaded!")

def outputResult(output_filename):
	output_file = open(output_filename, "w")
	output = []
	for e in allEvents.values():
		output.append(e.to_string())
	output_file.write(json.dumps(output))
	logging.info("Output saved to: %s" % (output_filename))


def get_jaccard_distance(lshcache, docid_a, docid_b):
	a_fingerprints = set(lshcache.fingerprints[docid_a])
	b_fingerprints = set(lshcache.fingerprints[docid_b])
	return lshcache.hasher.jaccard(a_fingerprints,b_fingerprints)

def get_containment(lshcache, docid_a, docid_b):
	a_fingerprints = set(lshcache.fingerprints[docid_a])
	b_fingerprints = set(lshcache.fingerprints[docid_b])

	return len(a_fingerprints & b_fingerprints) / len(a_fingerprints)
	# return lshcache.hasher.jaccard(a_fingerprints,b_fingerprints)

def get_duplicates_of(lshcache, doc_id, min_jaccard=None):
	if doc_id in lshcache.fingerprints:
		fingerprint = lshcache.fingerprints[doc_id]
	else:
		raise ValueError("Must provide a document or a known document id")

	candidates = set()
	for bin_i, bucket in lshcache.bins_(fingerprint):
		bucket_id = hash(tuple(bucket))
		candidates.update(lshcache.bins[bin_i][bucket_id])

	if min_jaccard is None:
		return candidates
	else:
		return {
			x
			for x in candidates
			if lshcache.hasher.jaccard(set(fingerprint), set(lshcache.fingerprints[x])) >= min_jaccard
		}

def get_similarities_of(lshcache, doc_id, min_jaccard=None):
	if doc_id in lshcache.fingerprints:
		fingerprint = lshcache.fingerprints[doc_id]
	else:
		raise ValueError("Must provide a document or a known document id:", doc_id)

	candidates = set()
	for bin_i, bucket in lshcache.bins_(fingerprint):
		bucket_id = hash(tuple(bucket))
		candidates.update(lshcache.bins[bin_i][bucket_id])

	if min_jaccard is None:
		return candidates
	else:
		# return [
		# 	(x, round(lshcache.hasher.jaccard(set(fingerprint), set(lshcache.fingerprints[x])),2))
		# 	for x in candidates
		# 	if lshcache.hasher.jaccard(set(fingerprint), set(lshcache.fingerprints[x])) >= min_jaccard
		# ]
		return [
			(x, round((2*len(set(fingerprint) & set(lshcache.fingerprints[x]))) / (len(set(fingerprint)) + len(set(lshcache.fingerprints[x]))),2))
			# lshcache.hasher.jaccard(set(fingerprint), set(lshcache.fingerprints[x])),2))
			for x in candidates
			if ((2*len(set(fingerprint) & set(lshcache.fingerprints[x]))) / (len(set(fingerprint)) + len(set(lshcache.fingerprints[x])))) >= min_jaccard and x != doc_id
		]

def findDataDependencies_All_Events():

	# seeds = np.array([ 72352, 784338, 366972, 630676, 794876, 677132, 843637, 208600, 200328, 987482])
	seeds = np.array([ 82241,  37327, 892129, 314275, 984838, 268169, 654205, 386536,  43381, 745416])
	hasher = minhash.MinHasher(seeds=seeds, char_ngram=5, hashbytes=4)
	lshcache = cache.Cache(bands=100, hasher=hasher)

	for event in dataList:
		if not hasattr(event, '_signature'):
			event._signature = hasher.fingerprint(event._msg.encode('utf8')).tolist()
		lshcache.add_fingerprint(event._signature, event._eventId)

	logging.info("Signatures added to lshcache")

	for event in dataList:
		event_dup = get_similarities_of(lshcache, doc_id=event._eventId, min_jaccard=0.6)
		event._data_similarities = list(event_dup)
		logging.info("event_dup(%s) similarities found %d" %(event._type, len(event._data_similarities)))

	logging.info("finish...")


def main():
	"""Main entry point for the script."""

	parser = argparse.ArgumentParser(prog='falcon-datasolver', description='This program is ... TODO!!!')
	parser.add_argument('--event_file', default=None, help="input file (falcon-solver output)")
	parser.add_argument('--output_file', default=None, help="output file")

	args, event_file = parser.parse_known_args()

	if args.event_file is None:
		logging.info("No input file")
		sys.exit(os.EX_USAGE)

	parse_events_file(args.event_file)

	findDataDependencies_All_Events()

	if args.output_file is None: output_file = "falcon_casolver.json"
	else : output_file = args.output_file
	outputResult(output_file)


if __name__ == '__main__':
	main()
